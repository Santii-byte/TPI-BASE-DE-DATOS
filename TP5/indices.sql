-- ============================================================================
-- optimizacion_consultas_food_store.sql — Índices óptimos A/B/C + descarte
-- PostgreSQL 16. Uso: psql -d copia_trabajo -f optimizacion_consultas_food_store.sql
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- Consulta A: pedidos de un cliente en rango de fechas
--   SELECT id, fecha, total, estado FROM pedido
--   WHERE cliente_id = $1 AND fecha >= $2;
-- Estructura: compuesto equality-first (cliente_id) + range-second (fecha),
--   CUBRIENTE con las columnas de salida -> Index Only Scan (id sale de la
--   entrada INCLUDE; fecha y cliente_id de la llave).
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pedido_cliente_fecha_cover
    ON pedido (cliente_id, fecha) INCLUDE (id, total, estado);

-- ----------------------------------------------------------------------------
-- Consulta B: activos por rango de precio, ordenados, Top-50
--   SELECT id, nombre, precio, stock FROM producto
--   WHERE activo = TRUE AND precio BETWEEN $1 AND $2
--   ORDER BY precio DESC LIMIT 50;
-- Estructura: PARCIAL (solo filas activas: predicado invariante) +
--   DESCENDENTE (calza exacto el ORDER BY -> sin Sort, corte en 50) +
--   CUBRIENTE (nombre, stock; id sale de la entrada) -> Index Only Scan.
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_precio_desc_cover
    ON producto (precio DESC) INCLUDE (nombre, stock)
    WHERE activo = TRUE;

-- ----------------------------------------------------------------------------
-- Consulta C: agregación masiva por producto
--   SELECT producto_id, SUM(cantidad), SUM(cantidad * precio_unitario)
--   FROM detalle_pedido GROUP BY producto_id;
-- Estructura: CUBRIENTE ordenado por la clave de agrupación ->
--   Index Only Scan + GroupAggregate en streaming (entrada ya ordenada,
--   sin nodo Sort aunque sean ~50k grupos).
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_detalle_producto_cover
    ON detalle_pedido (producto_id) INCLUDE (cantidad, precio_unitario);

COMMIT;

VACUUM ANALYZE pedido;
VACUUM ANALYZE producto;
VACUUM ANALYZE detalle_pedido;

-- ----------------------------------------------------------------------------
-- 4to ÍNDICE — CANDIDATO A DESCARTE (NO CREAR):
--   CREATE INDEX idx_pedido_estado ON pedido (estado);
-- Justificación técnica: `estado` tiene 4 valores (~25% de filas cada uno).
--   Ningún filtro por un valor es selectivo, así que el planificador jamás
--   lo elegiría (Seq Scan o Bitmap siempre ganan); solo sumaría costo de
--   mantenimiento en cada INSERT/UPDATE, espacio en disco y trabajo de
--   VACUUM/ANALYZE. Regla aplicada: sin alta selectividad no hay índice.
--   (Excepción futura: si un estado pasa a ser raro (<1%), evaluar un
--   parcial WHERE estado = '<raro>' en ese momento, no antes.)
-- Tampoco crear: un btree simple (producto_id) SIN include existiendo el
--   covering de C (redundancia: misma llave líder, el simple sobra).
-- ----------------------------------------------------------------------------
