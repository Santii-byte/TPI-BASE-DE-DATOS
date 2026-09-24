EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    c.id AS cliente_id,
    c.nombre AS cliente_nombre,
    p.forma_pago,
    COUNT(DISTINCT p.id) AS total_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS monto_total
FROM cliente c
JOIN pedido p ON c.id = p.cliente_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE c.activo = TRUE
  AND p.estado IN ('pagado', 'enviado')
  AND p.fecha >= now() - INTERVAL '365 days'
GROUP BY c.id, c.nombre, p.forma_pago
ORDER BY monto_total DESC
LIMIT 50;

BEGIN;
SET LOCAL work_mem = '64MB';

EXPLAIN (ANALYZE, BUFFERS)
WITH monto_pedido AS (
    SELECT p.id, p.cliente_id, p.forma_pago,
           SUM(dp.cantidad * dp.precio_unitario) AS monto
    FROM pedido AS p
    JOIN detalle_pedido AS dp ON dp.pedido_id = p.id
    WHERE p.estado IN ('pagado', 'enviado')
      AND p.fecha >= now() - INTERVAL '365 days'
    GROUP BY p.id, p.cliente_id, p.forma_pago
)
SELECT c.id, c.nombre, m.forma_pago, SUM(m.monto) AS total
FROM cliente AS c
JOIN monto_pedido AS m ON m.cliente_id = c.id
WHERE c.activo
GROUP BY c.id, c.nombre, m.forma_pago
ORDER BY total DESC
LIMIT 50;

COMMIT;