# Food Store - TP Unidad 6: Respaldo, monitoreo, mantenimiento y restauracion

Trabajo practico de **operacion de bases de datos** sobre PostgreSQL 17:
respaldo logico, health check, mantenimiento y prueba de restauracion con
medicion de RPO/RTO.

- **Integrantes:** Franco Rios y Santino Barone.
- **Motor:** PostgreSQL 17.11.
- **Base:** `foodstore_u6`, esquema comercial de Food Store
  (`TP5/food-store/schema.sql`) y carga masiva (`TP5/food-store/data.sql`).
- **Herramientas:** OpenCode, psql, pg_dump, pg_restore, PowerShell 5.1.

---

## Estructura

```text
food-store-tp-u6/
├── SPEC_U6.md                  # Especificacion: alcance, frecuencia y fin
├── backup_foodstore.ps1        # Respaldo diario en formato custom (-Fc)
├── health_check.sql            # 8 controles de salud + veredicto
├── maintenance.sql             # Revision de autovacuum + VACUUM (ANALYZE)
├── restore_test.ps1            # Restauracion y validacion con RPO/RTO
├── informe_u6.md               # Informe final con resultados reales
├── informe_u6.html             # Version imprimible (Imprimir > Guardar como PDF)
├── README.md
├── backups/                    # .dump y manifiesto .counts.json
├── logs/                       # backup_*.log y restore_*.log
├── docs/                       # evidencias de cada ejecucion
└── cambios/
    └── DUIA_TP_U6.md           # Declaracion de uso de IA
```

---

## Requisitos

1. PostgreSQL 17 con `pg_dump`, `pg_restore`, `createdb`, `dropdb` y `psql`.
2. Base `foodstore_u6` creada y poblada.
3. Permisos para crear/eliminar la base `foodstore_restore_test`.
4. Sin contrasenas dentro de los scripts: usar `PGPASSWORD`,
   `%APPDATA%\postgresql\pgpass.conf` o autenticacion local.

Preparacion de la base (desde la raiz del repositorio):

```powershell
createdb -h localhost -p 55436 -U postgres foodstore_u6
psql -h localhost -p 55436 -U postgres -d foodstore_u6 -f TP5/food-store/schema.sql
psql -h localhost -p 55436 -U postgres -d foodstore_u6 -f TP5/food-store/data.sql
```

---

## Ejecucion manual

```powershell
cd food-store-tp-u6

# 1. Respaldo (genera backups/*.dump, backups/*.counts.json y logs/backup_*.log)
.\backup_foodstore.ps1

# 2. Health check (guardar evidencia)
psql -h localhost -p 55436 -U postgres -d foodstore_u6 `
  -v ON_ERROR_STOP=1 -f health_check.sql *> docs\evidencia_health_check.txt

# 3. Mantenimiento semanal
psql -h localhost -p 55436 -U postgres -d foodstore_u6 `
  -v ON_ERROR_STOP=1 -f maintenance.sql *> docs\evidencia_mantenimiento.txt

# 4. Restauracion y validacion (RTO/RPO)
.\restore_test.ps1
```

Los scripts aceptan parametros (`-Database`, `-BackupDir`, `-LogDir`, `-PgBin`,
`-PgHost`, `-PgPort`, `-PgUser`). Los valores por defecto apuntan a
`localhost:55436` y a la carpeta del TP.

---

## Automatizacion propuesta

Con el Programador de tareas de Windows:

| Tarea | Frecuencia | Comando |
|---|---|---|
| Respaldo | Diaria 02:00 | `powershell.exe -ExecutionPolicy Bypass -File C:\...\backup_foodstore.ps1` |
| Health check | Diaria 08:00 | `psql.exe ... -f health_check.sql` (codigo 3 si hay FAIL) |
| Mantenimiento | Lunes 03:00 | `psql.exe ... -f maintenance.sql` |
| Restauracion | Lunes 04:00 | `powershell.exe -ExecutionPolicy Bypass -File C:\...\restore_test.ps1` |

La condicion de terminacion de cada tarea esta detallada en `SPEC_U6.md`.
En todos los casos, codigo de salida 0 = OK; cualquier otro valor debe generar
una alerta.

---

## Resultados de la ejecucion real

- **Respaldo:** `backups/foodstore_u6_20261108_155019.dump`, 10.292.285 bytes
  (9,82 MB), `pg_dump` codigo 0 en 1,9 s.
- **Health check inicial:** 6 OK, 1 FAIL (46,34 % de tuplas muertas en
  `pedido`, 172.684 tuplas) y 1 WARN por la tabla temporal, corregido en el
  script.
- **Mantenimiento:** `VACUUM (ANALYZE)` de las 4 tablas; `pedido` quedo en
  0,00 % de tuplas muertas. Ajuste de umbrales de autovacuum en
  `detalle_pedido`.
- **Health check posterior:** 8/8 controles OK.
- **Prueba negativa:** con una base inexistente, `backup_foodstore.ps1`
  devolvio codigo 1 y registro el error (`docs/evidencia_respaldo_fallo.txt`).
- **Restauracion:** `foodstore_restore_test` creada y restaurada con
  `--no-owner --no-privileges`, RTO medido **5,69 s**, RPO observado
  **0,02 h**, conteos e integridad **100 % OK**.

El detalle completo esta en `informe_u6.md` y en `docs/`.

---

## Limpieza

La base `foodstore_restore_test` se conserva para inspeccion. Para eliminarla:

```powershell
dropdb -h localhost -p 55436 -U postgres foodstore_restore_test
```

Los respaldos antiguos deben rotarse segun la politica de retencion (por
ejemplo, 7 diarios + 4 semanales). Esa rotacion no se implementa en este TP.
