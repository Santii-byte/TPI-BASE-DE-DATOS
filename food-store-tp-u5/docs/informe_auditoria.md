# Informe de configuración y uso de la auditoría nativa (Parte B)

- **Motor:** PostgreSQL 17.
- **Entorno:** clúster de desarrollo aislado, puerto 55435, base `foodstore_u5`.
- **Fragmento capturado:** `docs/log_auditoria_prueba.txt`.
- **Salida de la prueba:** `docs/salida_prueba_auditoria.txt`.

---

## 1. Parámetros modificados

La configuración se aplicó en el `postgresql.conf` del clúster de desarrollo
(no en producción) y se reinició el servidor para que tomara los valores:

| Parámetro | Valor aplicado | Motivo |
|---|---|---|
| `log_connections` | `on` | Registrar cada intento de conexión y su resultado. |
| `log_disconnections` | `on` | Registrar el cierre de sesión y su duración. |
| `log_statement` | `'all'` | Registrar lectura, escritura y DDL. La consigna pedía como mínimo un nivel que registre modificaciones (`'mod'`); se eligió `'all'` para poder capturar también la lectura masiva del simulacro. |
| `log_line_prefix` | `'%m [%p] user=%u db=%d host=%r app=%a '` | Incluir timestamp con milisegundos, PID, usuario, base, host/puerto y aplicación. |
| `log_min_error_statement` | `'error'` | Registrar la sentencia que produjo un error (por ejemplo, el `GRANT` denegado). |
| `log_duration` | `off` | Evitar duplicar la duración; el plan de auditoría no la necesita. |

> **Desvío consciente:** `log_statement = 'all'` es más verboso que el mínimo
> pedido. Se eligió así porque la Parte C necesita reconstruir una **lectura**
> masiva, y `'mod'` no registra `SELECT`. El costo es un volumen mayor de log y
> el riesgo de capturar parámetros sensibles (ver punto 4).

## 2. Secuencia de prueba y fragmento

`sql/auditoria_test.sql` se ejecutó como `app_foodstore` y contiene:

1. una lectura (`SELECT count(*) FROM cliente`);
2. una inserción (`INSERT INTO cliente ...`);
3. una actualización (`UPDATE cliente ...`);
4. un intento fallido de `fn_autenticar`;
5. `ROLLBACK` para no dejar datos de prueba.

El fragmento del log está en `docs/log_auditoria_prueba.txt`. Extracto:

```text
connection received: host=::1 port=51517
connection authenticated: user="app_foodstore" method=trust
connection authorized: user=app_foodstore database=foodstore_u5 application_name=psql
statement: SELECT 'INICIO_PRUEBA_AUDITORIA' AS marca;
statement: SELECT count(*) AS clientes_visibles FROM cliente;
statement: BEGIN;
statement: INSERT INTO cliente (nombre, email, telefono) VALUES (...);
statement: UPDATE cliente SET telefono = ... WHERE email = ...;
statement: SELECT * FROM fn_autenticar('analista1@foodstore.test', 'clave-incorrecta');
statement: ROLLBACK;
statement: SELECT 'FIN_PRUEBA_AUDITORIA' AS marca;
disconnection: session time: 0:00:00.032 user=app_foodstore database=foodstore_u5 host=::1 port=51517
```

## 3. Qué información aporta y qué queda fuera

### 3.1 Información útil para auditoría

| Pregunta | Campo del log | Ejemplo del fragmento |
|---|---|---|
| **Quién** | `user=%u` | `user=app_foodstore` |
| **Qué** | `statement:` / `STATEMENT:` | `INSERT INTO cliente ...`, `SELECT * FROM fn_autenticar(...)` |
| **Cuándo** | `%m` | `2026-11-06 10:39:35.376 -03` |
| **Desde dónde** | `host=%r` y `connection received` | `host=::1(51517)` |
| **Sesión** | `[%p]` | `[9412]` |
| **Resultado** | `ERROR:` / `DETAIL:` / `STATEMENT:` | `permission denied to grant role ...` |
| **Duración** | `disconnection: session time` | `0:00:00.032` |

Con esto se puede reconstruir una secuencia básica: quién se conectó, desde qué
host, qué sentencias ejecutó, en qué orden y cuáles fallaron.

### 3.2 Fuera del alcance de la auditoría nativa

- **Valores fila por fila:** `log_statement` registra el texto SQL, no las filas
  leídas ni los valores modificados. Para eso haría falta un trigger de
  auditoría, CDC o replicación lógica.
- **Resultado de una función:** el log muestra la llamada a `fn_autenticar`, pero
  no si devolvió `true`/`false` ni cuántas filas.
- **Parámetros de protocolo extendido:** si la aplicación usa
  `PREPARE`/`EXECUTE` o el protocolo extendido, el texto puede no incluir los
  valores; `pgaudit.log_parameter` permitiría registrarlos, con el riesgo de
  exponer secretos.
- **Granularidad por objeto y clase:** `pgaudit` permitiría auditar por clases
  (`READ`, `WRITE`, `DDL`, `ROLE`, `FUNCTION`, etc.), por relación y con
  parámetros. No reemplaza un registro fila por fila; para eso se necesita un
  trigger o CDC. La ventaja de `pgaudit` es que separa la auditoría de la
  aplicación y reduce el ruido.
- **Integridad del log:** el log nativo no está firmado ni encadenado. Un
  administrador con acceso al sistema operativo podría alterarlo. Para un
  entorno real conviene enviarlo a un SIEM o a almacenamiento WORM.

## 4. ¿El archivo de log es un activo sensible?

**Sí, y mucho.** El log contiene texto SQL con literales —emails, nombres,
teléfonos y, en este TP, contraseñas enviadas como parámetros a
`fn_autenticar`— además de usuarios, bases, hosts, errores y horarios. Es un
mapa de la operación y puede contener datos personales y secretos.

Por eso:

- **A nivel de sistema operativo:** el archivo debe pertenecer al usuario del
  motor (`postgres`) y al grupo de administración, con permisos `0600` o `0640`
  como máximo; nunca `world-readable`. El directorio de logs debe estar fuera
  del alcance de usuarios de aplicación.
- **A nivel de motor:** solo deberían leerlo el DBA y el equipo de seguridad.
  No debe exponerse por una vista SQL, una API ni una carpeta compartida. Si se
  centraliza, el envío debe ser autenticado y cifrado.
- **Rotación y retención:** definir retención mínima, rotación y borrado seguro;
  el log no debe crecer sin control ni quedar en backups sin protección.
- **Minimización:** evitar `log_statement='all'` en producción si no es
  necesario; si se usa, no registrar parámetros sensibles y proteger el archivo
  como si fuera una tabla con datos personales.

> En este TP el log del simulacro (Parte C) mostró la contraseña en texto claro
> dentro de la sentencia `SELECT * FROM fn_autenticar(..., 'ClaveSegura#2026')`.
> Es una evidencia directa de por qué el log es un activo sensible y de por qué
> la captura de parámetros debe revisarse antes de habilitar
> `log_statement='all'` en producción.
