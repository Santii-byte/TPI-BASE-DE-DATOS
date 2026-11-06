-- ============================================================================
-- TP 6 — Parte 2 / 03b: Pico de ventas del día para la base canónica TP2–TP5
-- ============================================================================
-- La carga masiva de TP3/TP5 distribuye 200.000 pedidos a lo largo de un año,
-- por lo que el día actual tiene muy poco volumen y no representa el pico
-- que justifica el reporte. Este script agrega, SOLO PARA LA MEDICIÓN,
-- 100.000 pedidos de hoy y ~400.000 renglones de detalle.
--
-- Ejecutar sobre una COPIA de trabajo, no sobre producción.
-- ============================================================================

BEGIN;
SET LOCAL search_path TO public;

CREATE TEMP TABLE _nuevos_pedidos (id BIGINT) ON COMMIT DROP;

WITH ins AS (
    INSERT INTO pedido (cliente_id, fecha, total, estado, forma_pago)
    SELECT (1 + floor(random() * 20000))::BIGINT,
           now(),
           0.00,
           (ARRAY['pendiente', 'pagado', 'enviado', 'cancelado'])[(1 + floor(random() * 4))::INTEGER]::estado_pedido,
           (ARRAY['efectivo', 'tarjeta_credito', 'tarjeta_debito', 'transferencia'])[(1 + floor(random() * 4))::INTEGER]::metodo_pago
    FROM generate_series(1, 100000)
    RETURNING id
)
INSERT INTO _nuevos_pedidos (id)
SELECT id FROM ins;

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT n.id,
       x.producto_id,
       x.cantidad,
       pr.precio
FROM _nuevos_pedidos AS n
CROSS JOIN LATERAL (
    SELECT (1 + floor(random() * 50000))::BIGINT AS producto_id,
           (1 + floor(random() * 5))::INTEGER     AS cantidad
    FROM generate_series(1, 4)
) AS x
JOIN producto AS pr ON pr.id = x.producto_id
ON CONFLICT (pedido_id, producto_id) DO NOTHING;

COMMIT;

ANALYZE public.pedido;
ANALYZE public.detalle_pedido;

SELECT 'pedidos de hoy' AS metrica, count(*) AS filas
  FROM public.pedido
 WHERE fecha::date = CURRENT_DATE
UNION ALL
SELECT 'detalles de hoy', count(*)
  FROM public.detalle_pedido dp
  JOIN public.pedido p ON p.id = dp.pedido_id
 WHERE p.fecha::date = CURRENT_DATE;
