-- ============================================================================
-- Exportar la instancia del servidor a CSV (lado PostgreSQL)
-- ============================================================================
-- Uso (desde la carpeta food-store/):
--   psql -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/exportar_snapshot.sql
--
-- Para conservar una instantanea de un caso, copiar el CSV generado a
-- docs/evidencias/ despues de ejecutar este script. Los booleanos salen como
-- t/f. En la tablet se importan a una tabla de staging de texto y se
-- normalizan a 1/0 antes de poblar snapshot_servidor.
-- ============================================================================

\copy (SELECT id, nombre, categoria, precio_centavos, stock, disponible, eliminado, fecha_copia FROM v_snapshot_movil ORDER BY id) TO 'movil/servidor_snapshot.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

SELECT count(*) AS filas_exportadas,
       min(fecha_copia) AS fecha_copia
  FROM v_snapshot_movil;