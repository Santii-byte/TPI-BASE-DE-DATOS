-- ============================================================================
-- medicion_escritura.sql — Impacto de los índices en INSERT masivo (10k filas)
-- Corre en copia aislada: crea y elimina tablas temporales de prueba (bench_*).
-- ============================================================================

-- 1. Tablas espejo (sin FKs para aislar únicamente el costo del índice)
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

-- Diferencial: índice covering de la consulta C
CREATE INDEX idx_bench_cover
    ON bench_idx (producto_id) INCLUDE (cantidad, precio_unitario);

-- 2. Generar el lote idéntico de 10.000 filas en memoria
SELECT setseed(0.42);
DROP TABLE IF EXISTS lote_10k;
CREATE TEMP TABLE lote_10k AS
SELECT (1 + floor(random() * 200000))::BIGINT AS pedido_id,
       (1 + floor(random() * 50000))::BIGINT  AS producto_id,
       (1 + floor(random() * 5))::INTEGER     AS cantidad,
       (500 + random() * 4500)::NUMERIC(12, 2) AS precio_unitario
FROM generate_series(1, 10000);

-- 3. Medición del INSERT en la tabla SIN índice adicional
EXPLAIN (ANALYZE, COSTS OFF)
INSERT INTO bench_base (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pedido_id, producto_id, cantidad, precio_unitario
FROM lote_10k
ON CONFLICT DO NOTHING;

-- 4. Medición del INSERT en la tabla CON índice adicional
EXPLAIN (ANALYZE, COSTS OFF)
INSERT INTO bench_idx (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pedido_id, producto_id, cantidad, precio_unitario
FROM lote_10k
ON CONFLICT DO NOTHING;

-- 5. Comparativa de tamaño en disco (Overhead del índice)
SELECT 'bench_base_tabla' AS objeto, pg_size_pretty(pg_relation_size('bench_base')) AS tamano
UNION ALL
SELECT 'bench_idx_tabla', pg_size_pretty(pg_relation_size('bench_idx'))
UNION ALL
SELECT 'idx_bench_cover', pg_size_pretty(pg_relation_size('idx_bench_cover'));

-- 6. Limpieza final de tablas de prueba
DROP TABLE IF EXISTS bench_base;
DROP TABLE IF EXISTS bench_idx;
DROP TABLE IF EXISTS lote_10k;


-- Tomar tiempo de inserción
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT 
    (1 + floor(random() * 100000))::BIGINT,
    (1 + floor(random() * 40000))::BIGINT,
    1,
    100.00
FROM generate_series(1, 10000)
ON CONFLICT DO NOTHING;


-- Medición de inserción masiva (10.000 filas)

-- Tomar tiempo de inserción
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT 
    (1 + floor(random() * 100000))::BIGINT,
    (1 + floor(random() * 40000))::BIGINT,
    1,
    100.00
FROM generate_series(1, 10000)
ON CONFLICT DO NOTHING;
