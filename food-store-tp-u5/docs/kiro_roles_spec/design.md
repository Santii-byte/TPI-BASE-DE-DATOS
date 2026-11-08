# Design — Esquema de roles y permisos de mínimo privilegio (Food Store)

> **Nota de autoría:** documento redactado en la sesión de **OpenCode**, no en Kiro.
> La carpeta conserva el nombre `kiro_roles_spec/` por requisito de entrega.

## 1. Jerarquía de roles

```text
foodstore_owner  (dueño de objetos, NOLOGIN)
      │  owned by
      ├── tablas comerciales: cliente, producto, pedido, detalle_pedido
      ├── tablas de seguridad: usuario, intento_login, usuario_anon
      └── función fn_autenticar()

admin_datos        (NOLOGIN)  ── DML comercial, sin cuentas ni DDL
operador_ventas    (NOLOGIN)  ── alta/edición de ventas, sin DELETE
analista_ventas    (NOLOGIN)  ── lectura comercial + columnas de usuario
auditor_seguridad  (NOLOGIN)  ── lectura de auditoría + columnas de usuario
soporte_cliente    (NOLOGIN)  ── datos de contacto de cliente

app_foodstore        (LOGIN) IN ROLE operador_ventas
reportes_foodstore   (LOGIN) IN ROLE analista_ventas
soporte_foodstore    (LOGIN) IN ROLE soporte_cliente

DBA (superusuario)   ── administra roles y altas de cuenta, fuera de la app
```

`admin_seguridad` / `seguridad_foodstore` **no existen** en la versión final:
ver §6, alternativa descartada.

## 2. Matriz de privilegios sobre tablas

Leyenda: `S` = SELECT, `I` = INSERT, `U` = UPDATE, `D` = DELETE, `—` = sin
privilegio. `C(...)` indica privilegio a nivel de columna.

| Tabla | admin_datos | operador_ventas | analista_ventas | auditor_seguridad | soporte_cliente |
|---|---|---|---|---|---|
| `cliente` | S I U D | S I U | S | S | C(id,nombre,email,telefono,activo) + U(email,telefono) |
| `producto` | S I U D | S | S | S | — |
| `pedido` | S I U D | S I U | S | S | S(id,cliente_id,fecha,estado) |
| `detalle_pedido` | S I U D | S I U | S | S | — |
| `usuario` | — | — | C(id,email,nombre,rol,activo,created_at,ultimo_acceso) | C(id,email,nombre,rol,activo,created_at,ultimo_acceso) | — |
| `intento_login` | — | — | — | S | — |
| `usuario_anon` | — | — | S | S | — |

### Decisiones de diseño

1. **`admin_datos` no toca `usuario`.** La administración de datos y la de
   identidades son funciones distintas. El alta de cuentas la ejecuta el DBA
   con un procedimiento controlado, nunca el rol de datos.
2. **`operador_ventas` no tiene DELETE.** La baja de pedidos se hace por cambio
   de estado, no por borrado físico. `detalle_pedido` tiene `ON DELETE CASCADE`,
   así que un DELETE sobre `pedido` podría borrar historia en cascada.
3. **`analista_ventas` y `auditor_seguridad` leen `usuario` por columna.** El
   `password_hash` queda fuera de su alcance incluso con `SELECT *`.
4. **`soporte_cliente` actualiza solo `email` y `telefono`.** No puede cambiar
   nombre, estado ni pedidos.
5. **Ningún rol de aplicación administra roles.** Se descartó
   `admin_seguridad` porque `CREATEROLE` + `ADMIN OPTION` permite re-otorgarse
   un rol con `INHERIT`/`SET` o crear un login nuevo y asignárselo. Esa
   administración queda en el DBA.
6. **La aplicación no lee `password_hash` directamente.** Lo hace
   `fn_autenticar()`, `SECURITY DEFINER`, con `search_path = public, pg_temp`.
   Así, un error de la aplicación no expone el hash en una consulta normal y el
   registro de intentos queda centralizado.
