# Verificación de los TP anteriores

Fecha: 2026-11-12.
Entorno: clúster PostgreSQL 17.11 temporal y limpio, puerto 55438, sin datos
reales. Cliente `psql` 17. SQLite 3.50.4.

El objetivo fue comprobar que los entregables anteriores siguen ejecutándose y
que TP8 puede apoyarse en ellos sin romper nada.

## TP5 - Modelo, datos e índices

| Control | Resultado |
|---|---|
| `TP5/food-store/schema.sql` | OK: 4 tablas, 2 tipos, 2 índices |
| `TP5/food-store/data.sql` | OK: carga masiva completa |
| `cliente` | 20.000 filas |
| `producto` | 50.000 filas |
| `pedido` | 200.000 filas |
| `detalle_pedido` | 399.997 filas (las colisiones de PK se evitan con `ON CONFLICT DO NOTHING`) |
| `idx_pedido_cliente_id` | usado por el plan de la consulta de 90 días |
| Índices y checks | creados sin errores |

Observación: la diferencia entre 400.000 intentos y 399.997 filas está
documentada en el propio `data.sql`; no es un fallo.

## TP6 - FNBC y desnormalización

| Control | Resultado |
|---|---|
| `00_migracion_esquema_tp5.sql` | OK: `categoria` con 60 filas, 50.000 productos con categoría, 0 sin categoría |
| `tp_fnbc_control_lote.sql` | OK: vista de compatibilidad con las 3 filas originales |
| Diferencia simétrica FNBC | 0 filas en el original y 0 en la vista |
| `00_ejecutar_tp5.sql` | OK: resumen creado, top 5 devuelto |
| Auditoría de desincronización | 0 filas |
| Suma global fuente vs resumen | `t` (coincide) |
| `05b_prueba_sincronizacion_tp5.sql` | OK: los triggers mantienen el resumen |

El detalle de las consultas y los planes está en `TP6/informe_tp6.md` y en
`TP6/resultados/`.

## TP5 Unidad 5 - Seguridad

Se recreó `foodstore_u5` desde `TP2_Concurrencia/Script.sql` y se ejecutaron
`00_base_seguridad.sql`, `usuario_anon.sql`, `roles.sql`,
`verificar_permisos.sql` y `consultas_equivalencia.sql`.

| Control | Resultado |
|---|---|
| `usuario` | 6.000 filas, 5 roles, 5.648 activos |
| `usuario_anon` | 6.000 filas |
| Equivalencia por rol y por mes | 0 diferencias; 500 altas por mes en ambos lados |
| Permisos de tabla futura | `analista_lee=t`, `operador_inserta=t`, `operador_borra=f`, `admin_borra=f`, `public_lee=f`, `public_ejecuta_fn=f` |
| Roles | ningún rol de aplicación es superusuario ni puede crear roles |

## TP6 Unidad 6 - Respaldo y restauración

Se ejecutaron los scripts reales con la base canónica `copia_trabajo` en el
clúster temporal:

```text
backup_foodstore.ps1 -Database copia_trabajo -PgPort 55438
restore_test.ps1 -Database foodstore_restore_verify -PgPort 55438
```

| Control | Resultado |
|---|---|
| `pg_dump -Fc` | código 0 en 2,17 s; 10.760.210 bytes |
| Conteos restaurados | 20.000 / 50.000 / 200.000 / 399.997, todos OK |
| Integridad | 8/8 controles en 0 |
| RTO | 6,25 s |
| RPO | 0 h |
| Veredicto | `OK - restauración y validaciones completas` |

## TP7 - MongoDB

`TP7/consultas_mongodb.js` y `TP7/consultas_postgresql.sql.sql` se revisaron de
forma estática: el equipo no tiene `mongod`, `mongosh` ni `mongo` instalados,
por lo que no se pudo ejecutar la parte MongoDB. No se detectaron errores de
sintaxis; las consultas PostgreSQL equivalentes usan el esquema de TP5.

Recomendación para TP7 (no aplicada): crear un índice multikey
`db.pedidos.createIndex({ "lineas_pedido.producto_id": 1 })` para la consulta
(c), y verificar con `explain("executionStats")` cuando haya una instancia.

## TP8 - Resultado

| Control | Resultado |
|---|---|
| Snake de PostgreSQL a CSV | 16 productos exportados con `fecha_copia` |
| Importación SQLite | 16 filas en `snapshot_servidor`, 13 visibles (stock > 0 y no eliminados) |
| C1 | catálogo local, sin servidor |
| COMMIT | borrador completo con 2 items y 1 solicitud |
| ROLLBACK | 0 filas |
| C7a | `CHECK` de cantidad, 0 filas |
| C7b | `FOREIGN KEY`, 0 filas |
| C2 | `CONFLICTO` y luego `SIMULADO_APROBADO` |
| C3 | `RECHAZADO` por stock |
| C4 | `RECHAZADO` por baja; item conservado |
| C5 | `SIMULADO_APROBADO` |
| C6 | UUID duplicado rechazado |
| PostgreSQL final | 3 pedidos, 4 detalles, stock 295: `VERDE` |

Conclusión: los TP5, TP6 y las dos partes de la Unidad 5/6 siguen funcionando
en un entorno limpio. TP7 queda pendiente de una instancia MongoDB; TP8 se
ejecutó completo y no modificó pedidos ni stock del servidor.