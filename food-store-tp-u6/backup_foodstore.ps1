# ============================================================================
# backup_foodstore.ps1 - Respaldo logico completo de Food Store (PostgreSQL 17)
# ----------------------------------------------------------------------------
# Genera un archivo custom (-Fc) con fecha y hora, un log de ejecucion y un
# manifiesto JSON con los conteos por tabla tomados justo antes del respaldo.
# No contiene contrasenas: use PGPASSWORD, pgpass.conf o autenticacion local.
#
# Salida:
#   0  respaldo creado y verificado (archivo existe y no esta vacio)
#   1  error de validacion previa, de pg_dump o archivo incompleto
# ============================================================================

[CmdletBinding()]
param(
    [string]$Database   = "foodstore_u6",
    [string]$BackupDir  = (Join-Path $PSScriptRoot "backups"),
    [string]$LogDir     = (Join-Path $PSScriptRoot "logs"),
    [string]$PgBin      = "C:\Program Files\PostgreSQL\17\bin",
    [string]$PgHost     = "localhost",
    [string]$PgPort     = "55436",
    [string]$PgUser     = "postgres"
)

$ErrorActionPreference = "Continue"

$PgDump = Join-Path $PgBin "pg_dump.exe"
$Psql   = Join-Path $PgBin "psql.exe"

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile   = Join-Path $LogDir ("backup_" + $Timestamp + ".log")
$DumpFile  = Join-Path $BackupDir ("foodstore_u6_" + $Timestamp + ".dump")
$CountFile = Join-Path $BackupDir ("foodstore_u6_" + $Timestamp + ".counts.json")

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

# ---------------------------------------------------------------------------
# 1. Validaciones previas
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
Set-Content -Path $LogFile -Value ("=== RESPALDO FOOD STORE " + $Timestamp + " ===") -Encoding UTF8

Write-Log ("Base de datos: " + $Database)
Write-Log ("Servidor: " + $PgHost + ":" + $PgPort + " usuario=" + $PgUser)
Write-Log ("Destino: " + $DumpFile)

if (-not (Test-Path $PgDump)) { Fail ("No existe pg_dump en " + $PgDump) }
if (-not (Test-Path $Psql))   { Fail ("No existe psql en " + $Psql) }

$ConnectionArgs = @("-h", $PgHost, "-p", $PgPort, "-U", $PgUser, "-w")

# ---------------------------------------------------------------------------
# 2. Conteos pre-respaldo (manifiesto de validacion)
# ---------------------------------------------------------------------------
$CountsSql = @"
SELECT 'cliente|' || count(*) FROM cliente
UNION ALL SELECT 'producto|' || count(*) FROM producto
UNION ALL SELECT 'pedido|' || count(*) FROM pedido
UNION ALL SELECT 'detalle_pedido|' || count(*) FROM detalle_pedido
ORDER BY 1;
"@

$CountsRaw = & $Psql @ConnectionArgs -X -q -t -A -d $Database -c $CountsSql 2>&1
$CountsCode = $LASTEXITCODE
$CountsRaw | Add-Content -Path $LogFile -Encoding UTF8
if ($CountsCode -ne 0) { Fail ("No se pudieron leer los conteos (psql=" + $CountsCode + ")") }

$Counts = [ordered]@{}
foreach ($line in $CountsRaw) {
    $text = ($line | Out-String).Trim()
    if ($text -match '^([a-z_]+)\|([0-9]+)$') {
        $Counts[$matches[1]] = [int64]$matches[2]
    }
}
if ($Counts.Count -ne 4) { Fail "El manifiesto no contiene los 4 conteos esperados" }

$Manifest = [ordered]@{
    timestamp = (Get-Date).ToString("o")
    database  = $Database
    dump_file = $DumpFile
    counts    = $Counts
}
$Manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $CountFile -Encoding UTF8
Write-Log ("Manifiesto de conteos: " + $CountFile)
Write-Log ("Conteos: cliente=" + $Counts["cliente"] + " producto=" + $Counts["producto"] + " pedido=" + $Counts["pedido"] + " detalle_pedido=" + $Counts["detalle_pedido"])

# ---------------------------------------------------------------------------
# 3. Respaldo custom
# ---------------------------------------------------------------------------
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$DumpOutput = & $PgDump @ConnectionArgs -d $Database -Fc --no-password -f $DumpFile 2>&1
$DumpCode = $LASTEXITCODE
$Stopwatch.Stop()

$DumpOutput | Add-Content -Path $LogFile -Encoding UTF8
Write-Log ("pg_dump finalizo con codigo " + $DumpCode + " en " + [math]::Round($Stopwatch.Elapsed.TotalSeconds, 2) + " s")

if ($DumpCode -ne 0) {
    if (Test-Path $DumpFile) { Remove-Item $DumpFile -Force }
    if (Test-Path $CountFile) { Remove-Item $CountFile -Force }
    Fail ("pg_dump devolvio codigo " + $DumpCode)
}
if (-not (Test-Path $DumpFile)) { Fail "pg_dump no genero el archivo esperado" }

$DumpInfo = Get-Item $DumpFile
if ($DumpInfo.Length -le 0) {
    Remove-Item $DumpFile -Force
    if (Test-Path $CountFile) { Remove-Item $CountFile -Force }
    Fail "El archivo de respaldo esta vacio"
}

Write-Log ("Archivo: " + $DumpFile)
Write-Log ("Tamano: " + $DumpInfo.Length + " bytes (" + [math]::Round($DumpInfo.Length / 1MB, 2) + " MB)")
Write-Log ("RESULTADO: OK - respaldo verificado")
exit 0
