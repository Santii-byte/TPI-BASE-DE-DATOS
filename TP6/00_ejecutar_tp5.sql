-- ============================================================================
-- TP 6 — Parte 2 / Wrapper para la base canónica acumulada (esquema public)
-- ============================================================================
-- Requiere haber corrido 00_migracion_esquema_tp5.sql.
-- Uso: psql -d copia_trabajo -f TP6/00_ejecutar_tp5.sql
-- ============================================================================

SET search_path TO public;
\ir tp_desnormalizacion_top_categorias.sql
