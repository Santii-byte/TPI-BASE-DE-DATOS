# ============================================================================
# restore_test.ps1 - Prueba semanal de restauracion (PostgreSQL 17)
# ----------------------------------------------------------------------------
# Toma el respaldo custom mas reciente (o el indicado con -BackupFile), crea la
# base aislada foodstore_restore_test, restaura con --no-owner --no-privileges
# y valida conteos, integridad y datos invalidos contra el manifiesto generado
# por backup_foodstore.ps1.
#
# El cronometro (RTO medido) arranca ANTES de createdb y se detiene al terminar
# la ultima validacion. La antiguedad del respaldo se informa como RPO
# observado.
#
# Salida:
#   0  restauracion y todas las validaciones OK
#   1  fallo en cualquier paso
# ============================================================================

[CmdletBinding()]
param(
    [string]$Database   = "foodstore_restore_test",
    [string]$BackupFile = "",
    [string]$BackupDir  = (Join-Path $PSScriptRoot "backups"),
    [string]$LogDir     = (Join-Path $PSScriptRoot "logs"),
    [string]$DocsDir    = (Join-Path $PSScriptRoot "docs"),
    [string]$PgBin      = "C:\Program Files\PostgreSQL\17\bin",
    [string]$PgHost     = "localhost",
    [string]$PgPort     = "55436",
    [string]$PgUser     = "postgres"
)

$ErrorActionPreference = "Continue"

$PgRestore = Join-Path $PgBin "pg_restore.exe"
$Psql      = Join-Path $PgBin "psql.exe"
$CreatedDb = Join-Path $PgBin "createdb.exe"
$DropDb    = Join-Path $PgBin "dropdb.exe"

$RunTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile      = Join-Path $LogDir ("restore_" + $RunTimestamp + ".log")
$EvidenceFile = Join-Path $DocsDir "evidencia_restauracion.txt"

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Fail {
    param([string]$Message)
    Write-Log ("ERROR: " + $Message)
    Write-Log "RESULTADO: FALLO (codigo de salida 1)"
    exit 1
}

function Invoke-Scalar {
    param([string]$Sql)
    $out = & $Psql @ConnectionArgs -X -q -t -A -d $Database -c $Sql 2>&1
    $code = $LASTEXITCODE
    $text = ($out | Out-String).Trim()
    if ($code -ne 0) {
        Fail ("psql fallo (" + $code + "): " + $text)
    }
    return [int64]$text
}

# ---------------------------------------------------------------------------
# 1. Preparacion
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
New-Item -ItemType Directory -Force -Path $DocsDir | Out-Null
Set-Content -Path $LogFile -Value ("=== PRUEBA DE RESTAURACION " + $RunTimestamp + " ===") -Encoding UTF8

foreach ($tool in @($PgRestore, $Psql, $CreatedDb, $DropDb)) {
    if (-not (Test-Path $tool)) { Fail ("No existe la herramienta: " + $tool) }
}

if ([string]::IsNullOrWhiteSpace($BackupFile)) {
    $latest = Get-ChildItem -Path $BackupDir -Filter "foodstore_u6_*.dump" -File |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $latest) { Fail ("No hay respaldos en " + $BackupDir) }
    $BackupFile = $latest.FullName
}
if (-not (Test-Path $BackupFile)) { Fail ("No existe el respaldo: " + $BackupFile) }

$BackupInfo = Get-Item $BackupFile
if ($BackupInfo.Length -le 0) { Fail "El respaldo esta vacio" }

$nameMatch = [regex]::Match($BackupInfo.Name, '^foodstore_u6_(\d{8}_\d{6})\.dump$')
if (-not $nameMatch.Success) { Fail ("Nombre de respaldo inesperado: " + $BackupInfo.Name) }
$BackupTimestamp = $nameMatch.Groups[1].Value
$ManifestFile = Join-Path $BackupDir ("foodstore_u6_" + $BackupTimestamp + ".counts.json")
if (-not (Test-Path $ManifestFile)) { Fail ("No existe el manifiesto de conteos: " + $ManifestFile) }

