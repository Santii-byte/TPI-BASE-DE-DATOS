# DUIA - Optimización de índices

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Actuá como un Administrador de Bases de Datos PostgreSQL experto en optimización y EXPLAIN ANALYZE. Sobre nuestro esquema masivo (cliente: 20k, producto: 50k, pedido: 200k, detalle_pedido: 400k), tenemos 3 consultas que sufren por escaneo secuencial (Seq Scan): 1. Historial de pedidos por cliente y fecha: SELECT id, fecha, total, estado FROM pedido WHERE cliente_id = 12450 AND fecha >= now() - interval '90 days'; (Genera Seq Scan on pedido, cost=0.00..4850.00, tiempo=~35ms) 2. Filtro de catálogo activo por rango de precio: SELECT id, nombre, precio, stock FROM producto WHERE activo = true AND precio BETWEEN 1500.00 AND 1800.00; (Genera Seq Scan on producto, cost=0.00..1450.00, tiempo=~12ms) 3. Búsqueda de líneas de venta por producto: SELECT dp.pedido_id, dp.cantidad, dp.precio_unitario, p.nombre FROM detalle_pedido dp JOIN producto p ON p.id = dp.producto_id WHERE dp.producto_id = 34500; (Genera Seq Scan on detalle_pedido, cost=0.00..9600.00, tiempo=~52ms) Generá un archivo llamado `optimizacion.sql` que contenga: - Las sentencias CREATE INDEX necesarias para optimizar cada una de las 3 consultas. - Para cada índice, un comentario que explique: qué nodo del plan ataca (Seq Scan), por qué se eligió esa estructura (índice compuesto, parcial o sobre clave foránea) y qué nuevo nodo se espera en el plan (Index Scan / Bitmap Index Scan). - Todo dentro de la estructura estándar para PostgreSQL."

## Qué generó
Asumo el rol DBA. Creado `optimizacion.sql` (sin commit, como exige tu protocolo):

* **Q1 – historial por cliente y fecha:** `CREATE INDEX ... ON pedido (cliente_id, fecha)`. Ataca el `Seq Scan on pedido`: la igualdad en `cliente_id` + rango en `fecha` piden un btree compuesto (equality-first, range-second); se espera `Index Scan` (o `Bitmap Heap Scan` + `Bitmap Index Scan` según selectividad). Supera al `idx_pedido_cliente_id` existente, que solo cubre la primera columna.
* **Q2 – catálogo activo por precio:** `CREATE INDEX ... ON producto (precio) WHERE activo = TRUE`. Ataca el `Seq Scan on producto`: el índice parcial encaja con el filtro invariante `activo = true` (índice pequeño, solo filas activas) y ordena por `precio` para el `BETWEEN`; se espera `Bitmap Index Scan`. El `idx_producto_activo` existente (solo columna `activo`) no resuelve rangos de precio.
* **Q3 – líneas por producto:** `CREATE INDEX ... ON detalle_pedido (producto_id)`. Ataca el `Seq Scan on detalle_pedido`: la PK compuesta `(pedido_id, producto_id)` no sirve para filtrar solo por `producto_id` (segunda columna), la FK queda sin soporte; índice btree simple sobre la FK. Se espera `Index Scan`/`Bitmap Index Scan` en detalle + `Nested Loop` con `Index Scan using producto_pkey` en el JOIN.
* **Cierre:** todo en transacción, `IF NOT EXISTS` (idempotente, estilo de `Script.sql`) y `ANALYZE` de las 3 tablas para que el planificador adopte los índices. Para aplicar sin bloquear escritura en producción, versión `CONCURRENTLY` fuera de transacción (nota en el archivo).

Ejecución sugerida en copia aislada: `psql -d copia_trabajo -f optimizacion.sql` y luego `EXPLAIN (ANALYZE, BUFFERS)` de las 3 consultas para confirmar los nodos. DUIA en `cambios/optimizacion_indices.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Archivo `optimizacion.sql` nuevo en la raíz del repo, más este DUIA en `cambios/optimizacion_indices.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
