# BITACORA.md — Uso de IA en el TP Unidad 5

- **Proyecto:** Food Store — Seguridad, permisos y auditoría.
- **Integrantes:** Franco Rios y Santino Barone.
- **Asistente utilizado:** OpenCode (modelo DeepSeek V4.1 Flash Free), en reemplazo de Kiro donde la consigna lo menciona.
- **Alcance:** Partes A–E del TP Unidad 5.
- **Nota:** los registros de la IA se resumen; las respuestas completas que se
  consideran evidencia están en `docs/respuesta_ia_draft_roles.md` y
  `docs/respuesta_ia_incidente.md`. Las especificaciones finales están en
  `docs/kiro_roles_spec/`.

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| **A1.** «Redactá una especificación breve (requirements + design) de los roles reales que necesita Food Store: como mínimo los cuatro roles de grupo y los dos de login vistos en clase, más los que consideres necesarios. Justificá cada rol en una oración.» | Propuso los cuatro grupos (`admin_datos`, `operador_ventas`, `analista_ventas`, `auditor_seguridad`) y dos logins (`app_foodstore`, `reportes_foodstore`), más un rol de identidades `admin_seguridad` con `CREATEROLE` y administración de membresías. | El equipo **agregó** `soporte_cliente` / `soporte_foodstore` para atención al cliente y **mantuvo** la separación datos/identidades. La propuesta de `admin_seguridad` se aceptó en el papel en esta etapa, pero se revisó después (A3). Se escribieron `docs/kiro_roles_spec/requirements.md` y `design.md`. |
| **A2.** «Escribí un borrador de `roles.sql` para PostgreSQL 17 con `CREATE ROLE`, `GRANT`, `REVOKE`, permisos por columna sobre `usuario` y `ALTER DEFAULT PRIVILEGES`. Devolvé el SQL y una lista breve de supuestos.» | Devolvió un esqueleto con **privilegios de más**: `GRANT ALL PRIVILEGES ON ALL SEQUENCES ... TO admin_datos`, `GRANT EXECUTE ON ALL FUNCTIONS ... TO admin_datos`, `TRUNCATE` y escritura sobre `intento_login` para el rol de datos, `GRANT CREATE ON SCHEMA public` a `admin_datos`, y `SELECT`/`UPDATE` directos sobre `usuario.password_hash` para `app_foodstore`. | **Caso explícito de permiso más amplio de lo necesario:** el equipo rechazó el `GRANT ALL` y los grants directos sobre `password_hash`. Se reemplazaron por una matriz tabla por tabla, sin `TRUNCATE`, sin `CREATE` para roles de aplicación, sin escritura sobre `intento_login` y con autenticación encapsulada en `fn_autenticar`. El borrador quedó solo como punto de partida; el archivo final es `sql/roles.sql`. |
| **A3.** «Auditá críticamente `roles.sql` para un esquema de mínimo privilegio. Señalá privilegios más amplios de lo necesario, riesgos de escalamiento y problemas de herencia/`ADMIN OPTION`. No edites archivos.» | Encontró que `admin_seguridad` tenía `CREATEROLE` + `ADMIN OPTION`: podía re-otorgarse un rol con `INHERIT`/`SET`, o crear un login nuevo y asignárselo. También observó que la separación de funciones no se sostenía. | **Caso de permiso de más detectado y corregido:** se eliminaron `admin_seguridad` y `seguridad_foodstore` de `roles.sql`. La administración de roles y el alta de cuentas quedan en el DBA. Se documentó la decisión en `requirements.md`, `design.md` y `sql/roles.sql`. Se volvió a ejecutar la verificación (A5). |
| **A4.** «¿Cómo endurecemos los privilegios por defecto y `PUBLIC` para que las tablas y funciones futuras no hereden permisos de más?» | Propuso revocar `DELETE` al rol de datos en los defaults, revocar `TEMPORARY` sobre la base y agregar `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC`. | El equipo aceptó las dos primeras y **comprobó que la tercera no funciona**: los default privileges se *suman* al ACL inicial de la función, que ya trae `EXECUTE` para `PUBLIC`. Se creó una función de prueba y `PUBLIC` seguía ejecutándola. Se reemplazó por la regla real: **toda función nueva debe llevar `REVOKE ... FROM PUBLIC` explícito**, como `fn_autenticar`; quedó documentado en `design.md`. |
| **A5.** «Mostrame cómo verificar con `\du`, `information_schema.role_table_grants` y pruebas negativas que cada rol tiene exactamente lo previsto.» | Propuso consultas sobre `pg_roles`, `pg_auth_members`, `role_table_grants` y `column_privileges`, más pruebas con `has_table_privilege` / `has_column_privilege`. | El equipo las ejecutó contra el clúster real, agregó la prueba de default privileges con una tabla futura y guardó la salida en `docs/verificacion_permisos.txt`. Detectó que **`ALTER DEFAULT PRIVILEGES` acumula**: una corrida anterior seguía dando `DELETE` al rol de datos, y hubo que agregar un `REVOKE DELETE` explícito antes de volver a otorgar. |
| **B1.** «Configurá el servidor de desarrollo con `log_connections`, `log_disconnections` y `log_statement` en un nivel que registre modificaciones. Explicá qué valor conviene y por qué.» | Recomendó `log_connections = on`, `log_disconnections = on` y `log_statement = 'mod'` como mínimo; mencionó `'all'` como alternativa más verbosa. Propuso `log_line_prefix` con timestamp, PID, usuario, base y host. | El equipo eligió **`log_statement = 'all'`** en forma consciente: la Parte C necesita reconstruir una **lectura** masiva, y `'mod'` no registra `SELECT`. Se documentó el desvío y su costo en `docs/informe_auditoria.md`. |
| **B2.** «Analizá el fragmento de log: qué sirve para auditar (quién, qué, cuándo, desde dónde), qué queda fuera del alcance nativo y si el log es un activo sensible. ¿Quién debería leerlo?» | Respondió que el log permite reconstruir usuario, sentencia, timestamp, host y errores; que no da filas afectadas ni valores de retorno; y que el archivo es sensible porque contiene SQL con literales. Recomendó permisos `0600/0640` y acceso solo de DBA/seguridad. | El equipo aceptó el análisis y lo amplió con evidencia propia: el log capturó la **contraseña en texto claro** dentro de la llamada a `fn_autenticar`. Se documentó en `docs/informe_auditoria.md` y en `docs/log_auditoria_prueba.txt`. |
| **C1.** «Anonimizá este fragmento de log antes de dárselo a una IA: reemplazá mails, nombres y cualquier dato identificable por valores sintéticos, con el mismo criterio de `usuario_anon`.» | Propuso reemplazar los emails por identificadores sintéticos, redactar las contraseñas y ocultar la ruta del servidor. | El equipo revisó el resultado antes de continuar: verificó que no quedaran mails reales, claves ni rutas locales. El log anonimizado quedó en `docs/log_simulacro_anonimizado.txt`. |
| **C2.** «Te entrego únicamente este log anonimizado. Reconstruí qué ocurrió, en qué orden, y proponé una hipótesis de contención. Si algo no se puede determinar con el log, decilo explícitamente. No agregues contexto externo.» | Reconstruyó correctamente la sesión única (PID 7556), el orden conexión → 7 llamadas a `fn_autenticar` → lectura de `usuario` → tres intentos denegados → cierre. Contó bien 6 llamadas al usuario 001 y 1 al 999, y detectó `method=trust`. | **Contraste humano:** la secuencia y los conteos coinciden con el script ejecutado. Pero la IA afirmó que el ejercicio terminó «sin lectura sensible» y «sin modificación de datos». El equipo detectó que el propio log muestra la lectura masiva de emails/nombres y que `fn_autenticar` escribe en `intento_login` y `usuario.ultimo_acceso`. Se marcaron como afirmaciones no sustentadas en `docs/informe_incidente.md`. |
| **C3.** «Con ese mismo log, ¿qué harías para contener el incidente en un caso real?» | Propuso bloquear el origen, deshabilitar el rol, rotar credenciales, preservar evidencia, revisar el alcance y corregir `trust`/rate-limit. | El equipo **no ejecutó automáticamente** ninguna acción: evaluó la propuesta, fijó su propio orden de contención y dejó explícito que la decisión es humana y basada en evidencia (`docs/informe_incidente.md`, §3). Se descartó tratar la sugerencia de la IA como runbook. |
| **D1.** «Construí/actualizá `usuario_anon` con datos sintéticos deterministas: conservá lo necesario para agregar por rol y mes de alta, reemplazá email, nombre, hash y `ultimo_acceso` con valores sintéticos.» | Propuso conservar `id`, `rol`, `activo` y `created_at`; reemplazar email/nombre por valores derivados del `id` y anular `ultimo_acceso`. | El equipo lo implementó en `sql/usuario_anon.sql` sin `random()`. Verificó 6000 filas, 5 roles y 12 meses, sin diferencias con `usuario` (`mismos roles = 0`, `mismos meses = 0`). |
| **D2.** «Escribí una consulta de agregación sobre `usuario_anon` (cantidad de usuarios por rol y por mes de alta) y la consulta equivalente sobre la tabla real `usuario`. Agregá una comparación que devuelva solo las diferencias.» | Devolvió las dos consultas con `GROUP BY rol, date_trunc('month', created_at)` y un `FULL OUTER JOIN` con `IS DISTINCT FROM` para comparar. | El equipo ejecutó ambas en `foodstore_u5`: la comparación devolvió **0 filas**; los totales por rol y por mes coinciden uno a uno. Evidencia en `docs/resultados_equivalencia.txt` y `docs/verificacion_equivalencia.md`. |
| **D3.** «¿Qué información concreta de Food Store no debería salir nunca hacia un asistente de IA sin pasar antes por este proceso de anonimización?» | Mencionó emails, nombres, teléfonos, direcciones, documentos, historiales de compra, fechas individuales, hashes y logs crudos con literales SQL. | El equipo aceptó la respuesta y la redactó en `docs/verificacion_equivalencia.md` (§4), agregando que solo deben salir agregados o identificadores sintéticos verificados. |
| **E1.** «Revisá el historial de Git del repositorio: ¿refleja el avance por partes? ¿Los mensajes son legibles? ¿Qué se debería hacer distinto?» | Señaló que el historial tiene mensajes genéricos («Actualizacion», «f», «md»), varios merges y que el TP U5 todavía no está commiteado. | El equipo confirmó el diagnóstico y dejó la nota de la sección «Revisión del historial de Git»: commitear por parte, con mensajes descriptivos y sin mezclar reorganizaciones con cambios funcionales. Los commits los hace el equipo, no la IA. |

