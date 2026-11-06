# DUIA — TP6 Parte 2: Desnormalización controlada del top 5

## Herramienta

DeepSeek V4.1 Flash Free (OpenCode)

## Prompt utilizado

"Y ahora se continua con la parte 2: [Food store 2.txt: Parte 2 — Consulta con desnormalización controlada. Escenario del top 5 de categorías por monto vendido en el día, consulta base, y puntos a) EXPLAIN ANALYZE antes, b) elección y justificación del patrón de desnormalización, c) implementación SQL, d) consulta sobre la estructura desnormalizada con EXPLAIN ANALYZE y tabla antes/después, e) script de auditoría de desincronización]. Entregable: tp_desnormalizacion_top_categorias.sql e informe breve."

## Qué generó

Listo. Implementé la Parte 2 completa en `TP6/`, con el entregable `tp_desnormalizacion_top_categorias.sql`, y la validé tanto sobre la base canónica acumulada de TP2–TP5 como sobre un laboratorio reproducible aislado.

**Mediciones reales (PostgreSQL 17)**

| Entorno | Antes (mediana de 3) | Después (mediana de 3) | Mejora |
|---|---:|---:|---:|
| Base canónica TP2–TP5 | 244,707 ms | 0,183 ms | ~1.337× |
| Laboratorio `tp6_p2` | 289,556 ms | 0,239 ms | ~1.212× |

- **Antes (canónica):** 226,875 / 244,707 / 279,576 ms. El costo está en recorrer y unir cientos de miles de renglones de detalle para producir 60 grupos; el `Sort` final solo ordena 60 filas (25 kB).
- **Después (canónica):** 0,208 / 0,183 / 0,151 ms. Solo lee 5 entradas del índice del resumen y hace 5 lookups a `categoria_pkey`.
- Ambas consultas devuelven exactamente el mismo top 5 y los mismos totales.

**Qué implementé**

- **Estructura:** `resumen_venta_categoria_dia(categoria_id, fecha, total_vendido)`, con PK `(categoria_id, fecha)` e índice `(fecha, total_vendido DESC) INCLUDE (categoria_id)`.
- **Sincronización:** disparadores sobre `detalle_pedido` (INSERT/UPDATE/DELETE), `pedido` (cambio de `fecha`/`eliminado` y `BEFORE DELETE`) y `producto` (cambio de `categoria_id`), con un upsert atómico por delta.
- **Trigger `BEFORE DELETE` sobre `pedido`** para evitar el doble descuento que produce la FK `ON DELETE CASCADE` del esquema TP2/TP5.
- **Backfill** inicial desde la fuente de verdad.
- **Auditoría** con `FULL OUTER JOIN` entre la fuente recalculada y el resumen.
- **Reversión** sin pérdida mediante `06_rollback.sql`.
- **Compatibilidad con TP2–TP5:** migración `00_migracion_esquema_tp5.sql` que extiende el esquema `public` sin recrearlo, conservando `pedido.fecha TIMESTAMPTZ` y los índices/constraints previos.

**Archivos creados**

- `TP6/tp_desnormalizacion_top_categorias.sql` — entregable principal, agnóstico al `search_path`.
- `TP6/00_migracion_esquema_tp5.sql` — migración del esquema canónico TP2–TP5.
- `TP6/00_ejecutar_tp5.sql` / `TP6/00_ejecutar_laboratorio.sql` — wrappers de `search_path`.
- `TP6/01_esquema_base.sql` / `TP6/02_poblado.sql` — laboratorio reproducible.
- `TP6/03_consulta_antes.sql` / `TP6/04_consulta_despues.sql` — mediciones del laboratorio.
- `TP6/03b_poblado_pico_hoy.sql` / `TP6/03c_consulta_antes_tp5.sql` / `TP6/04b_consulta_despues_tp5.sql` — mediciones de la base canónica.
- `TP6/05_prueba_sincronizacion.sql` / `TP6/05b_prueba_sincronizacion_tp5.sql` — 9 mutaciones con auditoría y `ROLLBACK`.
- `TP6/06_rollback.sql` — reversión.
- `TP6/07_auditoria.sql` / `TP6/07b_auditoria_tp5.sql` — auditoría independiente.
- `TP6/informe_parte2.md` — informe de la Parte 2.
- `TP6/informe_tp6.md` — informe completo Parte 1 + Parte 2.
- `TP6/resultados/` — planes `EXPLAIN ANALYZE` antes/después y salidas de auditoría de ambos entornos.
- `TP6/cambios/DUIA_TP6_Parte2_Desnormalizacion.md` — esta DUIA.

**Verificación**

- Auditoría de desincronización: **0 filas** en ambos entornos.
- Suma global fuente vs resumen: `TRUE`.
- Prueba de sincronización: **9 mutaciones verificadas, 0 desincronizaciones**.
- Validé todo en un clúster PostgreSQL 17 temporal y aislado (puerto 55434). No toqué tu base real ni hice commits.

**Nota:** el informe combinado está en `TP6/informe_tp6.md`, listo para convertir a PDF/Word. No generé el PDF/Word directamente porque este entorno no tiene Word ni pandoc instalados.

## Qué se aceptó

Se generó el paquete completo de la Parte 2: entregable SQL, scripts de soporte, mediciones, auditoría, rollback, informes y esta DUIA.

## Qué se modificó o descartó y por qué

-

## Verificación realizada

-
