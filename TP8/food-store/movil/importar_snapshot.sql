-- ============================================================================
-- Importar servidor_snapshot.csv a la tablet
-- ============================================================================
-- Requiere haber cargado el CSV en snapshot_raw. Con sqlite3:
--
--   .mode csv
--   .import --csv --skip 1 servidor_snapshot.csv snapshot_raw
--   .read importar_snapshot.sql
--
-- En DB Browser: File > Import > Table from CSV, elegir snapshot_raw y marcar
-- "Column names in first line". Luego ejecutar este archivo.
--
-- PostgreSQL exporta los booleanos como t/f. Por eso el staging es TEXT y la
-- conversion a 1/0 se hace aca, una sola vez y de forma explicita.
-- ============================================================================

PRAGMA foreign_keys = ON;

BEGIN;

DELETE FROM snapshot_servidor;

INSERT INTO snapshot_servidor
    (id, nombre, categoria, precio_centavos, stock, disponible, eliminado, fecha_copia)
SELECT CAST(TRIM(id) AS INTEGER),
       TRIM(nombre),
       TRIM(categoria),
       CAST(TRIM(precio_centavos) AS INTEGER),
       CAST(TRIM(stock) AS INTEGER),
       CASE lower(TRIM(disponible))
            WHEN 't' THEN 1 WHEN 'true' THEN 1 WHEN '1' THEN 1 ELSE 0
       END,
       CASE lower(TRIM(eliminado))
            WHEN 't' THEN 1 WHEN 'true' THEN 1 WHEN '1' THEN 1 ELSE 0
       END,
       TRIM(fecha_copia)
  FROM snapshot_raw
 WHERE id IS NOT NULL
   AND TRIM(id) <> '';

-- El catalogo local queda alineado con la instantanea. Se incluyen las bajas
-- logicas para no romper la FK de item_borrador y para poder explicar el
-- RECHAZADO; la consulta de catalogo disponible las filtra.
INSERT INTO producto_cache
    (id, nombre, categoria, precio_centavos, stock, disponible, eliminado, fecha_copia)
SELECT id, nombre, categoria, precio_centavos, stock, disponible, eliminado, fecha_copia
  FROM snapshot_servidor
 WHERE true
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    categoria       = excluded.categoria,
    precio_centavos = excluded.precio_centavos,
    stock           = excluded.stock,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

-- Filas que ya no existen en el servidor: si no estan referenciadas por un
-- borrador se eliminan; si estan referenciadas se conservan pero se ocultan.
UPDATE producto_cache
   SET disponible = 0
 WHERE id NOT IN (SELECT id FROM snapshot_servidor);

DELETE FROM producto_cache
 WHERE id NOT IN (SELECT id FROM snapshot_servidor)
   AND id NOT IN (SELECT producto_id FROM item_borrador);

DELETE FROM snapshot_raw;

COMMIT;

-- Evidencia de la importacion
SELECT (SELECT count(*) FROM snapshot_servidor)                        AS filas_servidor,
       (SELECT count(*) FROM producto_cache)                           AS filas_cache,
       (SELECT count(*) FROM producto_cache WHERE disponible = 1 AND eliminado = 0 AND stock > 0) AS catalogo_visible,
       (SELECT max(fecha_copia) FROM snapshot_servidor)                AS fecha_copia;