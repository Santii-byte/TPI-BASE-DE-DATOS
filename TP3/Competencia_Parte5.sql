EXPLAIN ANALYZE
SELECT id, nombre, precio, stock
FROM producto
WHERE activo = TRUE AND precio BETWEEN 1000.00 AND 3000.00
ORDER BY precio DESC
LIMIT 50;

-- 1.
CREATE INDEX IF NOT EXISTS idx_producto_activo_precio_desc
  ON producto (precio DESC) INCLUDE (nombre, stock)
  WHERE activo = TRUE;

-- 2. Actualizás el mapa de visibilidad de PostgreSQL (obligatorio para Index Only Scan)
VACUUM ANALYZE producto;

-- 3. Volvés a medir la consulta
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio, stock
FROM producto
WHERE activo = TRUE AND precio BETWEEN 1000.00 AND 3000.00
ORDER BY precio DESC
LIMIT 50;