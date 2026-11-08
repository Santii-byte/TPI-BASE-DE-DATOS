# Requirements — Esquema de roles y permisos de mínimo privilegio (Food Store)

> **Nota de autoría:** esta especificación se redactó en la sesión de **OpenCode**.
> El nombre de la carpeta (`kiro_roles_spec/`) se conserva porque así lo pide la
> consigna del TP, pero **no** fue generada con Kiro.

## 1. Propósito

Definir el esquema de roles y privilegios de Food Store para que cada cuenta
pueda ejecutar **solo** las operaciones que su función laboral requiere, con
separación entre datos comerciales, seguridad de cuentas y auditoría.

## 2. Alcance

Aplica al esquema `public` de la base Food Store (cliente, producto, pedido,
detalle_pedido) y a las tablas de seguridad `usuario`, `intento_login` y
`usuario_anon`. No define todavía políticas RLS ni auditoría con `pgaudit`.

## 3. Roles de grupo (NOLOGIN)

| Rol | Operación que habilita | Por qué esa operación y no otra |
|---|---|---|
| `admin_datos` | SELECT/INSERT/UPDATE/DELETE sobre las tablas comerciales (cliente, producto, pedido, detalle_pedido) y uso de sus secuencias. | Es el rol de mantenimiento de datos: necesita corregir y depurar registros comerciales, pero **no** debe administrar cuentas ni credenciales; por eso no recibe `usuario`, `intento_login`, DDL, `TRUNCATE` ni `CREATE` sobre el esquema. |
| `operador_ventas` | SELECT sobre producto; SELECT/INSERT/UPDATE sobre cliente, pedido y detalle_pedido; uso de secuencias. | Es el rol de la aplicación de ventas: registra y corrige operaciones del día, pero no borra historia ni toca cuentas; por eso no recibe DELETE, `TRUNCATE` ni acceso a `password_hash`. |
| `analista_ventas` | SELECT sobre las tablas comerciales y lectura **por columna** de `usuario` (sin `password_hash`), más SELECT sobre `usuario_anon`. | Es el rol de reportes: necesita agregar ventas y métricas de usuarios, pero no debe ver credenciales ni modificar nada. |
| `auditor_seguridad` | SELECT sobre las tablas comerciales, `intento_login` y `usuario_anon`; lectura **por columna** de `usuario` sin `password_hash`. | Es el rol de auditoría: reconstruye qué pasó, pero no participa de la operación ni puede alterar datos o credenciales. |
| `soporte_cliente` | SELECT por columna sobre cliente y pedido; UPDATE por columna de `telefono` y `email` de cliente. | Es el rol de atención al cliente: actualiza datos de contacto, pero no ve ventas completas, ni usuarios, ni puede cambiar el estado de un pedido. |
| `foodstore_owner` | Dueño de los objetos; sin login. | Permite que los objetos tengan un dueño técnico distinto de las cuentas humanas y que `ALTER DEFAULT PRIVILEGES` sea predecible. |

> **Decisión revisada:** se evaluó un rol `admin_seguridad` con `CREATEROLE` y
> `ADMIN OPTION` sobre los roles de grupo, pero la auditoría interna demostró
> que esa combinación permite re-otorgarse el rol o crear un login nuevo y
> asignárselo. Se descartó. La administración de roles de PostgreSQL y el alta
> de cuentas quedan reservadas al DBA, fuera de la aplicación.

## 4. Roles de login

| Rol de login | Rol de grupo que hereda | Justificación |
|---|---|---|
| `app_foodstore` | `operador_ventas` | Cuenta de la aplicación de ventas; se conecta para registrar operaciones y autenticar usuarios a través de `fn_autenticar`. |
| `reportes_foodstore` | `analista_ventas` | Cuenta de la herramienta de reportes; solo lee datos agregados y columnas no sensibles de `usuario`. |
| `soporte_foodstore` | `soporte_cliente` | Cuenta del equipo de atención; solo consulta y actualiza datos de contacto. |

## 5. Requisitos funcionales

- **RF1 — Mínimo privilegio:** ningún rol recibe `SUPERUSER`, `CREATEDB`,
  `CREATEROLE` ni `BYPASSRLS`.
- **RF2 — Sin `PUBLIC`:** se revocan privilegios sobre esquema, tablas,
  secuencias y funciones de `PUBLIC`, y se revoca `TEMPORARY` sobre la base.
- **RF3 — Separación de funciones:** quien administra datos comerciales
  (`admin_datos`) no administra cuentas ni roles. La administración de roles
  de PostgreSQL queda en el DBA; ningún rol de aplicación puede `SET ROLE`,
  otorgar membresías ni crear roles.
- **RF4 — Permiso a nivel de columna:** `analista_ventas`, `auditor_seguridad` y
  `soporte_cliente` reciben `GRANT SELECT (...)` o `GRANT UPDATE (...)` sobre
  columnas específicas, nunca sobre `usuario.password_hash`.
- **RF5 — Autenticación encapsulada:** `app_foodstore` **no** recibe SELECT
  directo sobre `usuario.password_hash`; autentica mediante
  `fn_autenticar(text, text)`, que es `SECURITY DEFINER`, con `search_path`
  fijo y `EXECUTE` otorgado solo a los roles de login.
- **RF6 — Default privileges:** las tablas futuras creadas por
  `foodstore_owner` en `public` heredan la política (lectura para analystas y
  auditoría, DML para administración y operación), y `PUBLIC` no hereda nada.
- **RF7 — Reversibilidad:** `roles.sql` debe poder ejecutarse más de una vez
  sin fallar (creación idempotente de roles y `REVOKE`/`GRANT` repetibles).
- **RF8 — Verificabilidad:** el estado final se comprueba con `\du`,
  `information_schema.role_table_grants` y
  `information_schema.column_privileges`.

## 6. Criterios de aceptación

1. `\du` muestra los seis roles de grupo (incluido `foodstore_owner`) y los
   tres roles de login con los atributos previstos.
2. La consulta sobre `role_table_grants` coincide exactamente con la matriz de
   `design.md`.
3. `app_foodstore` no puede leer `usuario.password_hash` ni otorgarse
   `admin_datos`.
4. `reportes_foodstore` puede leer las columnas permitidas de `usuario`, pero
   no `password_hash`.
5. Una tabla nueva creada por `foodstore_owner` recibe los privilegios por
   defecto declarados.
6. La simulación de incidente deja evidencia en el log y el intento de
   escalamiento falla.

## 7. Fuera de alcance

- Row Level Security (RLS) por fila.
- `pgaudit` y auditoría por triggers.
- Rotación automática de contraseñas.
- Integración con un proveedor de identidad externo.
