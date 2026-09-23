# DUIA - Tuning Top-N con índice descendente cubriente

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Actuá como especialista en tuning de PostgreSQL para una competencia de optimización. Tenemos la siguiente consulta lenta sobre una tabla 'producto' con 50.000 filas: EXPLAIN ANALYZE SELECT id, nombre, precio, stock FROM producto WHERE activo = TRUE AND precio BETWEEN 1000.00 AND 3000.00 ORDER BY precio DESC LIMIT 50; Actualmente ejecuta un Seq Scan y un Top-N Sort en memoria, tardando ~18.5 ms. Proponé: 1. Una estrategia de indexación avanzada (índice parcial compuesto o B-tree con orden descendente) que elimine tanto el Seq Scan como el nodo Sort (usando el índice para resolver el ORDER BY directamente). 2. Justificá la propuesta explicando qué nodos del plan elimina y por qué. 3. Generá las sentencias SQL listas para probar."

## Qué generó
Como especialista en tuning, propongo un btree parcial, descendente y cubriente:

```sql
CREATE INDEX IF NOT EXISTS idx_producto_activo_precio_desc
    ON producto (precio DESC) INCLUDE (nombre, stock)
    WHERE activo = TRUE;
ANALYZE producto;
```

**Nodos que elimina y por qué:**

* **Elimina el `Seq Scan`:** el rango `precio BETWEEN 1000 AND 3000` se resuelve como `Index Cond` dentro del índice y el filtro `activo = TRUE` ya viene absorbido por el predicado parcial (el índice solo contiene filas activas). No se leen las 50k filas.
* **Elimina el `Sort` (Top-N):** el índice está físicamente ordenado por `precio DESC`, exactamente igual que el `ORDER BY`. El motor recorre el índice en orden y corta en `LIMIT 50` sin ordenar nada: el orden sale gratis del índice.
* **Por qué `DESC` y no el índice ASC de Q2:** el ASC obligaría a un backward scan para este `ORDER BY ... DESC`; declarar `DESC` calza el orden exacto del Top-N. Es un índice distinto al `idx_producto_precio_activo` (ese sirve rangos sin orden; este sirve rango + orden + límite).
* **Por qué `INCLUDE (nombre, stock)`:** vuelve al índice cubriente: `id` sale de la entrada, `nombre` y `stock` de las columnas incluidas, así el plan puede ser `Index Only Scan` sin visitar el heap (requiere visibility map al día: `VACUUM ANALYZE` tras la carga masiva).

**Sentencias listas para probar:**

```sql
CREATE INDEX IF NOT EXISTS idx_producto_activo_precio_desc
    ON producto (precio DESC) INCLUDE (nombre, stock)
    WHERE activo = TRUE;
ANALYZE producto;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio, stock
FROM producto
WHERE activo = TRUE AND precio BETWEEN 1000.00 AND 3000.00
ORDER BY precio DESC
LIMIT 50;
```

**Plan esperado:** `Limit -> Index Only Scan using idx_producto_activo_precio_desc` (`Index Cond` con el rango), sin `Sort` ni `Seq Scan`, tiempo esperado < 1 ms contra ~18.5 ms actuales. Si el `Index Only Scan` reporta `Heap Fetches` alto, correr `VACUUM ANALYZE producto;` y repetir. Documentado en `TP3/DUIA_Parte8.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Propuesta entregada en el chat, más este DUIA en `TP3/DUIA_Parte8.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
