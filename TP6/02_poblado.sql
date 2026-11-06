-- ============================================================================
-- TP 6 — Parte 2 / 02: Poblado de la instancia Food Store
-- PostgreSQL 16+
-- ============================================================================
-- Volumen: 60 categorías, 20.000 clientes, 30.000 productos,
-- 300.000 pedidos (40 % de hoy) y ~1.200.000 renglones de detalle.
-- El setseed hace reproducible la generación.
-- ============================================================================

BEGIN;
SET LOCAL search_path TO tp6_p2, public;
SELECT setseed(0.6);

-- 1. Categorías
INSERT INTO categoria (nombre)
SELECT 'Categoría ' || lpad(g::text, 2, '0')
FROM generate_series(1, 60) AS g;

-- 2. Clientes
INSERT INTO cliente (nombre, email, activo, created_at)
SELECT 'Cliente ' || g,
       'cliente' || g || '@test.com',
       random() < 0.95,
       now() - (random() * INTERVAL '365 days')
FROM generate_series(1, 20000) AS g;

-- 3. Productos: categoría aleatoria, 3 % eliminados
INSERT INTO producto (nombre, precio, stock, activo, categoria_id, eliminado, created_at)
SELECT 'Producto ' || g,
       (500 + random() * 4500)::NUMERIC(12, 2),
       floor(random() * 201)::INTEGER,
       random() < 0.90,
       (1 + floor(random() * 60))::BIGINT,
       random() < 0.03,
       now() - (random() * INTERVAL '365 days')
FROM generate_series(1, 30000) AS g;

-- 4. Pedidos: 40 % de hoy, 5 % eliminados (soft delete)
INSERT INTO pedido (cliente_id, fecha, total, estado, forma_pago, eliminado)
SELECT (1 + floor(random() * 20000))::BIGINT,
       CASE WHEN random() < 0.40
            THEN CURRENT_DATE
            ELSE CURRENT_DATE - (1 + floor(random() * 364))::INTEGER
       END,
       0.00,
       (ARRAY['pendiente', 'pagado', 'enviado', 'cancelado'])[(1 + floor(random() * 4))::INTEGER]::estado_pedido,
       (ARRAY['efectivo', 'tarjeta_credito', 'tarjeta_debito', 'transferencia'])[(1 + floor(random() * 4))::INTEGER]::metodo_pago,
       random() < 0.05
FROM generate_series(1, 300000);

-- 5. Detalle: ~1.2 M de renglones; 8 % eliminados (soft delete)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, eliminado)
SELECT x.pedido_id,
       x.producto_id,
       x.cantidad,
       pr.precio,
       random() < 0.08
FROM (
    SELECT (1 + floor(random() * 300000))::BIGINT AS pedido_id,
           (1 + floor(random() * 30000))::BIGINT  AS producto_id,
           (1 + floor(random() * 5))::INTEGER     AS cantidad
    FROM generate_series(1, 1200000)
) AS x
JOIN producto AS pr ON pr.id = x.producto_id
ON CONFLICT (pedido_id, producto_id) DO NOTHING;

-- 6. Coherencia del total del pedido (solo para realismo; la consulta no lo usa)
UPDATE pedido AS p
SET total = COALESCE(sub.total, 0.00)
FROM (
    SELECT pedido_id, SUM(subtotal)::NUMERIC(14, 2) AS total
    FROM detalle_pedido
    GROUP BY pedido_id
) AS sub
WHERE p.id = sub.pedido_id;

COMMIT;

-- 7. Estadísticas para que el planificador tome decisiones realistas
ANALYZE tp6_p2.categoria;
ANALYZE tp6_p2.cliente;
ANALYZE tp6_p2.producto;
ANALYZE tp6_p2.pedido;
ANALYZE tp6_p2.detalle_pedido;

-- 8. Verificación de volumen
SELECT 'categoria' AS tabla, count(*) AS filas FROM tp6_p2.categoria
UNION ALL
SELECT 'cliente', count(*) FROM tp6_p2.cliente
UNION ALL
SELECT 'producto', count(*) FROM tp6_p2.producto
UNION ALL
SELECT 'pedido', count(*) FROM tp6_p2.pedido
UNION ALL
SELECT 'pedido de hoy', count(*) FROM tp6_p2.pedido WHERE fecha = CURRENT_DATE
UNION ALL
SELECT 'detalle_pedido', count(*) FROM tp6_p2.detalle_pedido;
