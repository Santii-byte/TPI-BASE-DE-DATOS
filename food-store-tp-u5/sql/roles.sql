-- ============================================================================
-- Food Store — TP Unidad 5
-- roles.sql — roles, membresías y privilegios de mínimo privilegio
-- ============================================================================
-- Ejecutar como superusuario o como foodstore_owner, después de
-- 00_base_seguridad.sql:
--   psql -d foodstore_u5 -f sql/roles.sql
--
-- El script es idempotente: puede ejecutarse varias veces.
-- No incluye contraseñas reales: los roles de login usan un placeholder que
-- debe rotarse con \password antes de cualquier despliegue.
-- ============================================================================

BEGIN;

-- NOTA: si la base viene de un borrador con `admin_seguridad` o
-- `seguridad_foodstore`, ejecutar antes `sql/cleanup_roles_obsoletos.sql`
-- (requiere superusuario y debe correrse en cada base del clúster).

-- ----------------------------------------------------------------------------
-- 1. Roles de grupo (NOLOGIN)
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['foodstore_owner', 'admin_datos', 'operador_ventas',
                             'analista_ventas', 'auditor_seguridad',
                             'soporte_cliente']
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', r);
        END IF;
    END LOOP;
END
$$;

ALTER ROLE foodstore_owner   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE admin_datos       NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE operador_ventas   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE analista_ventas   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE auditor_seguridad NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE soporte_cliente   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- ----------------------------------------------------------------------------
-- 2. Roles de login
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['app_foodstore', 'reportes_foodstore',
                             'soporte_foodstore']
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L',
                           r, 'CAMBIO_OBLIGATORIO');
        END IF;
    END LOOP;
END
$$;

ALTER ROLE app_foodstore       LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 20;
ALTER ROLE reportes_foodstore  LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 10;
ALTER ROLE soporte_foodstore   LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 10;

-- ----------------------------------------------------------------------------
-- 3. Membresías
--    Los roles de login NO reciben permisos directos: heredan de su grupo.
-- ----------------------------------------------------------------------------
GRANT operador_ventas  TO app_foodstore;
GRANT analista_ventas  TO reportes_foodstore;
GRANT soporte_cliente  TO soporte_foodstore;

-- NOTA DE DISEÑO (revisión crítica):
-- Se descartó un rol `admin_seguridad` con CREATEROLE y ADMIN OPTION sobre los
-- roles de grupo. La auditoría interna demostró que esa combinación permite
-- re-otorgarse el rol con INHERIT/SET, o crear un login nuevo y asignárselo:
-- no hay contención real. La administración de roles de PostgreSQL queda
-- reservada al DBA (superusuario), fuera de la aplicación.

-- ----------------------------------------------------------------------------
-- 4. Endurecimiento global del esquema public
-- ----------------------------------------------------------------------------
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Solo los roles de grupo reciben USAGE. Los roles de login lo heredan; no se
-- les concede nada directamente (facilita auditar una única matriz de permisos).
GRANT USAGE ON SCHEMA public TO
    admin_datos, operador_ventas, analista_ventas, auditor_seguridad,
    soporte_cliente, foodstore_owner;

-- Solo el dueño técnico puede crear objetos en public.
GRANT CREATE ON SCHEMA public TO foodstore_owner;

-- ----------------------------------------------------------------------------
-- 5. Privilegios sobre tablas comerciales
-- ----------------------------------------------------------------------------
-- 5.1 admin_datos: DML sobre datos comerciales, sin usuario ni DDL.
GRANT SELECT, INSERT, UPDATE, DELETE
    ON cliente, producto, pedido, detalle_pedido
    TO admin_datos;
REVOKE ALL ON usuario, intento_login, usuario_anon FROM admin_datos;

-- 5.2 operador_ventas: alta y corrección de ventas, sin DELETE.
GRANT SELECT ON producto TO operador_ventas;
GRANT SELECT, INSERT, UPDATE ON cliente, pedido, detalle_pedido TO operador_ventas;
REVOKE ALL ON usuario, intento_login, usuario_anon FROM operador_ventas;

