-- ARCHIVO: consultas_postgresql.sql

-- Consulta equivalente a b): Filtrar pedidos por estado
SELECT id, estado, forma_pago, total 
FROM pedido 
WHERE estado = 'pagado'::public.estado_pedido;

-- Consulta equivalente a c): Buscar pedidos que contengan un producto determinado
SELECT DISTINCT p.id, p.estado, p.total
FROM pedido p
JOIN detalle_pedido dp ON p.id = dp.pedido_id
WHERE dp.producto_id = 1;