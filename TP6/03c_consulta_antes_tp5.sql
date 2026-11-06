-- ============================================================================
-- TP 6 — Parte 2 / 03c: Consulta ANTES sobre la base canónica TP2–TP5
-- ============================================================================
-- Usa pedido.fecha TIMESTAMPTZ (esquema original). El filtro "hoy" se
-- expresa como rango [CURRENT_DATE, CURRENT_DATE + 1) para preservar la
-- semántica de fecha::date = CURRENT_DATE y permitir el uso de índice.
-- ============================================================================

SET search_path TO public;

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha >= CURRENT_DATE
  AND ped.fecha < CURRENT_DATE + 1
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha >= CURRENT_DATE
  AND ped.fecha < CURRENT_DATE + 1
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
