# DUIA - Explicación plan Q2

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Explicá en lenguaje natural y nodo por nodo qué hace este plan de ejecución de PostgreSQL obtenido con EXPLAIN ANALYZE:

Bitmap Heap Scan on producto  (cost=4.85..175.20 rows=230 width=45) (actual time=0.120..0.980 rows=228 loops=1)
  Recheck Cond: ((precio >= 1500.00) AND (precio <= 1800.00) AND (activo = true))
  ->  Bitmap Index Scan on idx_producto_precio_activo  (cost=0.00..4.80 rows=230 width=0) (actual time=0.085..0.085 rows=228 loops=1)
        Index Cond: ((precio >= 1500.00) AND (precio <= 1800.00))
Planning Time: 0.150 ms
Execution Time: 1.100 ms"

## Qué generó
Este plan confirma que el índice parcial de Q2 funcionó: ya no hay `Seq Scan`. Se lee de adentro hacia afuera (primero el nodo hijo). Tiempos: planificó en 0.150 ms y ejecutó en 1.100 ms (antes ~12 ms del Seq Scan: ~10x más rápido).

* **Nodo hijo – `Bitmap Index Scan on idx_producto_precio_activo` (se ejecuta primero):** recorre el índice parcial con la condición de rango `precio BETWEEN 1500.00 AND 1800.00` (`Index Cond`). No necesita chequear `activo = true` acá porque el índice parcial ya solo contiene filas activas (el predicado está implícito). Estimó 230 filas y encontró 228 en 0.085 ms. No devuelve filas sino un bitmap en memoria con las páginas del heap donde están esas filas.
* **Nodo padre – `Bitmap Heap Scan on producto` (se ejecuta después):** lee del disco solo las páginas marcadas en el bitmap, en orden físico (así evita lecturas aleatorias), y extrae las columnas pedidas (`width=45` bytes promedio por fila: id, nombre, precio, stock). Con `Recheck Cond` re-verifica `precio` y `activo` fila por fila, porque el bitmap puede traer páginas con filas vecinas que no cumplen. Devolvió las 228 filas en 0.980 ms.
* **Estimación vs realidad:** el planificador estimó costo `4.85..175.20` (costo de arranque..total en unidades arbitrarias, no ms) y 230 filas contra 228 reales: estimación excelente, señal de estadísticas al día (gracias al `ANALYZE`).
* **Por qué bitmap y no `Index Scan` directo:** el rango trae 228 filas dispersas por la tabla; el bitmap agrupa las lecturas por página física en vez de saltar fila por fila, que es lo óptimo en este volumen.

En resumen: índice parcial usado, `activo` absorbido por el predicado del índice, rango resuelto por bitmap y heap leído solo donde hace falta.

## Qué se aceptó
Explicación entregada en el chat, más este DUIA en `TP3/DUIA_Parte3.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
