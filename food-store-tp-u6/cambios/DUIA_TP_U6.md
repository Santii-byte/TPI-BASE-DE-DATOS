# DUIA - TP Unidad 6 (Food Store)

## Herramienta

- OpenCode
- Modelo: DeepSeek V4.1 Flash Free
- Fecha: 2026-11-08
- Alcance: TP Unidad 6 completo (especificacion, respaldo, monitoreo,
  mantenimiento, restauracion e informe)

## Prompt utilizado

> "Ahora tengo que empezar la unidad 6, estas son las consignas, siguelas y
> corrobora que este bien hecho."

Adjunto: cinco capturas con las consignas de la Unidad 6.

Prompts parciales usados durante la ejecucion:

1. "Revisa el esquema y los datos disponibles para elegir la base del TP."
2. "Redacta la especificacion U6 en una pagina, con frecuencia y condicion de
   terminacion."
3. "Escribe el script de respaldo en formato custom, sin contrasenas y con
   codigo de salida distinto de 0 ante fallo."
4. "Escribe un health check con al menos cuatro controles y veredicto por
   codigo de salida."
5. "Escribe la revision de mantenimiento justificada desde el estado observado,
   sin VACUUM FULL periodico."
6. "Escribe la prueba de restauracion con `--no-owner --no-privileges`, conteos
   contra el pre-respaldo y calculo de RPO/RTO."
7. "Ejecuta todo en un PostgreSQL 17 real y guarda evidencias."
8. "Redacta el informe final con fecha de respaldo, tiempos, RPO/RTO,
   validaciones, problema real, mejora concreta y uso de OpenCode."

## Que genero

- `SPEC_U6.md`: alcance, automatizacion, frecuencia, condicion de terminacion,
  RPO/RTO objetivo y fuera de alcance.
- `backup_foodstore.ps1`: respaldo `pg_dump -Fc`, nombre con fecha/hora, log,
  manifiesto JSON de conteos, validacion de archivo y codigos de salida.
- `health_check.sql`: 8 controles (tamano, conexiones, consultas largas,
  `idle in transaction`, tuplas muertas, indices invalidos, locks y tablas sin
  `ANALYZE`), con tabla de resultados y bloque `DO` que falla ante `FAIL`.
- `maintenance.sql`: revision de autovacuum, `VACUUM (ANALYZE)` justificado y
  ajuste de umbrales de autovacuum en `detalle_pedido`.
- `restore_test.ps1`: creacion de `foodstore_restore_test`, restauracion con
  `--no-owner --no-privileges`, validacion de conteos e integridad, calculo de
  RTO y RPO, evidencia en `docs/`.
- `README.md`, `informe_u6.md` y `cambios/DUIA_TP_U6.md`.
- Evidencias en `docs/` y logs en `logs/`.

## Que se modifico o descarto y por que

- **Base de trabajo:** se descarto usar el esquema `tp6_p2` de `TP6` porque
  vive en un esquema aislado y agrega `categoria`, que no aporta al objetivo de
  respaldo/restauracion. Se uso el esquema comercial de `TP5/food-store`
  (`public`) con la carga masiva de 20.000/50.000/200.000/399.994 filas.
- **Health check:** la primera version contaba la tabla temporal del propio
  chequeo como "tabla sin ANALYZE". Se filtro `schemaname = 'public'`.
- **Health check:** se renombro el umbral `max_dead_pct` a
  `max_dead_pct_umbral` para evitar ambiguedad con la metrica del mismo nombre.
- **Restauracion:** la primera corrida fallo porque `$ErrorActionPreference =
  "Stop"` convertia un `NOTICE` de `dropdb` en `stderr` en error terminante. Se
  cambio a `Continue` y se controlan explicitamente los codigos de salida.
- **VACUUM FULL:** se descarto como tarea periodica por el bloqueo
  `ACCESS EXCLUSIVE`; se documento su uso solo ante bloat extrema.
- **PDF:** no se genero PDF porque el entorno no tiene herramienta de
  conversion. Se entrega `informe_u6.md` como fuente; puede exportarse a PDF
  desde cualquier editor Markdown.

## Verificacion realizada

Se ejecuto el flujo completo en un cluster temporal de PostgreSQL 17.11 en el
puerto 55436:

1. Creacion de `foodstore_u6` y carga de esquema/datos: OK.
2. `backup_foodstore.ps1`: codigo 0, dump de 10.292.285 bytes en 1,9 s.
3. `health_check.sql` inicial: 1 FAIL real (46,34 % de tuplas muertas en
   `pedido`) y 1 WARN por la tabla temporal, corregido.
4. `maintenance.sql`: codigo 0, 172.684 identificadores muertos reclamados,
   0 tuplas muertas posteriores.
5. `health_check.sql` posterior: 8/8 controles OK.
6. `restore_test.ps1`: codigo 0, RTO 5,69 s, RPO 0,02 h, 4/4 conteos y 8/8
   validaciones de integridad OK.
7. `pg_restore -l`: codigo 0.

Las salidas reales quedaron en `docs/evidencia_*.txt` y en `logs/`.

## Nota sobre el uso de IA

La IA se uso como asistente de redaccion y ejecucion, no como reemplazo de la
verificacion. Cada resultado del informe se contrasto contra la salida real de
`psql`, `pg_dump` o `pg_restore`. Los archivos no se commitearon: quedan para
revision del equipo.
