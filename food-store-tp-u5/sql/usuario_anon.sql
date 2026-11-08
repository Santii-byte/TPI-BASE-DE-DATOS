-- ============================================================================
-- Food Store — TP Unidad 5
-- usuario_anon.sql — anonimización determinista de la tabla usuario
-- ============================================================================
-- Requiere 00_base_seguridad.sql (tabla usuario con datos).
-- Ejecutar antes de roles.sql para que los GRANT de roles.sql encuentren la
-- tabla usuario_anon:
--   psql -d foodstore_u5 -f sql/usuario_anon.sql
--
-- Criterio:
--   * id, rol, activo y created_at se conservan para no distorsionar los
--     agregados por rol y por mes de alta.
--   * email y nombre se reemplazan por valores sintéticos deterministas.
--   * password_hash se reemplaza por un valor inútil.
--   * ultimo_acceso se anula para no exponer hábitos de uso.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS usuario_anon (
    id            BIGINT PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    nombre        VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    rol           VARCHAR(30) NOT NULL,
    activo        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL,
    ultimo_acceso TIMESTAMPTZ
);

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'foodstore_owner') THEN
        ALTER TABLE usuario_anon OWNER TO foodstore_owner;
    END IF;
END
$$;

TRUNCATE usuario_anon;

INSERT INTO usuario_anon
    (id, email, nombre, password_hash, rol, activo, created_at, ultimo_acceso)
SELECT u.id,
       'anon' || lpad(u.id::text, 6, '0') || '@example.test',
       'Persona Anónima ' || lpad(u.id::text, 6, '0'),
       'anon-' || md5('hash:' || u.id::text),
       u.rol,
       u.activo,
       u.created_at,
       NULL
  FROM usuario AS u
 ORDER BY u.id;

COMMIT;

-- ----------------------------------------------------------------------------
-- Verificación de equivalencia estructural
-- ----------------------------------------------------------------------------
SELECT 'usuario' AS tabla, count(*) AS filas FROM usuario
UNION ALL
SELECT 'usuario_anon', count(*) FROM usuario_anon
UNION ALL
SELECT 'mismos roles', count(*) FROM (
    SELECT rol FROM usuario GROUP BY rol
    EXCEPT
    SELECT rol FROM usuario_anon GROUP BY rol
) AS diferencia_roles
UNION ALL
SELECT 'mismos meses', count(*) FROM (
    SELECT date_trunc('month', created_at) FROM usuario GROUP BY 1
    EXCEPT
    SELECT date_trunc('month', created_at) FROM usuario_anon GROUP BY 1
) AS diferencia_meses;
