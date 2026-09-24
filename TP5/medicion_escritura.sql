-- ============================================================================
-- medicion_escritura.sql — Impacto de los índices en INSERT masivo (10k filas)
-- Uso: psql -d copia_trabajo -f medicion_escritura.sql
-- Corre SOLO en copia aislada: crea y elimina tablas de prueba (bench_*).
-- Metodología: dos tablas espejo idénticas, una SIN y otra CON el índice
--   covering de la consulta C; se inserta el mismo lote de 10.000 filas en
--   cada una con EXPLAIN (ANALYZE) y se comparan Execution Time y tamaños.
--   (Los índices A y B viven en pedido/producto: no afectan al INSERT en
--   detalle_pedido y por eso no entran en la medición.)
-- ============================================================================

\timing on

-- ----------------------------------------------------------------------------
-- 1. Tablas espejo (sin FKs a propósito: se mide SOLO el costo del índice;
--    con FKs habría además chequeos contra pedido/producto en ambas ramas).
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS bench_base;
DROP TABLE IF EXISTS bench_idx;

CREATE TABLE bench_base (
    pedido_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (pedido_id, producto_id)
);

CREATE TABLE bench_idx (
    pedido_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (pedido_id, producto_id)
);
-- Único diferencial entre ambas: el covering de la consulta C.
CREATE INDEX idx_bench_cover
    ON bench_idx (producto_id) INCLUDE (cantidad, precio_unitario);

-- ----------------------------------------------------------------------------
-- 2. Lote idéntico de 10.000 filas (semilla fija => lote reproducible).
-- ----------------------------------------------------------------------------
SELECT setseed(0.42);
CREATE TEMP TABLE lote_10k AS
SELECT (1 + floor(random() * 200000))::BIGINT AS pedido_id,
       (1 + floor(random() * 50000))::BIGINT  AS producto_id,
       (1 + floor(random() * 5))::INTEGER     AS cantidad,
       (500 + random() * 4500)::NUMERIC(12, 2) AS precio_unitario
FROM generate_series(1, 10000);

-- ----------------------------------------------------------------------------
-- 3. Medición: mismo INSERT en cada tabla (comparar Execution Time).
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, COSTS OFF)
INSERT INTO bench_base (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pedido_id, producto_id, cantidad, precio_unitario
FROM lote_10k
ON CONFLICT DO NOTHING;

EXPLAIN (ANALYZE, COSTS OFF)
INSERT INTO bench_idx (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pedido_id, producto_id, cantidad, precio_unitario
FROM lote_10k
ON CONFLICT DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. Overhead en disco del índice (relación índice/tabla).
-- ----------------------------------------------------------------------------
SELECT 'bench_base_tabla' AS objeto, pg_relation_size('bench_base') AS bytes
UNION ALL
SELECT 'bench_idx_tabla', pg_relation_size('bench_idx')
UNION ALL
SELECT 'idx_bench_cover', pg_relation_size('idx_bench_cover');

-- ----------------------------------------------------------------------------
-- 5. Limpieza (las tablas bench_* no deben quedar en la base).
-- ----------------------------------------------------------------------------
DROP TABLE bench_base;
DROP TABLE bench_idx;

\timing off

-- Lectura esperada: el INSERT en bench_idx tarda más (mantenimiento del
-- btree: una entrada por fila + WAL del índice) y el índice ocupa disco
-- extra. Si la diferencia de Execution Time es < 10-15% y el índice C se
-- usa a diario (agregaciones masivas), el trade-off escritura/lectura
-- justifica crearlo; si la tabla fuera write-only, no.
