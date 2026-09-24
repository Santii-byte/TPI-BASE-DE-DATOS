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