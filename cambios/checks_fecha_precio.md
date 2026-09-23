# DUIA - CHECKs fecha no futura y precio_unitario positivo

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Necesito agregar una restricción CHECK en la tabla pedido para asegurar que la columna fecha no contenga fechas futuras (fecha <= now()), y una restricción CHECK en detalle_pedido para que precio_unitario sea estrictamente mayor a 0, todo esto sobre el archivo Script.sql. Siguiendo el protocolo_seguridad.md"

Prompts de seguimiento en el mismo flujo: "opcion A" y "Confirmado".

## Qué generó
# Plan: CHECKs en `Script.sql` (modo lectura, sin cambios aplicados)

## 1. Hallazgos (archivos inspeccionados)

**`Script.sql:46-55` – tabla `pedido` actual:**
```sql
fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
```
Sin CHECK sobre `fecha`.

**`Script.sql:61-72` – tabla `detalle_pedido` actual:**
```sql
cantidad INTEGER NOT NULL CHECK (cantidad > 0),
precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario >= 0),
```
Permite `0`, hay que endurecer a `> 0`. Comentario existente `-- CHECK 3:` quedará desactualizado.

**`protocolo_seguridad.md:1-5` exige, en orden:**
1. `Copia:` trabajar sobre BD aislada (`createdb -T plantilla_base copia_trabajo`).
2. `Respaldo:` `pg_dump copia_trabajo > backup.sql` antes del DDL.
3. `Transacción:` ejecutar envuelto en `BEGIN; ... ROLLBACK;` para inspeccionar, y solo luego `COMMIT`.
4. `Documentación:` documentar en `documentacion_cambios.pdf` (crearlo si no existe).

**`AGENTS.md` / `validaciones.py`:** aplican solo a validación Python de contraseñas, no bloquean este cambio SQL.

## 2. Plan propuesto de implementación

1. **Preparación (protocolo):**
   - Crear copia aislada: `createdb -T plantilla_base copia_trabajo`.
   - Respaldo: `pg_dump copia_trabajo > backup.sql`.

2. **Edición de `Script.sql`:**
   - **Opción A (recomendada, consistente con estilo actual del archivo – CHECKs inline sin nombre):**
     - `pedido.fecha`: `fecha TIMESTAMPTZ NOT NULL DEFAULT now() CHECK (fecha <= now()),`
     - `detalle_pedido.precio_unitario`: cambiar `CHECK (precio_unitario >= 0)` → `CHECK (precio_unitario > 0)` + actualizar comentario.
   - **Opción B (alternativa – constraints nombrados para mejor debugging):**
     - Mantener columnas y agregar después del `CREATE TABLE`:
     - `ALTER TABLE pedido ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= now());`
     - `ALTER TABLE detalle_pedido ADD CONSTRAINT chk_detalle_precio_positivo CHECK (precio_unitario > 0);` + eliminar CHECK inline viejo de `precio_unitario`.
   - No tocar validaciones preexistentes (`total >=0`, `cantidad >0`, `precio >=0`, `stock >=0`, FKs, índices).

3. **Verificación en copia con transacción:**
   ```sql
   BEGIN;
   -- re-ejecutar Script.sql completo (es re-ejecutable por los DROP ... CASCADE iniciales)
   -- casos borde esperados:
   -- RECHAZA: INSERT pedido con fecha = now() + interval '1 minute' / '1 day'
   -- ACEPTA: fecha = now(), fecha pasada
   -- RECHAZA: INSERT detalle_pedido con precio_unitario = 0 y < 0
   -- ACEPTA: precio_unitario = 0.01
   ROLLBACK; -- inspeccionar mensajes, luego repetir con COMMIT si todo ok
   ```

4. **Documentación:**
   - Crear/actualizar `documentacion_cambios.pdf` con: fecha, tablas afectadas, definición antes/después, justificación, resultado de pruebas.

## 3. Pregunta para decidir antes de ejecutar
¿Prefieres **Opción A (CHECK inline, mantiene estilo del archivo)** o **Opción B (CONSTRAINT nombrado `chk_*`, mejor trazabilidad de errores)**? Por defecto implementaría A salvo que me indiques lo contrario.

## Qué se aceptó
Opción A (CHECKs inline). Aplicado en el commit 804fcee "Update Script.sql": `pedido.fecha` con `CHECK (fecha <= now())` y `detalle_pedido.precio_unitario` con `CHECK (precio_unitario > 0)` más comentario `-- CHECK 4`.

## Qué se modificó o descartó y por qué
-

## Verificación realizada
Se ejecutó dentro de BEGIN...ROLLBACK. Se probó un INSERT con fecha actual (exitoso) y un INSERT con fecha en 2099 (falló con error de violación de CHECK).
