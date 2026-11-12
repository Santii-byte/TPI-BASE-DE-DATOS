# Casos C2 a C6 - comandos, resultados y explicación

Todos los casos se ejecutaron sobre una copia de la base con datos inventados.
La traza cruda está en `docs/evidencias/casos_c2_c6.txt`.

## Resumen

| Caso | Qué se preparó | Resultado | Explicación |
|---|---|---|---|
| C2 | Borrador con leche a 95000; el servidor la sube a 105000 | `CONFLICTO`; luego de aceptar el precio, nueva solicitud `SIMULADO_APROBADO` | El semáforo detecta que el precio visto no coincide. No se cambia nada en PostgreSQL; el cliente acepta y se crea una solicitud nueva con el precio actualizado. |
| C3 | Borrador con 5 manzanas; hay 4 | `RECHAZADO` | La cantidad pedida supera el stock de la instantánea. El motivo indica `id 12: pedidas 5, stock 4`. |
| C4 | Yerba mate vigente; después el servidor la marca `eliminado = 1` | `RECHAZADO`; el item local queda | El catálogo deja de mostrar el producto, pero el item no se borra: se conserva para explicar el rechazo. |
| C5 | Borrador sin cambios | `SIMULADO_APROBADO` | Precio, stock y disponibilidad coinciden. No se crea ningún pedido. |
| C6 | Reenviar la misma solicitud (mismo UUID) | Duplicado rechazado; la solicitud sigue una sola | La PK de `cola_sync` protege la idempotencia en la tablet. El semáforo no re-evalúa porque ya no está `PENDIENTE`. |

## C2 - Precio cambiado

Comandos (desde `food-store/`):

```powershell
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/casos/c2_subir_precio.sql
psql -h localhost -p 5432 -U postgres -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/exportar_snapshot.sql
```

En SQLite: importar `movil/servidor_snapshot.csv`, ejecutar
`movil/casos/c2_solicitud_conflicto.sql` y `movil/semaforo.sql`.

Resultado real:

```text
aaaaaaaa-aaaa-4aaa-8aaa-000000000011 | 88888888-8888-4888-8888-888888888888 | CONFLICTO | precio cambiado: id 2: visto 95000, servidor 105000;
```

Luego:

```text
.read movil/casos/c2_aceptar_precio.sql
.read movil/semaforo.sql
```

Resultado:

```text
aaaaaaaa-aaaa-4aaa-8aaa-000000000012 | 88888888-8888-4888-8888-888888888888 | SIMULADO_APROBADO | precio, stock y disponibilidad coinciden
```

El precio del servidor se restaura al final con
`postgres/casos/c2_restaurar_precio.sql`.

## C3 - Stock insuficiente

No hay cambio en PostgreSQL. Se exporta una instantánea nueva y se ejecuta
`movil/casos/c3_solicitud_stock.sql` + `movil/semaforo.sql`.

```text
aaaaaaaa-aaaa-4aaa-8aaa-000000000013 | 77777777-7777-4777-8777-777777777777 | RECHAZADO | stock insuficiente: id 12: pedidas 5, stock 4;
```

## C4 - Baja lógica

```powershell
psql ... -f postgres/casos/c4_baja_producto.sql
psql ... -f postgres/exportar_snapshot.sql
```

Después de importar la nueva instantánea:

```text
item local conservado            | 1
catalogo disponible              | 0
cache conserva la baja           | 1
snapshot conserva la baja        | 1
```

Y el semáforo:

```text
aaaaaaaa-aaaa-4aaa-8aaa-000000000014 | 99999999-9999-4999-8999-999999999999 | RECHAZADO | producto dado de baja: id 6 dado de baja;
```

El producto se restaura con `postgres/casos/c4_restaurar_producto.sql`.

## C5 - Sin cambios

Se exporta una instantánea nueva, se importa y se ejecuta
`movil/casos/c5_solicitud_sin_cambios.sql` + `movil/semaforo.sql`.

```text
aaaaaaaa-aaaa-4aaa-8aaa-000000000015 | bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb | SIMULADO_APROBADO | precio, stock y disponibilidad coinciden
```

## C6 - Reenvío del mismo UUID

```text
.read movil/casos/c6_reenvio.sql
.read movil/semaforo.sql
```

Resultado:

```text
ERROR ESPERADO: UNIQUE constraint failed: cola_sync.solicitud_uuid
C6 reenvio | filas = 1 | estado = SIMULADO_APROBADO
```

El semáforo no cambia la fila porque ya no está `PENDIENTE`.

**¿Dónde iría la protección real?** En el servidor, en la parada 8: una clave
única `pedido.id_local` (o una tabla `solicitud_sync` con UUID único) y la
confirmación de la venta dentro de una transacción que descuente stock con
`UPDATE ... WHERE stock >= cantidad`. La tablet no confirma ventas.

## Verificación final en PostgreSQL

```powershell
psql ... -f postgres/05_verificacion.sql
```

```text
pedidos_base | pedidos | detalles_base | detalles | stock_base | stock | veredicto
3            | 3       | 4             | 4        | 295        | 295   | VERDE: pedidos y stock sin cambios
```

Esto demuestra que la simulación no creó pedidos, no descontó stock y no
modificó precios de pedidos ya confirmados.