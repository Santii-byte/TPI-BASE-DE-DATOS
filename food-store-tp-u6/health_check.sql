-- ============================================================================
-- health_check.sql - Monitoreo diario de Food Store (PostgreSQL 17)
-- ----------------------------------------------------------------------------
-- Uso: psql -h localhost -p 55436 -U postgres -d foodstore_u6 -f health_check.sql
--
-- Ejecuta 8 controles y deja el detalle en una tabla temporal. El bloque DO
-- final lanza una excepcion si algun control queda en FAIL, de modo que el
-- Programador de tareas detecte el fallo por codigo de salida distinto de 0.
-- Un estado WARN no aborta la ejecucion, pero queda visible en la evidencia.
-- ============================================================================

\echo '=== HEALTH CHECK FOOD STORE ==='

SELECT now()                              AS momento,
       current_database()                 AS base,
       current_user                       AS usuario,
       pg_size_pretty(pg_database_size(current_database())) AS tamano_base,
       current_setting('max_connections') AS max_conexiones;

-- Detalle operativo: actividad por estado.
SELECT state, count(*) AS conexiones
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state
ORDER BY conexiones DESC;

-- Consultas activas (para detectar bloqueos o consultas largas).
SELECT pid, usename, state, wait_event_type, wait_event,
       now() - query_start AS duracion,
       left(query, 120)    AS consulta
FROM pg_stat_activity
WHERE datname = current_database()
  AND state = 'active'
  AND pid <> pg_backend_pid()
ORDER BY query_start;

-- Estado de tablas: tamano, tuplas vivas/muertas, vacuum y analyze.
SELECT relname,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
       n_live_tup,
       n_dead_tup,
       CASE WHEN n_live_tup + n_dead_tup = 0 THEN 0
            ELSE round(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
       END AS pct_tuplas_muertas,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze,
       seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC, relname;

-- ----------------------------------------------------------------------------
-- Controles consolidados
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS resultado_health;
CREATE TEMP TABLE resultado_health (
    orden   integer,
    control text,
    valor   text,
    umbral  text,
    estado  text,
    detalle text
);

WITH p AS (
    SELECT 10::numeric * 1024 * 1024 * 1024 AS max_db_bytes,
           (current_setting('max_connections')::int * 0.8)::int AS max_conexiones,
           5::int   AS max_idle_tx,
           300::int AS max_query_seconds,
           20::numeric AS max_dead_pct_umbral,
           2::int   AS max_consultas_largas
),
m AS (
    SELECT
        (SELECT pg_database_size(current_database())) AS db_bytes,
        (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()) AS conexiones,
        (SELECT count(*) FROM pg_stat_activity
          WHERE datname = current_database() AND state = 'active'
            AND pid <> pg_backend_pid()) AS consultas_activas,
        (SELECT count(*) FROM pg_stat_activity
          WHERE datname = current_database() AND state = 'idle in transaction') AS idle_tx,
        (SELECT count(*) FROM pg_stat_activity
          WHERE datname = current_database() AND state = 'active'
            AND pid <> pg_backend_pid()
            AND now() - query_start > interval '300 seconds') AS consultas_largas,
        (SELECT COALESCE(max(CASE WHEN n_live_tup + n_dead_tup = 0 THEN 0
                                  ELSE 100.0 * n_dead_tup / (n_live_tup + n_dead_tup)
                             END), 0)
           FROM pg_stat_user_tables
          WHERE schemaname = 'public') AS max_dead_pct,
        (SELECT count(*) FROM pg_index WHERE NOT indisvalid) AS indices_invalidos,
        (SELECT count(*) FROM pg_locks WHERE NOT granted) AS locks_esperando,
        (SELECT count(*) FROM pg_stat_user_tables
          WHERE schemaname = 'public'
            AND last_analyze IS NULL AND last_autoanalyze IS NULL) AS sin_analyze
)
INSERT INTO resultado_health
SELECT 1, '1. Tamano de la base', pg_size_pretty(db_bytes), '<= 10 GB',
       CASE WHEN db_bytes <= max_db_bytes THEN 'OK' ELSE 'FAIL' END,
       db_bytes::text || ' bytes'
FROM m, p
UNION ALL
SELECT 2, '2. Conexiones totales', conexiones::text,
       '<= ' || max_conexiones || ' (80% de max_connections)',
       CASE WHEN conexiones <= max_conexiones THEN 'OK'
            WHEN conexiones <= current_setting('max_connections')::int THEN 'WARN'
            ELSE 'FAIL' END,
       'Consultas activas: ' || consultas_activas
FROM m, p
UNION ALL
SELECT 3, '3. Consultas activas largas (> 5 min)', consultas_largas::text,
       '<= ' || max_consultas_largas,
       CASE WHEN consultas_largas = 0 THEN 'OK'
            WHEN consultas_largas <= max_consultas_largas THEN 'WARN'
            ELSE 'FAIL' END,
       'Excluye la sesion del health check'
FROM m, p
UNION ALL
SELECT 4, '4. Sesiones idle in transaction', idle_tx::text,
       '<= ' || max_idle_tx,
       CASE WHEN idle_tx = 0 THEN 'OK'
            WHEN idle_tx <= max_idle_tx THEN 'WARN'
            ELSE 'FAIL' END,
       'Transacciones abiertas que retienen locks'
FROM m, p
UNION ALL
SELECT 5, '5. Peor porcentaje de tuplas muertas', round(max_dead_pct, 2)::text || ' %',
       '< ' || max_dead_pct_umbral || ' %',
       CASE WHEN max_dead_pct < max_dead_pct_umbral THEN 'OK'
            WHEN max_dead_pct < (max_dead_pct_umbral * 2) THEN 'WARN'
            ELSE 'FAIL' END,
       'Justifica VACUUM (ANALYZE) en maintenance.sql'
FROM m, p
UNION ALL
SELECT 6, '6. Indices invalidos', indices_invalidos::text, '= 0',
       CASE WHEN indices_invalidos = 0 THEN 'OK' ELSE 'FAIL' END,
       'Un indice invalido no debe usarse para consultas'
FROM m, p
UNION ALL
SELECT 7, '7. Locks esperando', locks_esperando::text, '= 0',
       CASE WHEN locks_esperando = 0 THEN 'OK' ELSE 'FAIL' END,
       'Solicitudes de lock no concedidas'
FROM m, p
UNION ALL
SELECT 8, '8. Tablas sin ANALYZE', sin_analyze::text, '= 0',
       CASE WHEN sin_analyze = 0 THEN 'OK' ELSE 'WARN' END,
       'Sin estadisticas el planificador puede elegir malos planes'
FROM m, p;

SELECT control, valor, umbral, estado, detalle
FROM resultado_health
ORDER BY orden;

-- ----------------------------------------------------------------------------
-- Veredicto: solo FAIL produce codigo de salida distinto de 0.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    fallos integer;
    advertencias integer;
BEGIN
    SELECT count(*) FILTER (WHERE estado = 'FAIL'),
           count(*) FILTER (WHERE estado = 'WARN')
    INTO fallos, advertencias
    FROM resultado_health;

    RAISE NOTICE 'Resumen health check: % FAIL, % WARN', fallos, advertencias;

    IF fallos > 0 THEN
        RAISE EXCEPTION 'Health check FALLIDO: % control(es) en FAIL', fallos;
    END IF;
END $$;

\echo '=== FIN HEALTH CHECK ==='