---

## Caso más significativo de error o imprecisión de la IA

El caso más significativo fue la **reconstrucción del incidente (C2)**: la IA describió
correctamente la secuencia, los PIDs y las denegaciones, pero afirmó que el ejercicio había
terminado «sin lectura sensible» y «sin modificación de datos». Ambas afirmaciones son
insostenibles con el propio material: el log muestra un `SELECT` masivo de `email`, `nombre` y
metadatos de las 6000 cuentas, y `fn_autenticar` es `SECURITY DEFINER` y escribe en
`intento_login` y `usuario.ultimo_acceso` aunque el log solo registre la llamada. El equipo lo
detectó contrastando el log con el script ejecutado (`sql/simulacro_incidente.sql`) y con el DDL
de la función (`sql/00_base_seguridad.sql`), y dejó el contraste explícito en
`docs/informe_incidente.md` §2.3. Es el ejemplo que mejor muestra por qué no se puede aceptar una
reconstrucción de IA sin verificarla contra la ejecución real.

Un segundo caso relevante fue el **permiso de más en `roles.sql` (A3)**: la IA propuso un rol
`admin_seguridad` con `CREATEROLE` y `ADMIN OPTION`, que en PostgreSQL permite re-otorgarse el rol
o crear un login nuevo y asignárselo. Se detectó pidiendo una auditoría crítica del propio archivo
y se corrigió eliminando el rol.

