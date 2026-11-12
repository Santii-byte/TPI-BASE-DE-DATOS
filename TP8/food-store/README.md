# Food Store - TP Unidad 8: la base de la tablet

Trabajo práctico de **sincronización servidor -> tablet** para la feria sin señal.
La tablet arma el borrador y propone; PostgreSQL decide precio, stock y venta.
La simulación es local: `SIMULADO_APROBADO` **no es una venta**.

- **Integrantes:** Franco Rios y Santino Barone
- **Motor servidor:** PostgreSQL 17
- **Motor tablet:** SQLite 3.50 (STRICT)
- **Herramientas:** OpenCode, psql, Python 3 (solo como ejecutor de los `.sql`),
  DB Browser for SQLite / `sqlite3`.
- **Base de partida:** copia de laboratorio con datos inventados, inspirada en
  el esquema Food Store de TP2-TP7. **No se usan datos reales.**

---

## 1. Reglas que respeta el trabajo

1. Se trabaja sobre una copia de la base, con datos inventados.
2. No hay contraseñas, mails ni datos personales reales en la tablet.
3. La tablet **nunca** cambia stock ni precio del servidor, y **no confirma
   ventas**. `SIMULADO_APROBADO` solo significa "el borrador coincide con la
   instantánea".
4. Todo lo generado con IA fue leído y probado antes de ejecutarlo; lo que no
   se puede explicar no se entrega.

---

## 2. Estructura

```text
food-store/
├─ README.md
├─ movil/
│  ├─ schema_sqlite.sql          consigna 1.b
│  ├─ pruebas_sqlite.sql         consigna 1.c
│  ├─ importar_snapshot.sql      normaliza t/f y carga el catálogo
│  ├─ datos_prueba.sql           borradores inventados
│  ├─ semaforo.sql               consigna 2.b
│  ├─ servidor_snapshot.csv      consigna 2.a
│  ├─ foodstore_movil.db         base SQLite lista para abrir
│  └─ casos/
│     ├─ c2_solicitud_conflicto.sql
│     ├─ c2_aceptar_precio.sql
│     ├─ c3_solicitud_stock.sql
│     ├─ c4_solicitud_baja.sql
│     ├─ c5_solicitud_sin_cambios.sql
│     └─ c6_reenvio.sql
├─ postgres/
│  ├─ 01_esquema.sql
│  ├─ 02_datos.sql
│  ├─ exportar_snapshot.sql
│  ├─ 05_verificacion.sql
│  └─ casos/
│     ├─ c2_subir_precio.sql
│     ├─ c2_restaurar_precio.sql
│     ├─ c4_baja_producto.sql
│     └─ c4_restaurar_producto.sql
└─ docs/
   ├─ informe.pdf (fuente: informe.html)
   ├─ kiro/requirements.md, design.md, tasks.md
   ├─ bitacora_ia.md
   ├─ DUIA.md
   ├─ casos_c2_c6.md
   ├─ verificacion_tps_anteriores.md
   └─ evidencias/
```

Los scripts auxiliares de este repositorio están en `TP8/tools/` y no son
necesarios para corregir: solo generan la evidencia en un equipo sin `sqlite3`.

---

## 3. Crear todo desde cero

### 3.1 Servidor PostgreSQL

Desde la carpeta `food-store/`:

```powershell
createdb -h localhost -p 5432 -U postgres foodstore_u8
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/01_esquema.sql
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/02_datos.sql
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/exportar_snapshot.sql
```

`exportar_snapshot.sql` escribe `movil/servidor_snapshot.csv` con las columnas
mínimas `id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia`
(más `categoria`, dato útil para el catálogo de la tablet). La fecha de la copia
queda en `fecha_copia`, en formato ISO.

> Los booleanos de PostgreSQL salen como `t`/`f`. Por eso el CSV se importa a
> `snapshot_raw` (todo TEXT) y `importar_snapshot.sql` los convierte a `1`/`0`
> antes de poblar `snapshot_servidor` y `producto_cache`.

### 3.2 Tablet SQLite

Opción `sqlite3` (recomendada):

```text
sqlite3 movil/foodstore_movil.db
.read movil/schema_sqlite.sql
.mode csv
.import --csv --skip 1 movil/servidor_snapshot.csv snapshot_raw
.read movil/importar_snapshot.sql
.read movil/datos_prueba.sql
.read movil/semaforo.sql
.read movil/pruebas_sqlite.sql
.read movil/semaforo.sql
```

Opción DB Browser for SQLite:

1. Abrir/crear `movil/foodstore_movil.db`.
2. Pestaña **Execute SQL**: abrir y ejecutar `movil/schema_sqlite.sql`.
3. **File > Import > Table from CSV**: elegir `movil/servidor_snapshot.csv`,
   tabla destino `snapshot_raw`, marcar "Column names in first line".
4. Ejecutar `movil/importar_snapshot.sql`, `movil/datos_prueba.sql`,
   `movil/semaforo.sql`, `movil/pruebas_sqlite.sql` y otra vez
   `movil/semaforo.sql`.

`movil/foodstore_movil.db` ya viene generado y con los resultados de la
simulación inicial. Se puede abrir directamente en DB Browser.

### 3.3 Ejecutar solo las pruebas

```powershell
sqlite3 movil/foodstore_movil.db ".read movil/pruebas_sqlite.sql"
```

Las pruebas muestran:

- C1: consulta del catálogo disponible sin servidor (`PRAGMA database_list`
  solo lista `main`).
- Un borrador completo con `BEGIN ... COMMIT`.
- Un borrador descartado con `ROLLBACK` (0 filas).
- C7a: `cantidad = 0` falla por `CHECK` y no deja filas.
- C7b: producto inexistente falla por `FOREIGN KEY` y no deja filas.

