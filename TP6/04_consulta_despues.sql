-- ============================================================================
-- TP 6 — Parte 2 / 04: Consulta del panel (DESPUÉS de desnormalizar)
-- ============================================================================
-- Lee únicamente la tabla de resumen y hace un join puntual con la tabla
-- pequeña de categorías para mostrar el nombre. No recorre detalle_pedido,
-- producto ni pedido.
-- ============================================================================

SET search_path TO tp6_p2, public;

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
