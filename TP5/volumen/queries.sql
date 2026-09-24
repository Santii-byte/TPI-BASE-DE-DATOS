
-- Parte 1

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

-- Parte 2

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

-- Parte 3

-- Sentido 1: Filas en A que no estén en B
(
    WITH gasto AS (
        SELECT c.id AS id_cliente,
               c.nombre AS nombre_cliente,
               SUM(p.total) AS total_gastado
        FROM cliente AS c
        JOIN pedido AS p ON p.cliente_id = c.id
        WHERE c.activo = TRUE
          AND p.estado IN ('pagado', 'enviado')
        GROUP BY c.id, c.nombre
    )
    SELECT id_cliente, nombre_cliente, total_gastado,
           DENSE_RANK() OVER (ORDER BY total_gastado DESC, id_cliente ASC) AS ranking_gasto
    FROM gasto
)
EXCEPT
(
    SELECT g.id_cliente, g.nombre_cliente, g.total_gastado,
           DENSE_RANK() OVER (ORDER BY g.total_gastado DESC, g.id_cliente ASC) AS ranking_gasto
    FROM (
        SELECT c.id AS id_cliente,
               c.nombre AS nombre_cliente,
               SUM(p.total) AS total_gastado
        FROM cliente AS c
        JOIN pedido AS p ON p.cliente_id = c.id
        WHERE c.activo = TRUE
          AND p.estado IN ('pagado', 'enviado')
        GROUP BY c.id, c.nombre
    ) AS g
);


WITH v1 AS (
    SELECT c.id AS id_cliente,
           c.nombre AS nombre_cliente,
           p.id AS id_pedido,
           p.fecha AS fecha_pedido,
           p.total AS monto_pedido
    FROM cliente AS c
    JOIN pedido AS p ON p.cliente_id = c.id
    WHERE c.activo = TRUE
      AND p.estado IN ('pagado', 'enviado')
      AND p.fecha >= now() - INTERVAL '365 days'
      AND p.total > (
          SELECT AVG(p2.total)
          FROM pedido AS p2
          WHERE p2.cliente_id = c.id
            AND p2.fecha >= now() - INTERVAL '365 days'
      )
),
v2 AS (
    WITH promedio_cliente AS (
        SELECT cliente_id, AVG(total) AS promedio
        FROM pedido
        WHERE fecha >= now() - INTERVAL '365 days'
        GROUP BY cliente_id
    )
    SELECT c.id AS id_cliente,
           c.nombre AS nombre_cliente,
           p.id AS id_pedido,
           p.fecha AS fecha_pedido,
           p.total AS monto_pedido
    FROM cliente AS c
    JOIN pedido AS p ON p.cliente_id = c.id
    JOIN promedio_cliente AS pc ON pc.cliente_id = c.id
    WHERE c.activo = TRUE
      AND p.estado IN ('pagado', 'enviado')
      AND p.fecha >= now() - INTERVAL '365 days'
      AND p.total > pc.promedio
)
(SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v1
 EXCEPT
 SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v2)
UNION ALL
(SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v2
 EXCEPT
 SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v1);

-- Parte 4

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