7. **Sin `PUBLIC`.** Se revoca todo de `PUBLIC` sobre esquema, tablas,
   secuencias, funciones y base (`CONNECT`/`TEMPORARY`). Los roles de login no
   reciben permisos directos: heredan `USAGE` y los privilegios de su rol de
   grupo.
8. **`ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner`.** Las tablas futuras
   creadas por el dueño heredan la política. Las tablas con columnas sensibles
   nuevas deben recibir el mismo tratamiento por columna que `usuario`; se deja
   documentado como control de despliegue.

## 3. Privilegios por defecto

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- NO existe default privilege que quite el EXECUTE inicial de PUBLIC en
-- funciones: los default privileges se suman al ACL inicial. Cada función
-- nueva necesita REVOKE ALL ... FROM PUBLIC explícito (ver fn_autenticar).
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    REVOKE DELETE ON TABLES FROM admin_datos;  -- por si una corrida previa lo otorgó
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO operador_ventas;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT SELECT ON TABLES TO analista_ventas, auditor_seguridad;
ALTER DEFAULT PRIVILEGES FOR ROLE foodstore_owner IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO admin_datos, operador_ventas;
```

## 4. Autenticación y registro de intentos

`fn_autenticar(p_email text, p_password text)` devuelve
`(autenticado boolean, usuario_id bigint, rol_usuario text)`.

- Busca el usuario activo por email normalizado.
- Compara con `crypt(p_password, password_hash)` (pgcrypto / bcrypt).
- Registra **todo** intento en `intento_login` (`email_intentado`, `exito`,
  `ocurrido_en`, `origen`).
- En éxito actualiza `usuario.ultimo_acceso`.
- No revela si el email existe: el resultado es el mismo para usuario
  inexistente y contraseña incorrecta.
- Es `SECURITY DEFINER`, propiedad de `foodstore_owner`, con `search_path`
  fijo y `EXECUTE` revocado de `PUBLIC`.

## 5. Verificación

1. `\du` para atributos de roles y membresías.
2. `information_schema.role_table_grants` para privilegios de tabla.
3. `information_schema.column_privileges` para permisos de columna.
4. Prueba negativa: `SET ROLE admin_datos` y
   `GRANT admin_datos TO reportes_foodstore` desde una cuenta de reportes.
5. Prueba de default privileges: crear una tabla como `foodstore_owner` y
   comprobar que `analista_ventas` la lee, `operador_ventas` inserta pero no
   borra, `admin_datos` no borra y `PUBLIC` no lee.
6. Prueba de autenticación: intentos fallidos y exitoso contra `fn_autenticar`.

## 6. Alternativas descartadas

| Alternativa | Motivo del descarte |
|---|---|
| `GRANT ALL PRIVILEGES ON ALL TABLES` a `admin_datos` | Incluye `usuario`, `intento_login`, `TRUNCATE` y objetos futuros sensibles; viola mínimo privilegio y separación de funciones. |
| Dar `SELECT` directo sobre `usuario.password_hash` a `app_foodstore` | La aplicación no necesita leer el hash: solo autenticar. Se encapsula en `fn_autenticar`. |
| `GRANT CREATE ON SCHEMA public` a `admin_datos` | Permitiría crear objetos y potencialmente funciones que otros roles ejecuten; el DDL queda reservado al dueño. |
| `CREATEROLE` en `admin_datos` | Un administrador de datos podría crearse una cuenta con más privilegios. |
| `admin_seguridad` con `CREATEROLE` + `ADMIN OPTION` sobre los grupos | La auditoría interna demostró que puede re-otorgarse el rol (`INHERIT/SET TRUE`) o crear un login y asignárselo: no hay contención real. Se elimina; administra el DBA. |
| Roles de login con grants directos | Duplicaría la política y haría difícil auditarla; se prefiere herencia desde roles de grupo. |
| `PUBLIC` con `EXECUTE` sobre `fn_autenticar` | Cualquier rol podría invocar la función y generar intentos; se restringe a los roles de login. |