---

## 4. Casos C2 a C6

Cada caso se ejecuta en este orden: cambio en PostgreSQL (si corresponde),
exportación de una instantánea nueva, importación en SQLite y semáforo.
La evidencia completa está en `docs/evidencias/casos_c2_c6.txt` y el resumen
explicado en `docs/casos_c2_c6.md`.

### C2 - precio cambiado

```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/casos/c2_subir_precio.sql
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/exportar_snapshot.sql
```

En SQLite: importar el CSV, ejecutar `movil/casos/c2_solicitud_conflicto.sql`
y `movil/semaforo.sql` -> `CONFLICTO`.
Luego `movil/casos/c2_aceptar_precio.sql` + `movil/semaforo.sql` -> nueva
solicitud `SIMULADO_APROBADO`.
Al final, restaurar el precio con `postgres/casos/c2_restaurar_precio.sql`.

### C3 - más unidades que stock

No hay cambio en el servidor. Se exporta una instantánea nueva y se ejecuta
`movil/casos/c3_solicitud_stock.sql` + `movil/semaforo.sql` -> `RECHAZADO`.

### C4 - baja lógica

```powershell
psql ... -f postgres/casos/c4_baja_producto.sql
psql ... -f postgres/exportar_snapshot.sql
```

Importar, ejecutar `movil/casos/c4_solicitud_baja.sql` + `movil/semaforo.sql`
-> `RECHAZADO`. El item local sigue existiendo; el catálogo disponible ya no
muestra el producto. Restaurar con `postgres/casos/c4_restaurar_producto.sql`.

### C5 - sin cambios

Exportar, importar, ejecutar `movil/casos/c5_solicitud_sin_cambios.sql` +
`movil/semaforo.sql` -> `SIMULADO_APROBADO`.

### C6 - reenvío del mismo UUID

Ejecutar `movil/casos/c6_reenvio.sql`: la PK de `cola_sync` rechaza el
duplicado (`UNIQUE constraint failed`) y el semáforo no vuelve a evaluar la
solicitud porque ya no está `PENDIENTE`.

### Verificación final en PostgreSQL

```powershell
psql ... -f postgres/05_verificacion.sql
```

Debe devolver `VERDE: pedidos y stock sin cambios` (3 pedidos, 4 detalles,
stock total 295). La tablet no confirmó ninguna venta.

---

## 5. Verificación rápida

```sql
-- Catálogo disponible en la tablet
SELECT id, nombre, precio_centavos, stock
  FROM producto_cache
 WHERE disponible = 1 AND eliminado = 0 AND stock > 0
 ORDER BY nombre;

-- Estado de la cola
SELECT solicitud_uuid, id_local, estado, motivo
  FROM cola_sync
 ORDER BY id_local;

-- No hay ventas creadas por la tablet
SELECT count(*) FROM pedido;                 -- 3, solo los del servidor
SELECT sum(stock) FROM producto WHERE tienda_id = 5;  -- 295
```

---

## 6. Decisiones de diseño

- **Dinero en centavos enteros**: evita `REAL` y redondeos; el mismo entero
  viaja de PostgreSQL a SQLite.
- **Snapshot completo, no incremental**: la feria no tiene señal; un CSV
  pequeño es fácil de reemplazar y auditar.
- **`fecha_copia` explícita**: permite detectar una instantánea vieja.
- **Staging de texto para el CSV**: PostgreSQL exporta `t/f`; la conversión a
  `1/0` se hace una sola vez y queda documentada.
- **PK de `cola_sync` = UUID de solicitud**: idempotencia en la tablet. En un
  sistema real, el servidor debe tener además una clave única de idempotencia
  (`pedido.id_local`) y confirmar la venta dentro de una transacción.
- **La tablet no borra items cuando un producto se da de baja**: el item queda
  para poder explicar el `RECHAZADO`; la baja se representa con `eliminado = 1`.
- **STRICT en las cuatro tablas operativas**: SQLite rechaza tipos inválidos.

---

## 7. Evidencia generada

| Archivo | Contenido |
|---|---|
| `docs/evidencias/01_esquema_y_datos.txt` | tablas, vista y conteos del servidor |
| `docs/evidencias/02_export_snapshot.txt` | exportación `\copy` y primeras filas del CSV |
| `docs/evidencias/03_carga_y_semaforo_inicial.txt` | importación y primeros resultados |
| `docs/evidencias/04_pruebas_sqlite.txt` | C1, COMMIT, ROLLBACK, C7a y C7b |
| `docs/evidencias/05_verificacion_postgres.txt` | pedidos y stock sin cambios |
| `docs/evidencias/casos_c2_c6.txt` | traza completa de los cinco casos |

En este equipo se usó `TP8/tools/sqlite_runner.py` porque no está instalado el
binario `sqlite3`; el archivo `.db` es el mismo que abre DB Browser y los
scripts son SQLite estándar.

---

## 8. TP anteriores

La verificación de TP5, TP6 y TP7 está en
`docs/verificacion_tps_anteriores.md`. TP5 y TP6 se ejecutaron en un clúster
PostgreSQL 17 temporal y limpio; TP7 son consultas MongoDB y se revisaron de
forma estática porque el equipo no tiene `mongosh` instalado.

---

## 9. Defensa (10 minutos)

1. Mostrar el CSV y la tabla `producto_cache` (C1).
2. Abrir `foodstore_movil.db` en DB Browser y correr `semaforo.sql` (C5).
3. Cambiar un precio en PostgreSQL, exportar e importar: mostrar `CONFLICTO`
   (C2) y explicar que no se modificó nada en el servidor.
4. Mostrar `05_verificacion.sql`: 3 pedidos y stock 295.
5. Cerrar con el hallazgo descartado del code review y por qué.