-- ============================================================================
-- Food Store — TP Unidad 5
-- auditoria_test.sql — secuencia breve para la prueba de auditoría (Parte B)
-- ============================================================================
-- Ejecutar como app_foodstore:
--   psql -h localhost -p 55435 -U app_foodstore -d foodstore_u5 \
--        -f sql/auditoria_test.sql
--
-- La transacción se revierte: el objetivo es generar eventos en el log, no
-- dejar datos de prueba.
-- ============================================================================

\set ON_ERROR_STOP off
\pset pager off

SELECT 'INICIO_PRUEBA_AUDITORIA' AS marca;

-- 1. Lectura
SELECT count(*) AS clientes_visibles FROM cliente;

BEGIN;

-- 2. Inserción
INSERT INTO cliente (nombre, email, telefono)
VALUES ('Cliente Prueba Auditoría', 'prueba.auditoria@example.test', '+54 11 4000-0000')
RETURNING id, email;

-- 3. Actualización
UPDATE cliente
   SET telefono = '+54 11 5555-0000'
 WHERE email = 'prueba.auditoria@example.test';

-- 4. Intento de inicio de sesión fallido contra fn_autenticar
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'clave-incorrecta');

ROLLBACK;

SELECT 'FIN_PRUEBA_AUDITORIA' AS marca;
