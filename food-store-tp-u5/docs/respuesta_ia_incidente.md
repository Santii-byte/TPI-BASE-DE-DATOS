# Respuesta de la IA a partir del log anonimizado (Parte C)

> **Prompt entregado a OpenCode:** únicamente el fragmento
> `docs/log_simulacro_anonimizado.txt`, sin contexto adicional.
> **Respuesta textual recibida:** se transcribe a continuación.

---

# Reconstrucción del evento

Todo el fragmento corresponde a **una sola sesión/backend** (PID `7556`), abierta y cerrada dentro del mismo segundo, sobre `db=foodstore_u5` con el usuario `reportes_foodstore` y cliente `psql`. No hay otras sesiones en el fragmento.

## Cronología (orden de líneas del log)

| Hora (.mmm) | Evento | Resultado |
|---|---|---|
| 46.615 | `connection received` desde `::1:49211` | — |
| 46.616 | `connection authenticated` user=`reportes_foodstore`, **method=trust** (`pg_hba.conf:121`) | OK sin credencial |
| 46.616 | `connection authorized`, `application_name=psql` | OK |
| 46.619 | `SELECT 'INICIO_SIMULACRO'` | OK (marca de inicio) |
| 46.620 | `fn_autenticar('usuario.anon.001@example.test', [redactado])` | sin error registrado |
| 46.631 | idem `001` (2ª vez) | sin error |
| 46.635 | idem `001` (3ª) | sin error |
| 46.639 | idem `001` (4ª) | sin error |
| 46.642 | idem `001` (5ª) | sin error |
| 46.646 | `fn_autenticar('usuario.anon.999@example.test', [redactado])` | sin error |
| 46.647 | `fn_autenticar('usuario.anon.001@example.test', [redactado])` (6ª de `001`) | sin error |
| 46.651 | `SELECT id, email, nombre, rol, activo, created_at, ultimo_acceso FROM usuario ORDER BY id` | OK (no hay línea ERROR) |
| 46.677 | `SELECT password_hash FROM usuario LIMIT 1` | **ERROR: permission denied for table usuario** |
| 46.677 | `SET ROLE admin_datos` | **ERROR: permission denied to set role** |
| 46.677 | `GRANT admin_datos TO reportes_foodstore` | **ERROR: permission denied to grant role** (DETAIL: falta ADMIN option) |
| 46.678 | `SELECT 'FIN_SIMULACRO'` | OK (marca de cierre) |
| 46.678 | `disconnection` (session time 0:00:00.068) | — |

## Lectura de la secuencia

1. **Es un simulacro/ejercicio controlado, no un ataque sorpresivo.** Las marcas `INICIO_SIMULACRO` / `FIN_SIMULACRO` delimitan explícitamente el ejercicio, y los identificadores (`anon.001`, `anon.999`, dominio `example.test`) son sintéticos.
2. **Fase 1 — intentos de autenticación contra `fn_autenticar`:** 7 llamadas, 6 contra el usuario `001` y 1 contra el usuario `999`. La primera llamada tarda ~11 ms y las siguientes ~3–4 ms; la diferencia es consistente con calentamiento de plan/caché, aunque el log no lo prueba.
3. **Fase 2 — reconocimiento de datos:** se listan columnas no sensibles de `usuario` (id, email, nombre, rol, activo, fechas), lo que **sí** está permitido al rol.
4. **Fase 3 — tres intentos de elevación/acceso indebido, en ráfaga (mismo milisegundo 46.677):**
   - leer el hash de contraseña → denegado,
   - `SET ROLE admin_datos` → denegado,
   - auto-otorgarse `admin_datos` por `GRANT` → denegado.
5. **Fase 4 — cierre ordenado** con `FIN_SIMULACRO` y desconexión. No hay `BEGIN`/`COMMIT` ni secuelas de transacción abortada: cada sentencia corrió en autocommit y `psql` siguió tras cada error (no había `ON_ERROR_STOP`).

## Qué NO se puede determinar con este log

- **El valor real del secreto:** ambos parámetros están reemplazados por `[SECRETO-REDACTADO]`. No se puede saber si las 6 llamadas usaron la misma clave o claves distintas.
- **El resultado de `fn_autenticar`:** no hay `ERROR` ni salida registrada; **no se sabe** si devolvió éxito, fallo, bloqueo, cuántas filas, ni si aplica rate-limit o lockout. Solo se sabe que no lanzó excepción.
- **Si `usuario.anon.999` existe** y qué devolvió esa llamada.
- **El contenido devuelto** por el `SELECT` de 46.651 (el log no registra filas ni cantidades).
- **El DDL/definición de `fn_autenticar`:** no se ve su cuerpo, si es `SECURITY DEFINER`, su owner ni su `search_path`. Esto es clave y el log no lo responde.
- **La configuración completa de `pg_hba.conf`:** solo se sabe que la línea 121 usa `trust` para esta conexión; no se ve el resto del archivo.
- **La membresía/atributos reales del rol** más allá de lo inferible: los errores prueban que no puede leer `password_hash` ni hacer `SET ROLE`, pero no se listan sus grants.
- **Actividad fuera del fragmento:** no se puede afirmar que no hubiera otras sesiones en paralelo, solo que no aparecen aquí.

## Hipótesis de contención

**Lo que el simulacro demuestra (contención efectiva en la capa de privilegios):** `reportes_foodstore` opera bajo **mínimo privilegio a nivel de columna** — el `SELECT` amplio sobre `usuario` pasa, pero `password_hash` cae con `permission denied for table usuario`, que es exactamente el mensaje que PostgreSQL emite cuando no hay privilegio de columna sobre el objeto. Además el rol **no es miembro utilizable de `admin_datos`** (falla `SET ROLE`) y **no tiene `ADMIN OPTION`** sobre ese rol (falla el `GRANT`). Es decir: la triple vía de escalada (leer hash → asumir rol → auto-asignarse rol) quedó cerrada y el ejercicio terminó sin modificación de datos ni lectura sensible.

**El punto débil que el log sí expone:** la autenticación de esa conexión fue **`method=trust`**. Eso significa que cualquier proceso que llegue por esa regla de `pg_hba.conf` (aquí loopback `::1`) obtiene la identidad `reportes_foodstore` **sin credencial**. La contención de privilegios no compensa que la puerta de entrada no pida nada: el simulacro validó "qué puede hacer el rol", pero no "quién puede convertirse en el rol".

**Hipótesis de contención propuesta (a validar, no verificable con el log):**
1. Reemplazar `trust` por `scram-sha-256` en la línea 121 de `pg_hba.conf` (o restringirla a `local`/usuarios administrativos puntuales) y forzar recarga de configuración.
2. Confirmar por catálogo (no por log) que los grants de `reportes_foodstore` son **solo columnas** de reporting y que no hereda roles con acceso a `password_hash`.
3. Auditar `fn_autenticar`: si es `SECURITY DEFINER`, verificar owner, `search_path` fijo y ausencia de parámetros que permitan inyección; el log no permite descartar que la función sea el vector real de escalada.
4. Verificar si existe control de intentos repetidos (6 llamadas al mismo usuario en 27 ms); el log no muestra bloqueo alguno.
5. Registrar en el propio simulacro si `fn_autenticar` devolvió éxito/fallo, para que el ejercicio sea evaluable; hoy esa evidencia falta.

**Conclusión:** el simulacro fue una prueba de contención *exitosamente contenida en la capa de privilegios SQL*, pero **el vector de entrada sigue siendo `trust`**, y la seguridad de `fn_autenticar` no puede evaluarse con este fragmento.
