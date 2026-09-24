-- Vista 1: Productos vigentes
CREATE VIEW vista_productos_vigentes AS
SELECT 
    id, 
    nombre, 
    precio, 
    stock 
FROM public.producto
WHERE activo = true;

-- Vista 2: Pedidos con datos del cliente (Criterio de Seguridad aplicado)
CREATE VIEW vista_pedidos_cliente AS
SELECT 
    p.id AS pedido_id, 
    p.fecha, 
    p.total, 
    p.estado, 
    c.id AS cliente_id, 
    c.nombre AS cliente_nombre
    -- NOTA DE SEGURIDAD: email y telefono omitidos intencionalmente
FROM public.pedido p
JOIN public.cliente c ON p.cliente_id = c.id;

-- Vista 3: Detalle de pedido con nombre del producto
CREATE VIEW vista_detalle_producto AS
SELECT 
    dp.pedido_id, 
    dp.cantidad, 
    dp.precio_unitario, 
    pr.nombre AS producto_nombre
FROM public.detalle_pedido dp
JOIN public.producto pr ON dp.producto_id = pr.id;

