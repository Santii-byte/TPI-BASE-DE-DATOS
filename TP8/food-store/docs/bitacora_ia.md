# Bitácora de uso de IA - TP8

Herramienta principal: **OpenCode** (modelo DeepSeek V4.1 Flash Free), con
psql 17 y SQLite 3.50 para verificar. Cada entrada registra el pedido, lo que
la IA generó, lo aceptado, lo descartado y la comprobación posterior.

---

## Entrada 1 - Diseño de las tablas de la tablet

**Prompt:** "Necesito cuatro tablas SQLite STRICT (producto_cache,
pedido_borrador, item_borrador, cola_sync) para una tablet sin señal. El
servidor PostgreSQL decide precio y stock; la tablet solo arma borradores.
Incluí PK, FK, checks y estados cerrados."

**Qué generó:** un primer DDL con `producto_cache`, `pedido_borrador`,
`item_borrador` y `cola_sync`, más una tabla `snapshot_servidor`. Usaba
`REAL` para el precio y no tenía staging para el CSV.

**Qué acepté:** la estructura general, las PK/FK, los checks de cantidad > 0 y
la PK UUID de `cola_sync`.

**Qué descarté y por qué:** descarté `REAL` para dinero porque introduce
redondeo; lo reemplacé por `precio_centavos` entero. Agregué `snapshot_raw` de
texto porque PostgreSQL exporta `t/f` y una tabla STRICT rechaza ese texto.

**Verificación:** `PRAGMA table_list` mostró 6 tablas; las pruebas C7a y C7b
fallaron con `CHECK constraint failed` y `FOREIGN KEY constraint failed` sin
dejar filas. Evidencia: `docs/evidencias/04_pruebas_sqlite.txt`.

---

## Entrada 2 - Semáforo de sincronización

**Prompt:** "Escribí un UPDATE en SQLite que compare las solicitudes PENDIENTE
contra snapshot_servidor. Rojo si el producto no existe, está dado de baja, no
está disponible o no alcanza el stock; amarillo si solo cambió el precio; verde
si todo coincide. El motivo debe decir qué producto falló. No modifiques
PostgreSQL y no re-evalúes solicitudes ya resueltas."

**Qué generó:** un `UPDATE ... FROM` con CTE y `group_concat`. La primera
versión marcaba `sin stock` y `stock insuficiente` a la vez para stock 0.

**Qué acepté:** la precedencia rojo > amarillo > verde, el `WHERE estado =
'PENDIENTE'` y el motivo con `group_concat`.

**Qué descarté y por qué:** descarté la duplicación del motivo. Agregué
`stock_servidor > 0` a la condición de stock insuficiente para que un producto
agotado solo diga "sin stock". También descarté usar un trigger: el semáforo
debe ser una corrida explícita y auditable, no un efecto oculto.

**Verificación:** producto 13 (stock 0) quedó `RECHAZADO` con motivo
`sin stock: id 13 sin stock`; producto 11 (10 pedidas, stock 8) quedó
`RECHAZADO` con `stock insuficiente`. Evidencia:
`docs/evidencias/03_carga_y_semaforo_inicial.txt`.

---

## Entrada 3 - Instantánea y booleanos del CSV

**Prompt:** "¿Cómo paso la vista v_snapshot_movil de PostgreSQL a SQLite sin
perder la fecha de copia y sin romper los tipos? Los booleanos de psql salen
como t/f."

**Qué generó:** un `\copy` directo a `snapshot_servidor` y un `UPDATE` para
convertir `t/f` después de importar.

**Qué acepté:** la vista con `fecha_copia` calculada con `to_char` y el
`\copy` a CSV con encabezado.

**Qué descarté y por qué:** descarté el `UPDATE` sobre una tabla STRICT: el
`.import` falla antes de poder convertir `t/f`. Lo reemplacé por
`snapshot_raw` (todo TEXT) y `importar_snapshot.sql`, que convierte a `1/0` y
recién después inserta en `snapshot_servidor`.

**Verificación:** `filas_servidor = 16`, `filas_cache = 16`,
`catalogo_visible = 13`, y la fecha del CSV coincide con la del servidor.
Evidencia: `docs/evidencias/02_export_snapshot.txt`.

---

## Entrada 4 - Caso C2 (precio cambiado y aceptación)

