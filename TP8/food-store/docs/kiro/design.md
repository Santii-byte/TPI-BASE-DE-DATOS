# Diseño - TP8

## 1. Arquitectura

```text
PostgreSQL 17 (servidor, fuente de verdad)
  producto / pedido / detalle_pedido
        |
        |  v_snapshot_movil  ->  COPY ... TO CSV  (fecha_copia)
        v
CSV  servidor_snapshot.csv
        |
        |  importación manual / staging snapshot_raw
        v
SQLite 3 (tablet, parada 5)
  producto_cache  <-- copia de trabajo
  snapshot_servidor <-- instantánea inmutable de la corrida
  pedido_borrador / item_borrador  <-- borrador local
  cola_sync  <-- solicitudes y resultado del semáforo
```

La tablet **no** tiene conexión con PostgreSQL. El único canal es el archivo
CSV que se copia en el momento en que hay señal.

## 2. Modelo de datos

### 2.1 Servidor

- `producto.id`: id estable que comparten todos los sistemas.
- `precio_centavos`: entero, sin decimales flotantes.
- `stock`: entero no negativo.
- `disponible`: booleano comercial.
- `eliminado`: baja lógica; nunca se borra físicamente un producto con
  historial.
- `fecha_copia`: se calcula en la vista con `to_char(now(), ...)`.

`pedido.id_local UUID UNIQUE` es la clave de idempotencia real del servidor.
`detalle_pedido` copia el precio al momento de la venta.

### 2.2 Tablet

| Tabla | Rol | Restricciones |
|---|---|---|
| `producto_cache` | catálogo local para armar borradores | PK, checks de precio/stock/booleanos, `STRICT` |
| `pedido_borrador` | cabecera local | PK UUID, forma de pago cerrada, `STRICT` |
| `item_borrador` | líneas del borrador | FK a borrador y a caché, cantidad > 0, `STRICT` |
| `cola_sync` | solicitudes y estado | PK UUID (idempotencia), estados cerrados, `STRICT` |
| `snapshot_servidor` | instantánea de la corrida | sin escritura desde la UI, `STRICT` |
| `snapshot_raw` | staging del CSV | todo TEXT para aceptar `t/f` |

## 3. Flujo de sincronización

1. En PostgreSQL se ejecuta `v_snapshot_movil` y se exporta con `\copy` a CSV.
2. El CSV se importa en `snapshot_raw`.
3. `importar_snapshot.sql` normaliza `t/f` a `1/0`, reemplaza
   `snapshot_servidor` y actualiza `producto_cache` con upsert.
4. La tablet arma `pedido_borrador` + `item_borrador` y encola una solicitud
   `PENDIENTE` con un UUID nuevo.
5. `semaforo.sql` evalúa **solo** las solicitudes `PENDIENTE`:
   - rojo -> `RECHAZADO`;
   - amarillo -> `CONFLICTO`;
   - verde -> `SIMULADO_APROBADO`.
6. El resultado se muestra al cliente. Si acepta un precio nuevo, se actualiza
   el borrador y se crea **otra** solicitud (nuevo UUID); no se reutiliza la
   anterior.

## 4. Precedencia del semáforo

1. `RECHAZADO`: producto inexistente, dado de baja, no disponible, stock 0 o
   cantidad mayor al stock.
2. `CONFLICTO`: no hay problema rojo y al menos un precio difiere.
3. `SIMULADO_APROBADO`: todo coincide.

El motivo se construye con `group_concat` por tipo de problema para que el
vendedor vea qué producto y qué valores causaron el resultado.

## 5. Idempotencia

- En la tablet: `cola_sync.solicitud_uuid` es PK. Reenviar el mismo UUID falla.
- En el servidor real: `pedido.id_local` es `UNIQUE` y la venta se confirma en
  una transacción que descuenta stock con `UPDATE ... WHERE stock >= cantidad`.
- Un `SIMULADO_APROBADO` **no** crea pedido. La confirmación real es un paso
  posterior, fuera del alcance del TP.

## 6. Decisiones descartadas

- **Borrar items cuando el producto se da de baja**: descartado. El item debe
  quedar para explicar el `RECHAZADO` y para conservar el borrador del cliente.
- **Guardar precios como `REAL`**: descartado por redondeo; se usan centavos
  enteros.
- **Sincronizar solo deltas**: descartado para la feria. Un CSV completo es más
  simple de reemplazar y de auditar con poca señal.
- **Que la tablet confirme ventas**: prohibido por la regla de oro. El servidor
  dispone.

## 7. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Instantánea vieja | `fecha_copia` visible y comparación al importar |
| CSV con `t/f` | staging TEXT y normalización explícita |
| Reenvío de solicitud | PK UUID en tablet + UNIQUE en servidor |
| Baja lógica | `eliminado = 1`; el catálogo filtra, el item no se borra |
| Restauración vieja de PostgreSQL | no subir borradores automáticamente; refrescar instantánea y revisar conflictos |