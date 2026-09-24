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