-- 5.3 analista_ventas: lectura comercial y columnas no sensibles de usuario.
GRANT SELECT ON cliente, producto, pedido, detalle_pedido, usuario_anon
    TO analista_ventas;
REVOKE ALL ON usuario FROM analista_ventas;
GRANT SELECT (id, email, nombre, rol, activo, created_at, ultimo_acceso)
    ON usuario TO analista_ventas;

-- 5.4 auditor_seguridad: lectura de operación y de intentos de login.
GRANT SELECT ON cliente, producto, pedido, detalle_pedido, intento_login,
                usuario_anon
    TO auditor_seguridad;
REVOKE ALL ON usuario FROM auditor_seguridad;
GRANT SELECT (id, email, nombre, rol, activo, created_at, ultimo_acceso)
    ON usuario TO auditor_seguridad;

-- 5.5 soporte_cliente: solo datos de contacto y pedidos mínimos.
GRANT SELECT (id, nombre, email, telefono, activo) ON cliente TO soporte_cliente;
GRANT UPDATE (email, telefono) ON cliente TO soporte_cliente;
GRANT SELECT (id, cliente_id, fecha, estado) ON pedido TO soporte_cliente;

-- 5.6 Sin rol de administración de cuentas a nivel aplicación.
--     El alta y el reset de credenciales los ejecuta el DBA con un
--     procedimiento controlado. Ningún rol de la aplicación puede escribir
--     `usuario` ni administrar membresías.

-- ----------------------------------------------------------------------------
-- 6. Secuencias
-- ----------------------------------------------------------------------------
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO admin_datos, operador_ventas;

-- ----------------------------------------------------------------------------
-- 7. Función de autenticación
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION fn_autenticar(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO
    app_foodstore, reportes_foodstore, soporte_foodstore;

-- El REVOKE masivo de funciones de la sección 4 también alcanza a pgcrypto
-- (crypt vive en public). El dueño de fn_autenticar necesita ejecutarla.
GRANT EXECUTE ON FUNCTION crypt(TEXT, TEXT) TO foodstore_owner;

-- ----------------------------------------------------------------------------
-- 8. Conexión a la base
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('REVOKE TEMPORARY ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_foodstore, reportes_foodstore, soporte_foodstore',
                   current_database());
END
$$;

-- ----------------------------------------------------------------------------
-- 9. Privilegios por defecto para tablas y secuencias futuras
--    Cualquier tabla nueva creada por foodstore_owner hereda esta política.
--    Si la tabla nueva contiene columnas secretas, se debe repetir el patrón
--    de usuario: REVOKE de tabla + GRANT por columna.
-- ----------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- ADVERTENCIA SOBRE FUNCIONES FUTURAS:
-- `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` NO
-- elimina el EXECUTE que PostgreSQL concede a PUBLIC por defecto: los default
-- privileges se SUMAN a los privilegios iniciales del objeto. Se verificó
-- creando una función nueva y comprobando que PUBLIC seguía ejecutándola.
-- Por eso toda función nueva debe crearse con un REVOKE explícito, igual que
-- fn_autenticar. No existe default privilege que lo evite.

-- Revocación explícita: ALTER DEFAULT PRIVILEGES acumula, no reemplaza. Si una
-- corrida anterior otorgó DELETE, hay que quitarlo antes de re-otorgar.
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    REVOKE DELETE ON TABLES FROM admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO operador_ventas;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT SELECT ON TABLES TO analista_ventas, auditor_seguridad;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO admin_datos, operador_ventas;

COMMIT;

-- ----------------------------------------------------------------------------
-- 10. Verificación rápida de membresías
-- ----------------------------------------------------------------------------
SELECT r.rolname AS rol,
       r.rolcanlogin AS puede_login,
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
