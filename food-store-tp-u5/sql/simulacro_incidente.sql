-- ============================================================================
-- Food Store — TP Unidad 5
-- simulacro_incidente.sql — simulacro controlado de acceso indebido (Parte C)
-- ============================================================================
-- Ejecutar como reportes_foodstore (rol de bajo privilegio):
--   psql -h localhost -p 55435 -U reportes_foodstore -d foodstore_u5 \
--        -f sql/simulacro_incidente.sql
--
-- La secuencia reproduce:
--   1. cinco intentos fallidos contra fn_autenticar;
--   2. un inicio de sesión exitoso;
--   3. una lectura masiva de la tabla usuario (solo columnas permitidas);
--   4. un intento de leer password_hash (debe fallar);
--   5. un intento de escalamiento a admin_datos (debe fallar).
--
-- NO se ejecuta ninguna acción de contención desde este script. La decisión
-- de contención se documenta aparte y la toma el equipo.
-- ============================================================================

\set ON_ERROR_STOP off
\pset pager off

SELECT 'INICIO_SIMULACRO' AS marca;

-- 1. Intentos fallidos de inicio de sesión contra la función de aplicación
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'incorrecta-01');
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'incorrecta-02');
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'incorrecta-03');
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'incorrecta-04');
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'incorrecta-05');

-- También un email inexistente: la función no debe revelar si existe.
SELECT * FROM fn_autenticar('no-existe@foodstore.test', 'incorrecta-06');

-- 2. Inicio de sesión exitoso
SELECT * FROM fn_autenticar('analista1@foodstore.test', 'ClaveSegura#2026');

-- 3. Lectura masiva de la tabla usuario (columnas permitidas por el rol).
--    En Windows se descarta la salida con NUL; en Unix usar /dev/null.
\o NUL
SELECT id, email, nombre, rol, activo, created_at, ultimo_acceso
  FROM usuario
 ORDER BY id;
\o

-- 4. Intento de leer el hash de contraseñas (debe fallar por privilegios)
SELECT password_hash FROM usuario LIMIT 1;

-- 5. Intento de escalamiento de privilegios (debe fallar)
SET ROLE admin_datos;
GRANT admin_datos TO reportes_foodstore;

SELECT 'FIN_SIMULACRO' AS marca;