**Prompt:** "Simulá C2: el servidor sube el precio de la leche, el borrador
tiene el precio viejo. Mostrá CONFLICTO y después, cuando el cliente acepta,
una solicitud nueva que dé SIMULADO_APROBADO. No reutilices el UUID."

**Qué generó:** un único UPDATE de precio y un INSERT de una solicitud nueva
con el mismo UUID de la anterior.

**Qué acepté:** el cambio de precio en PostgreSQL y la idea de crear una
solicitud nueva tras la aceptación.

**Qué descarté y por qué:** descarté reutilizar el UUID; la PK lo impide y,
además, ocultaría el historial de la primera solicitud. Usé UUID distintos
para la solicitud en conflicto y para la aceptada.

**Verificación:** la solicitud `...0011` quedó `CONFLICTO` con motivo
`id 2: visto 95000, servidor 105000`; la `...0012` quedó
`SIMULADO_APROBADO`. Evidencia: `docs/evidencias/casos_c2_c6.txt`.

---

## Entrada 5 - Caso C4 (baja lógica)

**Prompt:** "En C4 el producto se da de baja después del borrador. Quiero que
el semáforo lo rechace, que el catálogo ya no lo muestre, pero que la fila del
item siga existiendo. ¿Borro el producto de producto_cache?"

**Qué generó:** un `DELETE FROM producto_cache` cuando el producto no aparece
en la instantánea nueva.

**Qué acepté:** marcar `eliminado = 1` en el servidor y filtrar el catálogo
con `eliminado = 0`.

**Qué descarté y por qué:** descarté el DELETE. Rompe la FK de `item_borrador`
y borra la evidencia que el vendedor necesita para explicar el rechazo. La
instantánea incluye las bajas lógicas y la tablet conserva la fila.

**Verificación:** `item local conservado = 1`, `catalogo disponible = 0`,
`cache conserva la baja = 1`, y la solicitud `...0014` quedó `RECHAZADO` con
`producto dado de baja: id 6`. Evidencia: `docs/evidencias/casos_c2_c6.txt`.

---

## Entrada 6 - Code review de la cursada (OpenCode, modo Plan)

**Prompt:** "Revisá todos los scripts de TP1 a TP8 como si fueras un revisor.
Buscá problemas de integridad, tipos, respaldo y mantenimiento. Para cada
hallazgo indicá archivo, decisión (aceptado, corregido o descartado), motivo y
cómo comprobarlo en la base. Al menos uno tiene que quedar descartado con
fundamento."

**Qué generó:** una lista de hallazgos sobre `precio >= 0` en TP5, el `CHECK`
con `now()`, el password placeholder de TP5, la validación solo por conteos de
TP6, el trigger de resumen de TP6, la falta de índice en TP7 y la duplicación
de motivos en el semáforo de TP8.

**Qué acepté:** los hallazgos de TP5, TP6 y TP7; el de TP8 se corrigió.

**Qué descarté y por qué:** descarté cambiar el trigger de resumen de TP6 para
que no lance excepción cuando falta una celda. Esa excepción es una alarma
deliberada de inconsistencia; silenciarla ocultaría una desincronización que la
auditoría debe detectar. También descarté normalizar `lineas_pedido` en
MongoDB: el documento es una foto de la venta y el precio copiado debe
conservarse aunque el catálogo cambie.

**Verificación:** la auditoría de TP6 devolvió 0 filas y
`suma_global_coincide = t`; el semáforo de TP8 quedó sin motivos duplicados.
El detalle está en `docs/informe.pdf`, sección 3.c.

---

## Entrada 7 - Redacción del informe y defensa

**Prompt:** "Armá un informe de 6 páginas máximo con 1.a, 2.c, 3.a, 3.b y 3.c.
Incluí una tabla de casos C2-C6, el mapa de los tres motores y una tabla de
hallazgos con al menos un descartado. Agregá un guion de defensa de 10
minutos."

**Qué generó:** un borrador extenso, con explicaciones repetidas y sin la
columna "cómo lo comprobé".

**Qué acepté:** la estructura y las tablas; el guion de defensa.

**Qué descarté y por qué:** descarté el texto que afirmaba que la tablet
"actualiza stock" y la frase "venta aprobada". Va contra la regla de oro: la
tablet no cambia stock y `SIMULADO_APROBADO` no es una venta. También recorté
el informe para que no supere las 6 páginas.

**Verificación:** el PDF tiene 6 páginas y todas las afirmaciones se
corresponden con las evidencias de `docs/evidencias/`.