$Manifest = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json
$BackupTime = [datetimeoffset]::Parse($Manifest.timestamp, [Globalization.CultureInfo]::InvariantCulture).LocalDateTime
$BackupAge = (Get-Date) - $BackupTime
$Bytes = $BackupInfo.Length

Write-Log ("Respaldo: " + $BackupFile)
Write-Log ("Manifiesto: " + $ManifestFile)
Write-Log ("Fecha/hora del respaldo: " + $BackupTime.ToString("yyyy-MM-dd HH:mm:ss"))
Write-Log ("Tamano del respaldo: " + $Bytes + " bytes (" + [math]::Round($Bytes / 1MB, 2) + " MB)")
Write-Log ("Base de prueba: " + $Database)

$ConnectionArgs = @("-h", $PgHost, "-p", $PgPort, "-U", $PgUser, "-w")

# ---------------------------------------------------------------------------
# 2. Restauracion cronometrada (RTO)
# ---------------------------------------------------------------------------
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$StartLocal = Get-Date

Write-Log "Paso 1/3: eliminando base de prueba si existe"
$dropOut = & $DropDb @ConnectionArgs --if-exists --no-password $Database 2>&1
$dropOut | Add-Content -Path $LogFile -Encoding UTF8
if ($LASTEXITCODE -ne 0) { Fail ("dropdb devolvio " + $LASTEXITCODE) }

Write-Log "Paso 2/3: creando base de prueba"
$createOut = & $CreatedDb @ConnectionArgs --no-password $Database 2>&1
$createOut | Add-Content -Path $LogFile -Encoding UTF8
if ($LASTEXITCODE -ne 0) { Fail ("createdb devolvio " + $LASTEXITCODE) }

Write-Log "Paso 3/3: restaurando con pg_restore --no-owner --no-privileges"
$restoreOut = & $PgRestore @ConnectionArgs -d $Database --no-owner --no-privileges --exit-on-error --no-password $BackupFile 2>&1
$restoreCode = $LASTEXITCODE
$restoreOut | Add-Content -Path $LogFile -Encoding UTF8
if ($restoreCode -ne 0) { Fail ("pg_restore devolvio " + $restoreCode) }
Write-Log ("pg_restore OK en " + [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2) + " s")

# ---------------------------------------------------------------------------
# 3. Validaciones
# ---------------------------------------------------------------------------
$Tablas = @("cliente", "producto", "pedido", "detalle_pedido")
$CountResults = @()
$CountFailures = 0

foreach ($tabla in $Tablas) {
    $real = Invoke-Scalar ("SELECT count(*) FROM " + $tabla + ";")
    $esperado = [int64]$Manifest.counts.$tabla
    if ($real -eq $esperado) { $estado = "OK" } else { $estado = "FAIL"; $CountFailures++ }
    $CountResults += [pscustomobject]@{ Tabla = $tabla; Esperado = $esperado; Restaurado = $real; Estado = $estado }
    Write-Log ("Conteo " + $tabla + ": esperado=" + $esperado + " restaurado=" + $real + " -> " + $estado)
}

$Checks = @(
    @{ Nombre = "Productos invalidos (precio/stock)"; Sql = "SELECT count(*) FROM producto WHERE precio < 0 OR stock < 0;" },
    @{ Nombre = "Detalles invalidos (cantidad/precio)"; Sql = "SELECT count(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario <= 0;" },
    @{ Nombre = "Pedidos huerfanos de cliente"; Sql = "SELECT count(*) FROM pedido p LEFT JOIN cliente c ON c.id = p.cliente_id WHERE c.id IS NULL;" },
    @{ Nombre = "Detalles huerfanos de pedido"; Sql = "SELECT count(*) FROM detalle_pedido d LEFT JOIN pedido p ON p.id = d.pedido_id WHERE p.id IS NULL;" },
    @{ Nombre = "Detalles huerfanos de producto"; Sql = "SELECT count(*) FROM detalle_pedido d LEFT JOIN producto p ON p.id = d.producto_id WHERE p.id IS NULL;" },
    @{ Nombre = "Totales de pedido inconsistentes"; Sql = "SELECT count(*) FROM pedido p WHERE p.total <> COALESCE((SELECT SUM(d.cantidad * d.precio_unitario) FROM detalle_pedido d WHERE d.pedido_id = p.id), 0);" },
    @{ Nombre = "Indices invalidos"; Sql = "SELECT count(*) FROM pg_index WHERE NOT indisvalid;" },
    @{ Nombre = "Tablas base presentes"; Sql = "SELECT 4 - count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename IN ('cliente','producto','pedido','detalle_pedido');" }
)

