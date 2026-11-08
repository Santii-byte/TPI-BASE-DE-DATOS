-- ============================================================================
-- maintenance.sql - Revision semanal de mantenimiento (PostgreSQL 17)
-- ----------------------------------------------------------------------------
-- Uso: psql -h localhost -p 55436 -U postgres -d foodstore_u6 -f maintenance.sql
--
-- Orden:
--   1. Revisar configuracion de autovacuum y estado de las tablas.
--   2. Ejecutar VACUUM (ANALYZE) justificado por las tuplas muertas observadas.
--   3. Ajustar umbrales de autovacuum solo en detalle_pedido (tabla grande y
--      con updates frecuentes), para que el mantenimiento automatico actue
--      antes y no dependa de una ventana manual.
--   4. Verificar el estado posterior y fallar si hay indices invalidos.
--
-- No se ejecuta VACUUM FULL: toma ACCESS EXCLUSIVE, reescribe la tabla completa
-- y bloquea ventas. Su uso queda reservado a incidentes puntuales de bloat
-- extrema, nunca como tarea periodica.
-- ============================================================================

\echo '=== MANTENIMIENTO FOOD STORE ==='

-- 1. Configuracion global de autovacuum.
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'autovacuum',
    'autovacuum_naptime',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_analyze_scale_factor',
    'autovacuum_vacuum_threshold',
    'autovacuum_analyze_threshold'
)
ORDER BY name;

-- 2. Estado previo: justifica la accion manual.
SELECT relname,
       n_live_tup,
       n_dead_tup,
       CASE WHEN n_live_tup + n_dead_tup = 0 THEN 0
            ELSE round(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
       END AS pct_tuplas_muertas,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- 3. Accion segura y justificada.
--    VACUUM (ANALYZE) no bloquea lecturas ni escrituras y actualiza estadisticas.
--    Se ejecuta porque la carga masiva y el UPDATE de totales generaron tuplas
--    muertas que el autovacuum todavia no habia reclamado.
VACUUM (ANALYZE, VERBOSE) cliente;
VACUUM (ANALYZE, VERBOSE) producto;
VACUUM (ANALYZE, VERBOSE) pedido;
VACUUM (ANALYZE, VERBOSE) detalle_pedido;

-- 4. Ajuste preventivo de autovacuum para la tabla de mayor volumen.
--    Con los valores por defecto (scale_factor 0.20) harian falta ~100.000
--    tuplas muertas para disparar el vacuum; con 0.05 se dispara antes.
ALTER TABLE detalle_pedido SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);

-- 5. Estado posterior.
SELECT relname,
       n_live_tup,
       n_dead_tup,
       CASE WHEN n_live_tup + n_dead_tup = 0 THEN 0
            ELSE round(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
       END AS pct_tuplas_muertas,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY relname;

-- 6. Control final: si hay indices invalidos, el mantenimiento falla.
DO $$
DECLARE
    invalidos integer;
BEGIN
    SELECT count(*) INTO invalidos FROM pg_index WHERE NOT indisvalid;

    IF invalidos > 0 THEN
        RAISE EXCEPTION 'Mantenimiento FALLIDO: % indice(s) invalido(s)', invalidos;
    END IF;

    RAISE NOTICE 'Mantenimiento OK: VACUUM (ANALYZE) completado sin indices invalidos';
END $$;

\echo '=== FIN MANTENIMIENTO ==='
