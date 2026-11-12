# Declaración de Uso de Inteligencia Artificial (DUIA)

**Trabajo:** TP Unidad 8 - Food Store: la base de la tablet
**Integrantes:** Franco Rios y Santino Barone
**Fecha:** noviembre de 2026

## 1. Herramientas y modelos

| Herramienta | Modelo / modo | Uso |
|---|---|---|
| OpenCode | DeepSeek V4.1 Flash Free | diseño, SQL, documentos y revisión |
| OpenCode | modo Plan (revisión) | code review de los scripts de TP1-TP8 |
| PostgreSQL 17 | `psql`, `\copy` | ejecución y verificación del servidor |
| SQLite 3.50 | `sqlite3` / DB Browser / runner de Python | ejecución y verificación de la tablet |
| Python 3.14 | librería estándar `sqlite3` | ejecutar los `.sql` en un equipo sin binario `sqlite3` |

No se usó IA para generar datos personales. Todos los nombres, precios, stocks,
UUID y pedidos son inventados.

## 2. Alcance del uso

La IA se usó para:

- proponer el esquema SQLite y el semáforo;
- proponer los casos C2-C6 y los scripts de evidencia;
- revisar los scripts de las unidades anteriores;
- redactar el informe, el README y la bitácora.

La IA **no** decidió por sí sola qué se entregaba. Cada script fue leído,
ejecutado y verificado contra PostgreSQL y SQLite. Lo que no se pudo explicar
se descartó.

## 3. Prompts representativos

1. "Diseñá cuatro tablas SQLite STRICT para una tablet sin señal, con
   producto_cache, pedido_borrador, item_borrador y cola_sync."
2. "Escribí un semáforo en SQLite que marque RECHAZADO, CONFLICTO o
   SIMULADO_APROBADO comparando contra snapshot_servidor."
3. "¿Cómo importo un CSV de PostgreSQL con booleanos t/f a una tabla STRICT?"
4. "Revisá todos los scripts de TP1 a TP8 y proponé hallazgos con decisión y
   fundamento; al menos uno debe quedar descartado."
5. "Armá un informe de 6 páginas con 1.a, 2.c, 3.a, 3.b y 3.c y un guion de
   defensa de 10 minutos."

## 4. Qué se aceptó, corrigió o descartó

- **Aceptado:** estructura general del esquema, precedencia del semáforo,
  snapshot completo por CSV, PK UUID de idempotencia.
- **Corregido:** precio en centavos en lugar de `REAL`; staging de texto para
  booleanos; motivo duplicado de stock 0; afirmaciones del informe que decían
  "venta aprobada".
- **Descartado:** borrar items locales al dar de baja un producto; reutilizar
  el UUID de una solicitud; cambiar el trigger de resumen de TP6 para que no
  lance excepción; normalizar `lineas_pedido` en MongoDB; agregar una interfaz
  o un programa Python como requisito.

El detalle de cada decisión está en `docs/bitacora_ia.md`.

## 5. Verificación realizada

- Todos los scripts se ejecutaron en un clúster PostgreSQL 17 y en SQLite
  3.50; los resultados están en `docs/evidencias/`.
- La verificación final de PostgreSQL devolvió
  `VERDE: pedidos y stock sin cambios` (3 pedidos, 4 detalles, stock 295).
- Las pruebas C7a y C7b fallaron como se esperaba y no dejaron filas.
- El reenvío C6 fue rechazado por la PK de `cola_sync`.
- El PDF del informe se revisó completo antes de la entrega.

## 6. Responsabilidad

Los integrantes asumen la responsabilidad por el contenido entregado. La IA fue
una herramienta de apoyo: ninguna decisión de diseño, ningún dato y ninguna
conclusión del informe se aceptó sin ejecutarla o verificarla. En la defensa se
puede explicar cada tabla, cada consulta y cada caso.

## 7. Declaración

Declaramos que este trabajo es de nuestra autoría, que no se utilizaron datos
personales reales y que el uso de IA se realizó conforme a lo indicado por la
cátedra. Entregamos la bitácora y esta declaración para que el proceso sea
auditable.