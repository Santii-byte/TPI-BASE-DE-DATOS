# Informe del simulacro de incidente de acceso indebido (Parte C)

- **Entorno:** PostgreSQL 17, base `foodstore_u5` en un clúster de desarrollo aislado (puerto 55435).
- **Script:** `sql/simulacro_incidente.sql`.
- **Sesión atacante simulada:** rol de login `reportes_foodstore` (hereda `analista_ventas`).
- **Cuenta comprometida simulada:** `analista1@foodstore.test` (rol `analista_ventas`).
- **Log anonimizado:** `docs/log_simulacro_anonimizado.txt`.
- **Respuesta de la IA:** `docs/respuesta_ia_incidente.md`.
- **Salida del simulacro:** `docs/salida_simulacro.txt`.

---

## 1. Qué ejecutó realmente el equipo

El script se ejecutó en una sola sesión de `psql`, sin transacción explícita y con `ON_ERROR_STOP=off` para que la secuencia continuara después de cada error:

| # | Operación | Resultado real |
|---|---|---|
| 1 | `fn_autenticar('analista1@foodstore.test', 'incorrecta-01')` | `autenticado = false` |
| 2 | `fn_autenticar(... 'incorrecta-02')` | `autenticado = false` |
| 3 | `fn_autenticar(... 'incorrecta-03')` | `autenticado = false` |
| 4 | `fn_autenticar(... 'incorrecta-04')` | `autenticado = false` |
| 5 | `fn_autenticar(... 'incorrecta-05')` | `autenticado = false` |
| 6 | `fn_autenticar('no-existe@foodstore.test', 'incorrecta-06')` | `autenticado = false` (no revela si el email existe) |
| 7 | `fn_autenticar('analista1@foodstore.test', 'ClaveSegura#2026')` | `autenticado = true`, `usuario_id = 1`, `rol = analista_ventas` |
| 8 | `SELECT id, email, nombre, rol, activo, created_at, ultimo_acceso FROM usuario ORDER BY id` | **éxito**: lectura de las 6000 cuentas (columnas permitidas) |
| 9 | `SELECT password_hash FROM usuario LIMIT 1` | **ERROR: permission denied for table usuario** |
| 10 | `SET ROLE admin_datos` | **ERROR: permission denied to set role "admin_datos"** |
| 11 | `GRANT admin_datos TO reportes_foodstore` | **ERROR: permission denied to grant role "admin_datos"** (falta `ADMIN OPTION`) |

**Conclusión operativa:** el intento de escalamiento **falló** en sus tres variantes
(leer el hash, asumir el rol y autoasignarse el rol). El impacto confirmado no es
una escalada de privilegios, sino la **lectura masiva de datos de contacto y
metadatos de las 6000 cuentas** (`id`, `email`, `nombre`, `rol`, `activo`,
`created_at`, `ultimo_acceso`). El `password_hash` no fue legible.

---

## 2. Contraste con la reconstrucción de la IA

### 2.1 Qué acertó

- Identificó correctamente que todo el fragmento corresponde a **una sola
  sesión** (`PID 7556`), con `user=reportes_foodstore`, `db=foodstore_u5` y
  cliente `psql`.
- Ordenó bien la secuencia: conexión, intentos de autenticación, lectura de
  `usuario`, tres intentos denegados y cierre.
- Contó bien las llamadas: **6 contra el usuario 001** (5 fallidas + 1 exitosa)
  y **1 contra el usuario 999**.
- Detectó que `password_hash` fue denegado por privilegio de columna.
- Detectó que `SET ROLE admin_datos` y `GRANT admin_datos` fallaron, y que el
  `DETAIL` del `GRANT` confirma la ausencia de `ADMIN OPTION`.
- Observó que no hay `BEGIN`/`COMMIT` y que `psql` siguió tras los errores.
- Señaló correctamente lo que el log **no** permite saber: el resultado de
  `fn_autenticar`, si el usuario 999 existe, cuántas filas devolvió el SELECT,
  el cuerpo de la función o el resto de `pg_hba.conf`.
- Detectó un punto real: la conexión usó **`method=trust`**, es decir, la
  identidad se obtuvo sin credencial. Es una debilidad del entorno de
  laboratorio y una recomendación válida para producción.

### 2.2 Qué omitió

- No mencionó el **volumen** de la lectura masiva (6000 cuentas), porque el log
  no registra filas devueltas. Es una omisión esperable, no un error.
- No distinguió cuál de las llamadas a `fn_autenticar` fue la exitosa, porque el
  log no registra el valor de retorno. Lo dijo explícitamente.
- No mencionó que la cuenta `analista1@foodstore.test` pertenece al rol
  `analista_ventas`; el log no lo muestra. Correcto no inferirlo.
- No advirtió que `fn_autenticar` **escribe** en `intento_login` y actualiza
  `usuario.ultimo_acceso`, por lo que la frase "sin modificación de datos" no
  es verificable desde el log. Ver 2.3.

### 2.3 Afirmaciones que el log no sustenta

