-- ============================================================================
-- TP 6 — Parte 2 / 04b: Consulta DESPUÉS sobre la base canónica TP2–TP5
-- ============================================================================

SET search_path TO public;

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       r.total_vendido
  FROM resumen_venta_categoria_dia AS r
  JOIN categoria AS c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;

SELECT c.nombre AS categoria,
       r.total_vendido
  FROM resumen_venta_categoria_dia AS r
  JOIN categoria AS c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;
