-- ============================================================================
-- TP 6 — Parte 2 / 07: Auditoría de desincronización (script independiente)
-- ============================================================================
-- Compara la fuente de verdad con el resumen. Resultado esperado: 0 filas.
-- ============================================================================

SET search_path TO tp6_p2, public;

WITH fuente AS (
    SELECT pr.categoria_id,
           p.fecha::date,
           SUM(dp.subtotal)::NUMERIC(14, 2) AS total_vendido
      FROM detalle_pedido AS dp
      JOIN pedido AS p    ON p.id = dp.pedido_id
      JOIN producto AS pr ON pr.id = dp.producto_id
     WHERE dp.eliminado = FALSE
       AND p.eliminado = FALSE
     GROUP BY pr.categoria_id, p.fecha::date
),
resumen AS (
    SELECT categoria_id, fecha, total_vendido
      FROM resumen_venta_categoria_dia
)
SELECT COALESCE(f.categoria_id, r.categoria_id) AS categoria_id,
       COALESCE(f.fecha, r.fecha)               AS fecha,
       f.total_vendido                          AS total_fuente,
       r.total_vendido                          AS total_resumen,
       CASE
           WHEN f.categoria_id IS NULL THEN 'fila sobrante en el resumen'
           WHEN r.categoria_id IS NULL THEN 'fila faltante en el resumen'
           ELSE 'total desincronizado'
       END AS problema
  FROM fuente AS f
  FULL OUTER JOIN resumen AS r
    ON r.categoria_id = f.categoria_id
   AND r.fecha = f.fecha
 WHERE f.total_vendido IS DISTINCT FROM r.total_vendido
 ORDER BY fecha, categoria_id;

-- Control global: debe devolver TRUE
SELECT (SELECT COALESCE(SUM(total_vendido), 0) FROM resumen_venta_categoria_dia) =
       (SELECT COALESCE(SUM(dp.subtotal), 0)
          FROM detalle_pedido dp
          JOIN pedido p ON p.id = dp.pedido_id
         WHERE dp.eliminado = FALSE
           AND p.eliminado = FALSE) AS suma_global_coincide;
