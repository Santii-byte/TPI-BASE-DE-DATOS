# DUIA - Spec optimización consultas Food Store

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"# spec: optimizacion_consultas_food_store. Objetivo: Diseñar los índices óptimos para tres consultas críticas en PostgreSQL 16 sobre el esquema Food Store y evaluar sobreindexación. Contexto: pedido (~200k), producto (~50k), detalle_pedido (~400k). Carga: A) pedidos de un cliente en rango de fechas; B) activos por rango de precio ORDER BY precio DESC LIMIT 50; C) agregación por producto sobre detalle_pedido. Tareas: 1. CREATE INDEX por consulta evitando Seq Scan (Index Scan / Index Only Scan). 2. Un 4to índice candidato a DESCARTE por sobreindexación con justificación. 3. Script SQL para medir el impacto en escritura masiva (INSERT de 10.000 filas en detalle_pedido)."

## Qué generó
Spec implementada en `TP3/` (sin commit, como exige tu protocolo).

**Índices (`TP3/optimizacion_consultas_food_store.sql`):**

* **A – `ON pedido (cliente_id, fecha) INCLUDE (id, total, estado)`:** compuesto equality-first + range-second y cubriente con las columnas de salida → `Index Only Scan`, sin tocar el heap de 200k filas.
* **B – `ON producto (precio DESC) INCLUDE (nombre, stock) WHERE activo = TRUE`:** parcial (solo activos) + descendente (calza el `ORDER BY`, sin `Sort`, corte en 50) + cubriente → `Index Only Scan`.
* **C – `ON detalle_pedido (producto_id) INCLUDE (cantidad, precio_unitario)`:** cubriente ordenado por la clave de agrupación → `Index Only Scan` + `GroupAggregate` en streaming sin `Sort`.

**4to índice – DESCARTE documentado en el archivo: `ON pedido (estado)`.** Baja cardinalidad (4 valores, ~25% cada uno): ningún filtro es selectivo, el planificador jamás lo elegiría y solo sumaría mantenimiento en cada escritura + disco + `VACUUM`. Tampoco crear un `(producto_id)` simple existiendo el covering de C (redundancia).

**Medición de escritura (`TP3/medicion_escritura.sql`):** dos tablas espejo (con/sin el covering de C), mismo lote reproducible de 10k filas (`setseed`), `EXPLAIN (ANALYZE)` en ambos `INSERT`, comparativa de tamaños con `pg_relation_size` y limpieza final. Solo en copia aislada. Criterio de lectura incluido: si el sobrecosto es < 10-15% y C se usa a diario, el trade-off justifica el índice. Documentado en `TP3/DUIA_Parte15.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Archivos entregados (`optimizacion_consultas_food_store.sql`, `medicion_escritura.sql`), más este DUIA en `TP3/DUIA_Parte15.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
