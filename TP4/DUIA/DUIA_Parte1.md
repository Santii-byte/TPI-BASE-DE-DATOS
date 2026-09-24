# DUIA - Tuning spill a disco en Top-20 por recaudación

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Tengo este plan de ejecución real sobre PostgreSQL: [plan con Limit -> Sort top-N -> Finalize GroupAggregate -> Gather Merge -> Partial GroupAggregate -> Sort external merge Disk 4176kB con temp read/written -> Hash Join dp=pr -> Parallel Hash Join dp=p -> Parallel Seq Scans + Parallel Hash, Execution Time 313.381 ms]. Propón la mejor estrategia de optimización para reducir el tiempo de ejecución y eliminar los spills a disco (external merge en temp buffers). Explica qué índice crear y por qué, y predice si el optimizador cambiará el algoritmo de join."

## Qué generó
Diagnóstico (313 ms): el tiempo se va en 3 lugares: (1) el `Sort` por `pr.id` con `external merge` (~4 MB por worker, `temp read/written`) que alimenta al `Partial GroupAggregate`; (2) el hash de ~400k filas de `detalle_pedido` + ~100k de `pedido`; (3) agrega 46.608 grupos para quedarse con 20 (el `Sort` final top-N es barato: 27 kB en memoria, ese no es el problema).

**Índice propuesto (covering sobre la tabla de hechos):**

```sql
CREATE INDEX IF NOT EXISTS idx_detalle_producto_cover
    ON detalle_pedido (producto_id) INCLUDE (cantidad, precio_unitario);
VACUUM ANALYZE detalle_pedido;
```

**Por qué este índice:** `detalle_pedido` es la tabla más leída del plan (2942 buffers por worker). El índice cubriente convierte ese acceso en `Index-Only Scan`: sin visitas al heap (el `VACUUM` deja el visibility map al día), menos buffers y filas angostas. Además entrega las filas ordenadas por `producto_id`, que es la clave de agrupación (`Group Key: pr.id`): es el único índice que a la vez achica el I/O y ordena por la clave del `GroupAggregate`.

**Predicción sobre los joins: NO cambian, y está bien que no cambien.** Los `Hash Join` se mantienen porque ~50% de `detalle_pedido` participa del join: con esa selectividad, seq scan + hash es óptimo y ningún índice lo supera; un `Nested Loop` implicaría cientos de miles de probes y costaría más. El optimizador solo elegiría `Nested Loop` con este índice si el filtro fuera selectivo (ej. un solo producto, como en Q3). Lo que sí cambia: el acceso a `detalle_pedido` pasa a `Index-Only`/`Bitmap` y el `Sort` previo a la agregación trabaja con filas angostas ya ordenadas por producto.

**Para eliminar el spill de forma determinista:** el `external merge` existe porque el sort (~4-5 MB por worker) supera el `work_mem` default de 4 MB. Para la prueba: `SET LOCAL work_mem = '16MB';` antes de la consulta (el sort cabe en memoria, adiós `temp written`). Cambio global solo si el servidor tiene RAM de sobra (cada worker y cada nodo Sort lo multiplica).

**Plan esperado:** mismos `Hash Join`, `Index-Only Scan` en detalle, `Sort` en memoria (o reducido) + `GroupAggregate`, `Limit` intacto; tiempo esperado muy por debajo de 100 ms. Si la consulta se repite mucho en la competencia, la movida ganadora real es una tabla de resumen/`MATERIALIZED VIEW` por producto (el Top-20 sobre 46k grupos es trabajo inherente). Documentado en `TP3/DUIA_Parte9.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Propuesta entregada en el chat, más este DUIA en `TP3/DUIA_Parte9.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
