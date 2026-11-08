# Respuesta de la IA — borrador inicial de `roles.sql` (Parte A)

> **Prompt:** «Escribí un borrador de `roles.sql` para PostgreSQL 17 con
> `CREATE ROLE`, `GRANT`, `REVOKE`, permisos por columna sobre `usuario` y
> `ALTER DEFAULT PRIVILEGES`. Devolvé el SQL y una lista breve de supuestos.»
>
> **Uso:** se conserva como evidencia del caso en que la IA propuso permisos
> más amplios de lo necesario (`GRANT ALL PRIVILEGES`, `TRUNCATE`, acceso
> directo a `password_hash`). **No es el archivo entregado**: el definitivo es
> `sql/roles.sql`.

---

Archivo creado en `roles.sql` (raíz del proyecto):

```sql
-- ============================================================================
-- roles.sql — Food Store — PostgreSQL 17
-- Borrador para revisión crítica.
-- Ejecutar como dueño del esquema (rol que creó las tablas), no como superusuario.
-- ============================================================================
\set ON_ERROR_STOP on

BEGIN;

-- 1. Roles de grupo (sin login)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operador_ventas') THEN
        CREATE ROLE operador_ventas NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analista_ventas') THEN
        CREATE ROLE analista_ventas NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'auditor_seguridad') THEN
        CREATE ROLE auditor_seguridad NOLOGIN;
    END IF;
END
$$;

ALTER ROLE admin_datos       NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE operador_ventas   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE analista_ventas   NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE auditor_seguridad NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- 2. Roles de login
--    Reemplazar el password por uno real fuera del repositorio (o usar \password).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_foodstore') THEN
        CREATE ROLE app_foodstore LOGIN PASSWORD 'CAMBIO_OBLIGATORIO';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'reportes_foodstore') THEN
        CREATE ROLE reportes_foodstore LOGIN PASSWORD 'CAMBIO_OBLIGATORIO';
    END IF;
END
$$;

ALTER ROLE app_foodstore      LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 20;
ALTER ROLE reportes_foodstore LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS CONNECTION LIMIT 10;

-- 3. Membresías (herencia de privilegios)
GRANT operador_ventas TO app_foodstore;
GRANT analista_ventas TO reportes_foodstore;

-- 4. Endurecimiento del esquema public
REVOKE ALL ON SCHEMA public FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO
    admin_datos, operador_ventas, analista_ventas, auditor_seguridad,
    app_foodstore, reportes_foodstore;
GRANT CREATE ON SCHEMA public TO admin_datos;

REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- 5. Privilegios sobre objetos existentes

-- 5.1 admin_datos: mantenimiento de datos y DDL; sin lectura de password_hash.
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE
    ON cliente, producto, pedido, detalle_pedido, intento_login
    TO admin_datos;
GRANT SELECT (id, email, nombre, rol, activo, created_at, ultimo_acceso),
      INSERT,
      UPDATE (email, nombre, rol, activo)
    ON usuario TO admin_datos;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO admin_datos;

-- 5.2 operador_ventas: alta y actualización de ventas; sin DELETE ni credenciales.
GRANT SELECT, INSERT, UPDATE
    ON cliente, producto, pedido, detalle_pedido
    TO operador_ventas;
GRANT SELECT (id, email, nombre, rol, activo) ON usuario TO operador_ventas;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO operador_ventas;

-- 5.3 analista_ventas: solo lectura de datos comerciales.
GRANT SELECT ON cliente, producto, pedido, detalle_pedido TO analista_ventas;

-- 5.4 auditor_seguridad: solo lectura, incluidos intentos de login; sin password_hash.
GRANT SELECT ON cliente, producto, pedido, detalle_pedido, intento_login TO auditor_seguridad;
GRANT SELECT (id, email, nombre, rol, activo, created_at, ultimo_acceso)
    ON usuario TO auditor_seguridad;

-- 5.5 app_foodstore: columnas estrictamente necesarias para autenticación y sesión.
GRANT SELECT (id, email, password_hash, rol, activo),
      INSERT (email, nombre, password_hash, rol),
      UPDATE (password_hash, ultimo_acceso)
    ON usuario TO app_foodstore;
GRANT SELECT, INSERT ON intento_login TO app_foodstore;

-- 5.6 reportes_foodstore: sin grants directos; opera con analista_ventas.

-- 6. Revokes explícitos adicionales
REVOKE CREATE ON SCHEMA public FROM
    operador_ventas, analista_ventas, auditor_seguridad,
    app_foodstore, reportes_foodstore;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
    ON cliente, producto, pedido, detalle_pedido, intento_login
    FROM analista_ventas, auditor_seguridad;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE
    ON usuario
    FROM analista_ventas, auditor_seguridad;

-- 7. Privilegios por defecto para objetos futuros
--    Se aplican a objetos creados por el rol que ejecuta este script.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO admin_datos;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO operador_ventas;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO analista_ventas, auditor_seguridad;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO admin_datos, operador_ventas;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO
        admin_datos, operador_ventas, analista_ventas, auditor_seguridad;

COMMIT;
```

## Supuestos declarados por la IA

- Las tablas viven en el esquema `public` y el script se ejecuta como owner de
  las tablas (necesario para `ALTER DEFAULT PRIVILEGES` y para otorgar sobre
  objetos ajenos).
- `app_foodstore` atiende la aplicación y hereda `operador_ventas`;
  `reportes_foodstore` hereda `analista_ventas`.
- `auditor_seguridad` y `admin_datos` son roles de grupo: las personas se
  conectan con roles personales que se les asignan aparte.
- `password_hash` no debe ser legible por grupos administrativos ni de reporte;
  solo `app_foodstore` lo lee y actualiza. `admin_datos` puede insertar usuarios
  pero no leer ni cambiar el hash.
- Los `ALTER DEFAULT PRIVILEGES` cubren tablas nuevas de forma general: si se
  crea otra tabla con columnas sensibles, habrá que repetir los grants por
  columna.
- No se incluye RLS ni auditoría por triggers; queda para una iteración
  posterior.
- Los passwords son placeholders; deben rotarse con `\password` o
  SCRAM-SHA-256 antes de desplegar.

---

## Por qué se descartó tal cual

1. `GRANT ALL PRIVILEGES ON ALL SEQUENCES ... TO admin_datos` y
   `GRANT EXECUTE ON ALL FUNCTIONS ... TO admin_datos` dan más de lo necesario:
   el rol de datos no necesita todas las secuencias ni todas las funciones
   (incluida `fn_autenticar`).
2. `TRUNCATE` y escritura sobre `intento_login` permiten borrar/alterar
   evidencia de auditoría.
3. `GRANT CREATE ON SCHEMA public TO admin_datos` habilita DDL y la creación de
   funciones que otros roles podrían ejecutar.
4. `SELECT`/`UPDATE` directos sobre `password_hash` para `app_foodstore`
   exponen el hash a la aplicación; se reemplazó por `fn_autenticar`
   `SECURITY DEFINER`.
5. `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` no
   logra su objetivo (se verificó empíricamente): el `EXECUTE` inicial de
   `PUBLIC` se suma a los default privileges.
