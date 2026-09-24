-- ============================================================================
-- poblado_masivo.sql — Carga masiva de datos de prueba (PostgreSQL puro)
-- ============================================================================
-- Uso: psql -d copia_trabajo -f poblado_masivo.sql
--
-- Supuesto: base recién creada desde Script.sql (tablas vacías e
-- identidades arrancando en 1). Los id aleatorios se generan por rango:
--   cliente    1..20000 | producto 1..50000 | pedido 1..200000
-- Si las tablas ya tienen datos, los rangos deben ajustarse al id real.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. CLIENTES (20.000) — emails únicos 'clienteN@test.com'
-- ----------------------------------------------------------------------------
INSERT INTO cliente (nombre, email, telefono, activo, created_at)
SELECT
    'Cliente ' || g,
    'cliente' || g || '@test.com',
    CASE WHEN random() < 0.80
         THEN '+54 11 ' || (10000000 + floor(random() * 89999999))::bigint::text
         ELSE NULL END,
    random() < 0.95,
    now() - (random() * INTERVAL '365 days')
FROM generate_series(1, 20000) AS g;

-- ----------------------------------------------------------------------------
-- 2. PRODUCTOS (50.000) — precio 500..5000, stock 0..200
-- ----------------------------------------------------------------------------
INSERT INTO producto (nombre, precio, stock, activo, created_at)
SELECT
    'Producto ' || g,
    (500 + random() * 4500)::NUMERIC(12, 2),
    floor(random() * 201)::INTEGER,
    random() < 0.90,
    now() - (random() * INTERVAL '365 days')
FROM generate_series(1, 50000) AS g;

-- ----------------------------------------------------------------------------
-- 3. PEDIDOS (200.000) — cliente aleatorio, fecha dentro del último año
--    (fecha <= now(), respeta el CHECK de pedido.fecha).
--    El total se deja en 0.00 y se recalcula en el paso 5.
-- ----------------------------------------------------------------------------
INSERT INTO pedido (cliente_id, fecha, total, estado, forma_pago)
SELECT
    (1 + floor(random() * 20000))::BIGINT,
    now() - (random() * INTERVAL '365 days'),
    0.00,
    (ARRAY['pendiente', 'pagado', 'enviado', 'cancelado'])[(1 + floor(random() * 4))::INTEGER]::estado_pedido,
    (ARRAY['efectivo', 'tarjeta_credito', 'tarjeta_debito', 'transferencia'])[(1 + floor(random() * 4))::INTEGER]::metodo_pago
FROM generate_series(1, 200000);

-- ----------------------------------------------------------------------------
-- 4. DETALLE_PEDIDO (400.000) — pedido/producto aleatorios, cantidad 1..5.
--    precio_unitario se copia del precio real del producto (> 0, respeta
--    el CHECK estricto). ON CONFLICT evita abortar por pares aleatorios
--    repetidos (clave primaria compuesta); el conteo final puede quedar
--    levemente por debajo de 400.000 por esas colisiones.
-- ----------------------------------------------------------------------------
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT x.pedido_id, x.producto_id, x.cantidad, pr.precio
FROM (
    SELECT
        (1 + floor(random() * 200000))::BIGINT AS pedido_id,
        (1 + floor(random() * 50000))::BIGINT  AS producto_id,
        (1 + floor(random() * 5))::INTEGER     AS cantidad
    FROM generate_series(1, 400000)
) AS x
JOIN producto AS pr ON pr.id = x.producto_id
ON CONFLICT (pedido_id, producto_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. Coherencia: total del pedido = suma(cantidad * precio_unitario)
-- ----------------------------------------------------------------------------
UPDATE pedido AS p
SET total = sub.total
FROM (
    SELECT pedido_id, SUM(cantidad * precio_unitario)::NUMERIC(12, 2) AS total
    FROM detalle_pedido
    GROUP BY pedido_id
) AS sub
WHERE p.id = sub.pedido_id;

COMMIT;

-- ----------------------------------------------------------------------------
-- 6. Estadísticas del planificador para todas las tablas
-- ----------------------------------------------------------------------------
ANALYZE cliente;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- ----------------------------------------------------------------------------
-- 7. Verificación de conteos
-- ----------------------------------------------------------------------------
SELECT 'cliente' AS tabla, count(*) FROM cliente
UNION ALL
SELECT 'producto', count(*) FROM producto
UNION ALL
SELECT 'pedido', count(*) FROM pedido
UNION ALL
SELECT 'detalle_pedido', count(*) FROM detalle_pedido;

EXPLAIN ANALYZE
SELECT id, fecha, total, estado 
FROM pedido 
WHERE cliente_id = 12450 
  AND fecha >= now() - interval '90 days';