Un tercer caso fue la **recomendación técnica que no funciona (A4)**: `ALTER DEFAULT PRIVILEGES ...
REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` no elimina el `EXECUTE` inicial de `PUBLIC`. Se detectó
creando una función de prueba y comprobando que `PUBLIC` seguía pudiendo ejecutarla; se reemplazó
por un `REVOKE` explícito en cada función.

---

## Revisión del historial de Git

**Estado observado:** el historial previo al TP U5 tiene mensajes poco descriptivos
(`Actualizacion`, `f`, `md`, `borrar archivo`), varios commits de merge y reorganizaciones
mezcladas con cambios funcionales. El trabajo del TP U5 está **sin commitear** al momento de
escribir esta bitácora; el commit lo hace el equipo.

**Qué se haría distinto la próxima vez:**

1. Un commit por parte (A, B, C, D, E), con mensaje en imperativo y alcance claro
   (por ejemplo: `feat(u5-A): roles y privilegios de mínimo privilegio`).
2. No mezclar movimientos de archivos o reorganizaciones con cambios de lógica.
3. Commits pequeños y verificables: script + salida + informe de la parte juntos.
4. Etiquetar el cierre de cada TP (`tag: tp-u5`) para que el historial sea navegable.
5. Evitar mensajes de una sola palabra; mínimo un título y, si hace falta, un cuerpo breve.

---

## Trazabilidad de archivos por parte

| Parte | Archivos principales |
|---|---|
| A | `sql/roles.sql`, `sql/verificar_permisos.sql`, `docs/verificacion_permisos.txt`, `docs/kiro_roles_spec/requirements.md`, `docs/kiro_roles_spec/design.md` |
| B | `sql/auditoria_test.sql`, `docs/log_auditoria_prueba.txt`, `docs/salida_prueba_auditoria.txt`, `docs/informe_auditoria.md` |
| C | `sql/simulacro_incidente.sql`, `docs/salida_simulacro.txt`, `docs/log_simulacro_anonimizado.txt`, `docs/respuesta_ia_incidente.md`, `docs/informe_incidente.md` |
| D | `sql/usuario_anon.sql`, `sql/consultas_equivalencia.sql`, `docs/resultados_equivalencia.txt`, `docs/verificacion_equivalencia.md` |
| E | `BITACORA.md`, `README.md` |
