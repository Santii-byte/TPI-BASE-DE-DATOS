-- ============================================================================
-- Food Store — TP Unidad 5
-- 00_base_seguridad.sql — tablas de seguridad, dueño técnico y autenticación
-- ============================================================================
-- Requiere que el esquema comercial de Food Store ya exista (TP2/TP5).
-- Ejecutar como superusuario o como dueño actual de las tablas:
--   psql -d foodstore_u5 -f sql/00_base_seguridad.sql
--
-- Este script NO recrea las tablas comerciales: solo agrega lo necesario para
-- las Partes A–D del TP y transfiere la propiedad de los objetos a
-- foodstore_owner para que ALTER DEFAULT PRIVILEGES sea predecible.
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. Dueño técnico de los objetos (sin login)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'foodstore_owner') THEN
        CREATE ROLE foodstore_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE
            NOREPLICATION NOBYPASSRLS;
    END IF;
END
$$;

GRANT USAGE, CREATE ON SCHEMA public TO foodstore_owner;

-- ----------------------------------------------------------------------------
-- 2. Tabla de cuentas de la aplicación
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuario (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    nombre        VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    rol           VARCHAR(30) NOT NULL
        CHECK (rol IN ('admin_datos', 'operador_ventas', 'analista_ventas',
                       'auditor_seguridad', 'soporte_cliente')),
    activo        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    ultimo_acceso TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- 3. Registro de intentos de autenticación
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS intento_login (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email_intentado VARCHAR(255) NOT NULL,
    exito           BOOLEAN NOT NULL,
    ocurrido_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    origen          INET DEFAULT inet_client_addr()
);

CREATE INDEX IF NOT EXISTS idx_intento_login_fecha
    ON intento_login (ocurrido_en DESC);

CREATE INDEX IF NOT EXISTS idx_intento_login_email
    ON intento_login (email_intentado);

-- ----------------------------------------------------------------------------
-- 4. Función de autenticación (SECURITY DEFINER)
--    La aplicación NO lee password_hash directamente: solo ejecuta esta
--    función. Así se centraliza la comparación y el registro de intentos.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_autenticar(p_email TEXT, p_password TEXT)
RETURNS TABLE (autenticado BOOLEAN, usuario_id BIGINT, rol_usuario TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_email   VARCHAR(255);
    v_usuario usuario%ROWTYPE;
BEGIN
    v_email := lower(trim(COALESCE(p_email, '')));

    SELECT *
      INTO v_usuario
      FROM usuario u
     WHERE u.email = v_email
       AND u.activo = TRUE;

    IF NOT FOUND THEN
        -- Mismo resultado que una contraseña incorrecta: no se revela si el
        -- email existe.
        INSERT INTO intento_login (email_intentado, exito)
        VALUES (v_email, FALSE);

        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::TEXT;
        RETURN;
    END IF;

    IF v_usuario.password_hash = crypt(COALESCE(p_password, ''), v_usuario.password_hash) THEN
        UPDATE usuario
           SET ultimo_acceso = now()
         WHERE id = v_usuario.id;

        INSERT INTO intento_login (email_intentado, exito)
        VALUES (v_usuario.email, TRUE);

        RETURN QUERY SELECT TRUE, v_usuario.id, v_usuario.rol::TEXT;
    ELSE
        INSERT INTO intento_login (email_intentado, exito)
        VALUES (v_usuario.email, FALSE);

        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::TEXT;
    END IF;
END;
$$;

ALTER FUNCTION fn_autenticar(TEXT, TEXT) OWNER TO foodstore_owner;
REVOKE ALL ON FUNCTION fn_autenticar(TEXT, TEXT) FROM PUBLIC;

-- ----------------------------------------------------------------------------
-- 5. Datos de prueba determinísticos (6000 cuentas, 12 meses)
--    La cuenta analista1@foodstore.test se usa en el simulacro de incidente.
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF (SELECT count(*) FROM usuario) = 0 THEN
        INSERT INTO usuario (email, nombre, password_hash, rol, activo, created_at)
        SELECT CASE
                   WHEN g = 1 THEN 'analista1@foodstore.test'
                   ELSE 'usuario' || lpad(g::text, 4, '0') || '@foodstore.test'
               END,
               'Usuario ' || lpad(g::text, 4, '0'),
               crypt('ClaveSegura#2026', gen_salt('bf', 6)),
               CASE
                   WHEN g = 1 THEN 'analista_ventas'
                   ELSE (ARRAY['admin_datos', 'operador_ventas', 'analista_ventas',
                              'auditor_seguridad', 'soporte_cliente'])[1 + (g % 5)]
               END,
               (g % 17 <> 0),
               date_trunc('month', now())
                   - ((g % 12) || ' months')::interval
                   + ((g % 27) || ' days')::interval
          FROM generate_series(1, 6000) AS g
        ON CONFLICT (email) DO NOTHING;
    END IF;
END
$$;

-- ----------------------------------------------------------------------------
-- 6. Propiedad de los objetos para default privileges
-- ----------------------------------------------------------------------------
ALTER TABLE cliente        OWNER TO foodstore_owner;
ALTER TABLE producto       OWNER TO foodstore_owner;
ALTER TABLE pedido         OWNER TO foodstore_owner;
ALTER TABLE detalle_pedido OWNER TO foodstore_owner;
ALTER TABLE usuario        OWNER TO foodstore_owner;
ALTER TABLE intento_login  OWNER TO foodstore_owner;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT sequence_schema, sequence_name
          FROM information_schema.sequences
         WHERE sequence_schema = 'public'
    LOOP
        EXECUTE format('ALTER SEQUENCE %I.%I OWNER TO foodstore_owner',
                       r.sequence_schema, r.sequence_name);
    END LOOP;
END
$$;

COMMIT;

-- Verificación rápida
SELECT 'usuario' AS objeto, count(*) AS filas FROM usuario
UNION ALL
SELECT 'intento_login', count(*) FROM intento_login
UNION ALL
SELECT 'usuarios activos', count(*) FROM usuario WHERE activo
UNION ALL
SELECT 'usuarios por rol', count(DISTINCT rol) FROM usuario;
