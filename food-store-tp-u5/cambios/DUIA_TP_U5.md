# DUIA — TP Unidad 5 (Food Store)

## Herramienta

- OpenCode
- Modelo: DeepSeek V4.1 Flash Free
- Fecha: 2026-11-06 / 2026-11-08
- Alcance: TP Unidad 5 completo (Partes A–E)

## Prompt utilizado

> «Ahora sigamos con el TP de la unidad 5, es el siguiente archivo .txt. Leelo
> y segui las reglas que pide, todo lo que pida que sea en Kiro, que sea para
> esta sesion con OpenCode, no con Kiro.»
>
> Adjunto: `TP-U5.txt`.

Durante la ejecución se usaron además estos prompts parciales:

1. «Redactá una especificación breve (requirements + design) de los roles
   reales que necesita Food Store…»
2. «Escribí un borrador de `roles.sql` para PostgreSQL 17 con `CREATE ROLE`,
   `GRANT`, `REVOKE`, permisos por columna y `ALTER DEFAULT PRIVILEGES`…»
3. «Auditá críticamente `roles.sql`… señalá privilegios más amplios de lo
   necesario, riesgos de escalamiento y problemas de herencia/`ADMIN OPTION`.»
4. «Configurá el servidor con `log_connections`, `log_disconnections` y
   `log_statement`…»
5. «Anonimizá este fragmento de log antes de dárselo a una IA…»
6. «Te entrego únicamente este log anonimizado. Reconstruí qué ocurrió y
   proponé una hipótesis de contención…»
7. «Construí/actualizá `usuario_anon` con datos sintéticos deterministas…»
8. «Escribí la consulta de agregación sobre `usuario_anon` y la equivalente
   sobre `usuario`…»
9. «Revisá el historial de Git del repositorio…»

## Qué generó

- Estructura completa `food-store-tp-u5/` con `sql/` y `docs/`.
- `docs/kiro_roles_spec/requirements.md` y `design.md` (redactados en OpenCode,
  no en Kiro).
- `sql/00_base_seguridad.sql`: tablas `usuario` e `intento_login`, función
  `fn_autenticar` `SECURITY DEFINER`, datos de prueba y transferencia de
  propiedad a `foodstore_owner`.
- `sql/roles.sql`: seis roles de grupo, tres roles de login, privilegios por
  tabla y por columna, `ALTER DEFAULT PRIVILEGES` y revocaciones de `PUBLIC`.
- `sql/usuario_anon.sql` y `sql/consultas_equivalencia.sql`.
- `sql/auditoria_test.sql`, `sql/simulacro_incidente.sql` y
  `sql/verificar_permisos.sql`.
- Evidencia en `docs/`: verificación de permisos, log de auditoría, log del
  simulacro anonimizado, respuesta de la IA, contraste, informe de auditoría,
  informe de incidente y verificación de equivalencia.
- `BITACORA.md` y `README.md`.
- Respuestas literales de la IA conservadas en
  `docs/respuesta_ia_incidente.md` y en el historial de la sesión.

## Qué se modificó o descartó y por qué

_(Campo reservado para completar por el equipo.)_

## Verificación realizada

_(Campo reservado para completar por el equipo.)_
