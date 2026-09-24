-- 1.
CREATE INDEX IF NOT EXISTS idx_detalle_producto_cover
  ON detalle_pedido (producto_id) INCLUDE (cantidad, precio_unitario);

-- 2. Actualizar estadísticas y visibility map
VACUUM ANALYZE detalle_pedido;

BEGIN;
SET LOCAL work_mem = '16MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    pr.id AS producto_id,
    pr.nombre AS producto_nombre,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM producto pr
JOIN detalle_pedido dp ON pr.id = dp.producto_id
JOIN pedido p ON dp.pedido_id = p.id
WHERE p.estado IN ('pagado', 'enviado')
  AND pr.activo = TRUE
GROUP BY pr.id, pr.nombre
ORDER BY facturacion_total DESC
LIMIT 20;

COMMIT;

EXPLAIN (ANALYZE, BUFFERS)
WITH pedidos_validos AS (
    SELECT id
    FROM pedido
    WHERE estado IN ('pagado', 'enviado')
),
ventas_por_producto AS (
    SELECT 
        dp.producto_id,
        SUM(dp.cantidad) AS unidades_vendidas,
        SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
    FROM detalle_pedido dp
    JOIN pedidos_validos pv ON dp.pedido_id = pv.id
    GROUP BY dp.producto_id
)
SELECT 
    pr.id AS producto_id,
    pr.nombre AS producto_nombre,
    v.unidades_vendidas,
    v.facturacion_total
FROM ventas_por_producto v
JOIN producto pr ON v.producto_id = pr.id
WHERE pr.activo = TRUE
ORDER BY v.facturacion_total DESC
LIMIT 20;

EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.id AS cliente_id,
    c.nombre AS cliente_nombre,
    c.email,
    COUNT(DISTINCT p.id) AS cantidad_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
FROM cliente c
JOIN pedido p ON c.id = p.cliente_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE c.activo = TRUE
  AND p.estado IN ('pagado', 'enviado')
  AND p.fecha >= now() - INTERVAL '180 days'
GROUP BY c.id, c.nombre, c.email
ORDER BY gasto_total DESC
LIMIT 20;

CREATE INDEX IF NOT EXISTS idx_pedido_estado_fecha
  ON pedido (fecha) WHERE estado IN ('pagado', 'enviado');

CREATE INDEX IF NOT EXISTS idx_detalle_pedido_cover
  ON detalle_pedido (pedido_id) INCLUDE (cantidad, precio_unitario);

VACUUM ANALYZE pedido;
VACUUM ANALYZE detalle_pedido;

EXPLAIN (ANALYZE, BUFFERS)
WITH monto_pedido AS (
    SELECT p.id, p.cliente_id,
           SUM(dp.cantidad * dp.precio_unitario) AS monto
    FROM pedido AS p
    JOIN detalle_pedido AS dp ON dp.pedido_id = p.id
    WHERE p.estado IN ('pagado', 'enviado')
      AND p.fecha >= now() - INTERVAL '180 days'
    GROUP BY p.id, p.cliente_id
)
SELECT c.id, c.nombre, SUM(m.monto) AS total
FROM cliente AS c
JOIN monto_pedido AS m ON m.cliente_id = c.id
WHERE c.activo
GROUP BY c.id, c.nombre
ORDER BY total DESC
LIMIT 20;