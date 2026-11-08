# SPEC U6 - Respaldo, monitoreo, mantenimiento y restauracion

## Alcance

Operacion de la base `foodstore_u6` (Food Store, PostgreSQL 17) durante un ciclo
de 7 dias. La base se respalda con `pg_dump` en formato custom (`-Fc`) y se
verifica mediante un health check, una revision de mantenimiento y una
restauracion completa en una base aislada.

## Que se automatiza

| Actividad | Frecuencia | Script | Condicion de terminacion | Evidencia |
|---|---|---|---|---|
| Respaldo completo | Diaria, 02:00 | `backup_foodstore.ps1` | Termina con codigo 0 solo si `pg_dump` retorna 0, el `.dump` existe y no esta vacio; cualquier fallo devuelve codigo distinto de 0 y deja el error en el log. | `backups/*.dump`, `logs/backup_*.log`, `backups/*.counts.json` |
| Health check | Diaria, 08:00 | `health_check.sql` | Termina OK si ningun control queda en `FAIL`; el `DO` final lanza excepcion (codigo psql distinto de 0) si hay al menos un `FAIL`. | `docs/evidencia_health_check.txt` |
| Revision de mantenimiento | Semanal, lunes 03:00 | `maintenance.sql` | Termina OK si los `VACUUM (ANALYZE)` y `ANALYZE` finalizan sin error y la tabla de control no muestra indices invalidos. | `docs/evidencia_mantenimiento.txt` |
| Prueba de restauracion | Semanal, lunes 04:00 | `restore_test.ps1` | Termina con codigo 0 solo si `createdb`, `pg_restore --no-owner --no-privileges` y todas las validaciones pasan; si un conteo no coincide o hay datos invalidos, devuelve codigo distinto de 0. | `docs/evidencia_restauracion.txt`, `logs/restore_*.log` |

La automatizacion real se delega al Programador de tareas de Windows (o `cron`
en Linux) invocando los scripts con las mismas rutas y parametros documentados
en `README.md`. Los scripts no contienen contrasenas: usan `PGPASSWORD`,
`%APPDATA%\postgresql\pgpass.conf` o autenticacion local del servidor.

## Condiciones de exito

- Respaldo: archivo custom no vacio y log con codigo de salida 0.
- Health check: tamano de base, conexiones, consultas activas, locks, tuplas
  muertas e indices invalidos dentro de umbral.
- Mantenimiento: `VACUUM (ANALYZE)` justificado por tuplas muertas observadas;
  nunca `VACUUM FULL` periodico.
- Restauracion: conteos por tabla iguales al manifiesto pre-respaldo, cero
  productos invalidos, cero detalles invalidos, cero huerfanos y cero indices
  invalidos.
- RPO objetivo: <= 24 h (respaldo diario). RTO objetivo: <= 1 h.

## Fuera de alcance

- Replicacion en caliente, PITR con WAL archivado y alta disponibilidad.
- Cifrado de respaldos y almacenamiento externo (se documentan como mejora).
