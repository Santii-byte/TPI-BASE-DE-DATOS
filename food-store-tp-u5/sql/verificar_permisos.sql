-- ============================================================================
-- Food Store — TP Unidad 5
-- verificar_permisos.sql — evidencia de la Parte A
-- ============================================================================
-- Ejecutar como superusuario:
--   psql -d foodstore_u5 -f sql/verificar_permisos.sql
-- La salida se guarda en docs/verificacion_permisos.txt.
-- ============================================================================

\pset pager off
\pset border 2

\echo '=== 1. \du : roles y atributos ==='
\du

\echo '=== 2. Membresías ==='
SELECT r.rolname AS rol,
       r.rolcanlogin AS login,
       r.rolcreaterole AS crea_roles,
       r.rolsuper AS superusuario,
       ARRAY(
           SELECT m.rolname
             FROM pg_auth_members am
             JOIN pg_roles m ON m.oid = am.roleid
            WHERE am.member = r.oid
              AND (am.inherit_option OR am.set_option)
            ORDER BY m.rolname
       ) AS hereda_de,
       ARRAY(
           SELECT m.rolname
             FROM pg_auth_members am
             JOIN pg_roles m ON m.oid = am.roleid
            WHERE am.member = r.oid
              AND am.admin_option
            ORDER BY m.rolname
       ) AS administra_a
  FROM pg_roles r
 WHERE r.rolname IN ('foodstore_owner', 'admin_datos', 'operador_ventas',
                     'analista_ventas', 'auditor_seguridad', 'soporte_cliente',
                     'app_foodstore', 'reportes_foodstore', 'soporte_foodstore')
 ORDER BY r.rolname;

\echo '=== 3. Privilegios de tabla (information_schema.role_table_grants) ==='
SELECT grantee AS rol,
       table_name AS tabla,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
  FROM information_schema.role_table_grants
 WHERE grantee IN ('admin_datos', 'operador_ventas', 'analista_ventas',
                   'auditor_seguridad', 'soporte_cliente',
                   'app_foodstore', 'reportes_foodstore', 'soporte_foodstore')
   AND table_schema = 'public'
 GROUP BY grantee, table_name
 ORDER BY grantee, table_name;

\echo '=== 4. Privilegios de columna sobre usuario ==='
SELECT grantee AS rol,
       column_name AS columna,
       privilege_type AS privilegio
  FROM information_schema.column_privileges
 WHERE table_schema = 'public'
   AND table_name = 'usuario'
   AND grantee IN ('admin_datos', 'operador_ventas', 'analista_ventas',
                   'auditor_seguridad', 'soporte_cliente',
                   'app_foodstore', 'reportes_foodstore', 'soporte_foodstore')
 ORDER BY grantee, columna, privilegio;

\echo '=== 5. Privilegios por defecto de foodstore_owner ==='
SELECT pg_get_userbyid(defaclrole) AS propietario,
       defaclobjtype AS tipo,
       defaclacl AS acl
  FROM pg_default_acl
 WHERE pg_get_userbyid(defaclrole) = 'foodstore_owner'
 ORDER BY defaclobjtype;

\echo '=== 6. Pruebas negativas de privilegios (matriz booleana) ==='
SELECT 'reportes_foodstore puede leer password_hash' AS prueba,
       has_column_privilege('reportes_foodstore', 'usuario', 'password_hash', 'SELECT') AS resultado
UNION ALL
SELECT 'app_foodstore puede leer password_hash',
       has_column_privilege('app_foodstore', 'usuario', 'password_hash', 'SELECT')
UNION ALL
SELECT 'reportes_foodstore puede borrar pedidos',
       has_table_privilege('reportes_foodstore', 'pedido', 'DELETE')
UNION ALL
SELECT 'app_foodstore puede borrar pedidos',
       has_table_privilege('app_foodstore', 'pedido', 'DELETE')
UNION ALL
SELECT 'admin_datos puede leer usuario',
       has_table_privilege('admin_datos', 'usuario', 'SELECT')
UNION ALL
SELECT 'admin_datos puede administrar roles (CREATEROLE)',
       (SELECT rolcreaterole FROM pg_roles WHERE rolname = 'admin_datos')
UNION ALL
SELECT 'reportes_foodstore puede crear tablas temporales',
       has_database_privilege('reportes_foodstore', current_database(), 'TEMPORARY')
UNION ALL
SELECT 'PUBLIC puede ejecutar fn_autenticar',
       has_function_privilege('public', 'fn_autenticar(text,text)', 'EXECUTE')
UNION ALL
SELECT 'existe el rol admin_seguridad (no debe)',
       EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_seguridad')
UNION ALL
SELECT 'existe el rol seguridad_foodstore (no debe)',
       EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'seguridad_foodstore')
UNION ALL
SELECT 'app_foodstore puede ejecutar fn_autenticar',
       has_function_privilege('app_foodstore', 'fn_autenticar(text,text)', 'EXECUTE');

\echo '=== 7. Prueba de privilegios por defecto en una tabla futura ==='
SET ROLE foodstore_owner;
DROP TABLE IF EXISTS tabla_futura;
CREATE TABLE tabla_futura (id INT PRIMARY KEY, dato TEXT);
RESET ROLE;
SELECT has_table_privilege('analista_ventas', 'tabla_futura', 'SELECT') AS analista_lee,
       has_table_privilege('operador_ventas', 'tabla_futura', 'INSERT') AS operador_inserta,
       has_table_privilege('operador_ventas', 'tabla_futura', 'DELETE') AS operador_borra,
       has_table_privilege('admin_datos', 'tabla_futura', 'DELETE') AS admin_borra,
       has_table_privilege('public', 'tabla_futura', 'SELECT') AS public_lee,
       has_function_privilege('public', 'fn_autenticar(text,text)', 'EXECUTE') AS public_ejecuta_fn;
DROP TABLE tabla_futura;
