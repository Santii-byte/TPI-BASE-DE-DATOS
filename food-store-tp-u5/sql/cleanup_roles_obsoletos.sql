-- ============================================================================
-- Food Store — TP Unidad 5
-- cleanup_roles_obsoletos.sql — limpieza de roles descartados
-- ============================================================================
-- Ejecutar UNA sola vez como superusuario sobre CADA base del clúster:
--   psql -d foodstore_u5       -f sql/cleanup_roles_obsoletos.sql
--   psql -d foodstore_u5_clean -f sql/cleanup_roles_obsoletos.sql
-- y finalmente, en la base `postgres`:
--   psql -d postgres -f sql/cleanup_roles_obsoletos.sql
--
-- Motivo: `admin_seguridad` (con CREATEROLE + ADMIN OPTION) y su login
-- `seguridad_foodstore` se eliminaron por riesgo de escalamiento. DROP ROLE es
-- global al clúster, pero DROP OWNED BY es por base; por eso se ejecuta en cada
-- base antes de borrar los roles.
-- ============================================================================

\set ON_ERROR_STOP off

DROP OWNED BY seguridad_foodstore, admin_seguridad;

DROP ROLE IF EXISTS seguridad_foodstore;
DROP ROLE IF EXISTS admin_seguridad;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles
                WHERE rolname IN ('admin_seguridad', 'seguridad_foodstore')) THEN
        RAISE WARNING 'Quedan roles obsoletos: ejecutar este script en las demás bases antes de DROP ROLE.';
    ELSE
        RAISE NOTICE 'Roles obsoletos eliminados o inexistentes.';
    END IF;
END
$$;
