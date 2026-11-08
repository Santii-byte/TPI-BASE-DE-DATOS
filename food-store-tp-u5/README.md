# Food Store — TP Unidad 5: Roles, auditoría y protección de datos

Trabajo práctico de **seguridad en PostgreSQL**: diseño de permisos de mínimo
privilegio, auditoría nativa, simulacro de incidente, anonimización y verificación
de equivalencia.

- **Integrantes:** Franco Rios y Santino Barone.
- **Motor:** PostgreSQL 17.
- **Herramientas:** OpenCode (en lugar de Kiro), psql, Git.
- **Base:** esquema comercial de Food Store de `TP2_Concurrencia/Script.sql`
  más una capa de seguridad propia (`usuario`, `intento_login`,
  `fn_autenticar`).

---

## Estructura

```text
food-store-tp-u5/
├── BITACORA.md                     # Bitácora consolidada de uso de IA (Parte E)
├── README.md
├── cambios/
│   └── DUIA_TP_U5.md               # Declaración de uso de IA del TP
├── sql/
│   ├── 00_base_seguridad.sql       # usuario, intento_login, fn_autenticar, ownership
│   ├── usuario_anon.sql            # Parte D: anonimización determinista
│   ├── roles.sql                   # Parte A: roles, GRANT/REVOKE, defaults
│   ├── verificar_permisos.sql      # Parte A: evidencia de permisos
│   ├── auditoria_test.sql          # Parte B: lectura/insert/update/login fallido
│   ├── simulacro_incidente.sql     # Parte C: intentos, lectura masiva, escalamiento
│   ├── consultas_equivalencia.sql  # Parte D: agregados sobre usuario y usuario_anon
│   └── cleanup_roles_obsoletos.sql # limpieza opcional de roles de borradores
└── docs/
    ├── kiro_roles_spec/
    │   ├── requirements.md
    │   └── design.md
    ├── verificacion_permisos.txt
    ├── informe_auditoria.md
    ├── log_auditoria_prueba.txt
    ├── salida_prueba_auditoria.txt
    ├── salida_simulacro.txt
    ├── log_simulacro_anonimizado.txt
    ├── respuesta_ia_draft_roles.md
    ├── respuesta_ia_incidente.md
    ├── informe_incidente.md
    ├── resultados_equivalencia.txt
    └── verificacion_equivalencia.md
```

> La carpeta `docs/kiro_roles_spec/` conserva ese nombre por requisito de la
> consigna, pero la especificación se redactó en **OpenCode**, no en Kiro.

---

## Requisitos

1. PostgreSQL 17 con `pgcrypto` disponible.
2. Una base creada para el TP (por ejemplo `foodstore_u5`).
3. Ejecutar como un rol con permisos de superusuario para crear roles y cambiar
   la propiedad de los objetos. El script `roles.sql` también puede ejecutarse
   como `foodstore_owner` una vez creados los roles.

---

## Orden de ejecución

Desde la raíz del repositorio:

```bash
# 1. Esquema comercial base (si la base está vacía)
psql -d foodstore_u5 -f TP2_Concurrencia/Script.sql

# 2. Capa de seguridad: usuario, intento_login, fn_autenticar
psql -d foodstore_u5 -f food-store-tp-u5/sql/00_base_seguridad.sql

# 3. Tabla anonimizada (necesaria para los GRANT de roles.sql)
psql -d foodstore_u5 -f food-store-tp-u5/sql/usuario_anon.sql

# 4. Roles, membresías y privilegios (Parte A)
psql -d foodstore_u5 -f food-store-tp-u5/sql/roles.sql

# 5. Evidencia de permisos (Parte A)
psql -d foodstore_u5 -f food-store-tp-u5/sql/verificar_permisos.sql \
     > food-store-tp-u5/docs/verificacion_permisos.txt

# 6. Prueba de auditoría como rol de aplicación (Parte B)
psql -U app_foodstore -d foodstore_u5 \
     -f food-store-tp-u5/sql/auditoria_test.sql \
     > food-store-tp-u5/docs/salida_prueba_auditoria.txt

# 7. Simulacro de incidente como rol de reportes (Parte C)
psql -U reportes_foodstore -d foodstore_u5 \
     -f food-store-tp-u5/sql/simulacro_incidente.sql \
     > food-store-tp-u5/docs/salida_simulacro.txt

# 8. Equivalencia de agregados (Parte D)
psql -d foodstore_u5 -f food-store-tp-u5/sql/consultas_equivalencia.sql \
     > food-store-tp-u5/docs/resultados_equivalencia.txt
```

Si la base viene de un borrador con `admin_seguridad` / `seguridad_foodstore`,
ejecutar antes, **en cada base del clúster**:

```bash
psql -d foodstore_u5       -f food-store-tp-u5/sql/cleanup_roles_obsoletos.sql
psql -d foodstore_u5_clean -f food-store-tp-u5/sql/cleanup_roles_obsoletos.sql
psql -d postgres           -f food-store-tp-u5/sql/cleanup_roles_obsoletos.sql
```

---

## Configuración de auditoría usada (Parte B)

En el clúster de desarrollo aislado se aplicó:

```conf
log_connections = on
log_disconnections = on
log_statement = 'all'
log_line_prefix = '%m [%p] user=%u db=%d host=%r app=%a '
log_min_error_statement = error
log_duration = off
```

`log_statement = 'all'` se eligió por encima del mínimo `'mod'` porque la Parte C
requiere reconstruir una lectura masiva (`SELECT`). El costo y los riesgos se
explican en `docs/informe_auditoria.md`.

---

## Aclaraciones de seguridad

- `fn_autenticar` es `SECURITY DEFINER`, propiedad de `foodstore_owner`, con
  `search_path = public, pg_temp` fijo. La aplicación no lee `password_hash`.
- `REVOKE ALL ON ALL FUNCTIONS ... FROM PUBLIC` afecta también a `pgcrypto`
  (`crypt` vive en `public`); por eso `roles.sql` vuelve a otorgar
  `EXECUTE ON FUNCTION crypt(TEXT, TEXT)` a `foodstore_owner`.
- Los roles de login usan la contraseña placeholder `CAMBIO_OBLIGATORIO`.
  **Debe rotarse** con `\password` antes de cualquier uso real.
- El entorno de laboratorio usa `trust` en `pg_hba.conf`. En producción debe
  usarse `scram-sha-256`.
- `ALTER DEFAULT PRIVILEGES` **acumula**; para quitar un privilegio otorgado
  antes hay que ejecutar un `REVOKE` explícito.
- No existe default privilege que elimine el `EXECUTE` inicial de `PUBLIC` en
  funciones: toda función nueva necesita su `REVOKE ... FROM PUBLIC`.