$CheckResults = @()
$CheckFailures = 0
foreach ($check in $Checks) {
    $valor = Invoke-Scalar $check.Sql
    if ($valor -eq 0) { $estado = "OK" } else { $estado = "FAIL"; $CheckFailures++ }
    $CheckResults += [pscustomobject]@{ Control = $check.Nombre; Valor = $valor; Estado = $estado }
    Write-Log ("Control '" + $check.Nombre + "': valor=" + $valor + " -> " + $estado)
}

$Stopwatch.Stop()
$EndLocal = Get-Date
$RtoSeconds = [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2)
$RpoHours = [math]::Round($BackupAge.TotalHours, 2)

# ---------------------------------------------------------------------------
# 4. Evidencia
# ---------------------------------------------------------------------------
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("EVIDENCIA DE PRUEBA DE RESTAURACION - FOOD STORE")
$lines.Add("Generado: " + $EndLocal.ToString("yyyy-MM-dd HH:mm:ss"))
$lines.Add("")
$lines.Add("Respaldo utilizado : " + $BackupFile)
$lines.Add("Fecha/hora respaldo: " + $BackupTime.ToString("yyyy-MM-dd HH:mm:ss"))
$lines.Add("Tamano respaldo    : " + $Bytes + " bytes (" + [math]::Round($Bytes / 1MB, 2) + " MB)")
$lines.Add("Base restaurada    : " + $Database)
$lines.Add("Flags de restore   : --no-owner --no-privileges --exit-on-error")
$lines.Add("")
$lines.Add("Inicio (antes de createdb): " + $StartLocal.ToString("yyyy-MM-dd HH:mm:ss.fff"))
$lines.Add("Fin validacion            : " + $EndLocal.ToString("yyyy-MM-dd HH:mm:ss.fff"))
$lines.Add("Tiempo total restauracion + validacion (RTO medido): " + $RtoSeconds + " s")
$lines.Add("Antiguedad del respaldo (RPO observado): " + $RpoHours + " h")
$lines.Add("RPO objetivo: <= 24 h | RTO objetivo: <= 1 h")
$lines.Add("")
$lines.Add("Conteos por tabla:")
foreach ($r in $CountResults) {
    $lines.Add(("  {0,-16} esperado={1,-8} restaurado={2,-8} {3}" -f $r.Tabla, $r.Esperado, $r.Restaurado, $r.Estado))
}
$lines.Add("")
$lines.Add("Validaciones de integridad:")
foreach ($r in $CheckResults) {
    $lines.Add(("  {0,-40} valor={1,-6} {2}" -f $r.Control, $r.Valor, $r.Estado))
}
$lines.Add("")

$fallos = $CountFailures + $CheckFailures
if ($fallos -eq 0) {
    $lines.Add("RESULTADO: OK - restauracion y validaciones completas")
    Set-Content -Path $EvidenceFile -Value $lines -Encoding UTF8
    Write-Log ("RESULTADO: OK - RTO=" + $RtoSeconds + " s RPO=" + $RpoHours + " h")
    Write-Log ("Evidencia: " + $EvidenceFile)
    exit 0
}
else {
    $lines.Add("RESULTADO: FALLO - " + $fallos + " validacion(es) fallaron")
    Set-Content -Path $EvidenceFile -Value $lines -Encoding UTF8
    Fail ("" + $fallos + " validacion(es) fallaron; ver " + $EvidenceFile)
}