1. **"El ejercicio terminó sin modificación de datos ni lectura sensible".**
   - La parte de "sin modificación de datos" no se puede afirmar: `fn_autenticar`
     es una función `SECURITY DEFINER` que inserta en `intento_login` y
     actualiza `ultimo_acceso`. Esas escrituras no aparecen como sentencias
     separadas en el log. El log solo muestra la llamada a la función.
   - La parte de "sin lectura sensible" contradice su propia observación: el
     `SELECT` de 46.651 leyó emails, nombres y metadatos de todas las cuentas.
     Aunque no leyó `password_hash`, esos datos son personales y sensibles.
2. **"Es un simulacro/ejercicio controlado, no un ataque sorpresivo".**
   - Es una inferencia razonable por las marcas `INICIO_SIMULACRO` /
     `FIN_SIMULACRO`, pero el log por sí solo no prueba la intención. Un atacante
     podría escribir esas marcas. La conclusión correcta es "parece un
     simulacro", no "es un simulacro".
3. **"Los identificadores son sintéticos".**
   - El dominio `example.test` es reservado y sugiere anonimización, pero el log
     no lo declara. Es una inferencia, no un dato del log.
4. **"No hay rate-limit ni lockout".**
   - La IA lo plantea como hipótesis ("el log no muestra bloqueo"), lo cual es
     correcto. No debe leerse como una afirmación de que el control no existe:
     el log no muestra el interior de la función.

### 2.4 Error más significativo de la IA

El error más importante es **contradictorio y de impacto**: afirma que no hubo
"lectura sensible" cuando el propio log muestra una lectura masiva de emails y
nombres, y afirma que no hubo "modificación de datos" sin poder ver el cuerpo de
`fn_autenticar`, que sí escribe en `intento_login` y `usuario.ultimo_acceso`.
Se detectó contrastando el log con el script ejecutado y con el DDL de la
función (`sql/00_base_seguridad.sql`). Es exactamente el tipo de afirmación que
la consigna pide detectar: una causa/efecto asumido sin evidencia.

---

## 3. Decisión de contención del equipo

**La decisión es del equipo y se toma a partir de la evidencia; no se ejecutó
automáticamente ninguna acción sugerida por la IA.**

En un caso real, el equipo aplicaría este orden:

1. **Contener el origen:** cerrar las sesiones activas del rol
   `reportes_foodstore` y bloquear el origen (`::1`/IP) en firewall y en
   `pg_hba.conf`. Si el origen no es confiable, revocar `CONNECT`.
2. **Deshabilitar la cuenta comprometida:** `ALTER ROLE reportes_foodstore
   NOLOGIN` y desactivar la cuenta de aplicación afectada
   (`usuario.activo = false` para `analista1@foodstore.test`).
3. **Rotar credenciales:** forzar cambio de contraseña de la cuenta afectada y
   de los roles de login; revisar si el hash pudo haberse exfiltrado por otro
   canal. En este simulacro el hash **no** fue leído.
4. **Preservar evidencia:** conservar el log, la salida del simulacro y
   `intento_login` antes de limpiar; no borrar la sesión ni el historial.
5. **Evaluar el alcance:** revisar `intento_login` y los logs para confirmar
   cuántas cuentas se leyeron y si hubo otros accesos desde el mismo origen.
6. **Corregir la causa raíz:**
   - reemplazar `trust` por `scram-sha-256` en el entorno de desarrollo y
     producción;
   - agregar a `fn_autenticar` un control de intentos repetidos / bloqueo
     temporal por cuenta y por origen (hoy no existe);
   - revisar si `reportes_foodstore` realmente necesita leer `usuario`; si no,
     quitarle el `GRANT` por columna;
   - no reintroducir un rol de aplicación con `CREATEROLE`/`ADMIN OPTION`: la
     administración de roles y membresías queda en el DBA.
7. **Comunicar:** si los emails/nombres son datos personales, evaluar la
   notificación según la política de protección de datos aplicable.

**Lo que el equipo NO haría:** ejecutar a ciegas el `GRANT` o el cambio de
`pg_hba.conf` que propuso la IA sin validar el alcance, ni asumir que el
incidente terminó porque el escalamiento falló. La lectura masiva de datos de
contacto ya es un impacto que requiere contención y revisión.

---

## 4. Hallazgos para la Parte A

- El esquema de permisos **funcionó** para bloquear la escalada: no hay
  `ADMIN OPTION`, no hay `SET ROLE` y no hay acceso a `password_hash`.
- El rol de reportes **sí puede leer** columnas personales de todas las cuentas.
  Es una decisión de diseño que debe revisarse: si el reporte no necesita
  `email`/`nombre`, conviene reducir el `GRANT` a `id`, `rol`, `activo` y fechas.
- `fn_autenticar` no tiene control de frecuencia. Es una mejora pendiente y
  quedó documentada como limitación, no como fallo del esquema de permisos.
- El entorno de laboratorio usa `trust`; en producción debe usarse
  `scram-sha-256`. Se documenta como configuración de desarrollo, no como
  decisión de despliegue.
