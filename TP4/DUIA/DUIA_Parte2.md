# DUIA - Explicación plan ranking con agregación temprana

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Explica el siguiente plan de ejecución de PostgreSQL nodo por nodo en lenguaje natural, sin asumir ningún contexto previo de la base de datos. Identifica con exactitud: (1) en cada nodo de join, qué tabla actúa como externa/conductora (outer) y cuál como interna (inner), y (2) en qué nodo específico se consume la mayor cantidad de tiempo neto: [plan Limit -> Sort top-N -> HashAggregate Group Key c.id -> Hash Join p.cliente_id=c.id -> HashAggregate Group Key p.id con Batches 5 y Disk 3392kB -> Hash Join dp.pedido_id=p.id -> Seq Scan detalle 399993 + Hash de Bitmap Heap Scan pedido con Bitmap Index Scan on idx_pedido_estado_fecha + Seq Scan cliente activos, Execution Time 210.897 ms]"

## Qué generó
Se nota que aplicaste la Parte10: aparece `idx_pedido_estado_fecha` y la agregación temprana por pedido. Total: 210.9 ms (antes 295.7 ms, −29%). Aclaración clave: los tiempos `actual` son acumulativos (cada nodo incluye el de sus hijos), así que el tiempo neto = tiempo del nodo − tiempo de sus hijos. Lectura de abajo hacia arriba:

* **`Seq Scan on detalle_pedido` (15.8 ms netos, hoja):** lee una por una las 400k filas de la tabla de líneas, sin índice (correcto: se necesita casi toda la tabla).
* **`Bitmap Index Scan on idx_pedido_estado_fecha` (3.2 ms netos, hoja):** busca en el índice parcial solo el rango `fecha >= now()-180d` (`Index Cond`); el filtro de `estado` viene implícito en el predicado parcial. Encuentra 49.162 entradas.
* **`Bitmap Heap Scan on pedido` (~7.5 ms netos):** con el mapa de bits va al disco solo a las 3196 páginas necesarias y con `Recheck Cond` re-verifica `fecha` y `estado` fila por fila (algunas páginas traen filas vecinas que no sirven).
* **`Hash` sobre pedido (~5.8 ms netos):** mete esas 49k filas en una tabla hash en memoria (2817 kB) para búsquedas instantáneas por `id`.
* **`Hash Join (dp.pedido_id = p.id)` (~78.1 ms netos):** tabla externa/conductora = `detalle_pedido` (se recorren sus 400k filas una por una); tabla interna = `pedido` (la hash ya construida). Cada línea busca su pedido en el hash: ~98k coinciden.
* **`HashAggregate` por `p.id` (~73.4 ms netos):** agrupa esas ~98k filas en 42.601 montos por pedido. Es el segundo puesto y arrastra el único derrame que queda: `Batches: 5`, `Disk Usage: 3392kB` (`temp written=606`): el hash de agregación no entró en memoria y partió a disco.
* **`Seq Scan on cliente` + `Hash` (~4.1 ms entre ambos):** lee los 19k clientes activos y los hashea (1249 kB) por `id`.
* **`Hash Join (p.cliente_id = c.id)` (~13.8 ms netos):** externa = el subresultado ya agregado por pedido (42.6k filas); interna = `cliente` (la hash). Pega a cada monto su cliente.
* **`HashAggregate` por `c.id` (~18 ms netos):** agrupa en 16.714 totales por cliente, todo en memoria (`Batches: 1`, 7697 kB, sin disco).
* **`Sort` top-N (~2.4 ms) + `Limit` (~0 ms):** ordena solo para quedarse con las mejores 20 filas (heapsort de 27 kB en memoria); el `Limit` corta ahí y por eso los nodos de abajo igual trabajaron de más: calcularon los 16.714 grupos.

**Respuestas exactas:** (1) Join 1: outer `detalle_pedido`, inner `pedido`. Join 2: outer subconsulta agregada por pedido, inner `cliente`. (2) El mayor tiempo neto está en el `Hash Join` detalle↔pedido (~78 ms); segundo, el `HashAggregate` por pedido (~73 ms, inflado por su spill a disco). Próximo paso sugerido: `SET LOCAL work_mem` para que ese hash agregado entre en memoria. Documentado en `TP3/DUIA_Parte11.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Explicación entregada en el chat, más este DUIA en `TP3/DUIA_Parte11.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
