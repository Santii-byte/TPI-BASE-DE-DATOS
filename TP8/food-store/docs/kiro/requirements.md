# Requisitos - Sincronización Food Store / tablet de feria

Notación EARS. Cada requisito tiene un caso de prueba asociado.

## Contexto

La tablet de la parada 5 trabaja sin señal. El servidor PostgreSQL es la única
fuente de verdad para precio, stock, disponibilidad y ventas. La tablet solo
consulta una instantánea, arma borradores y propone solicitudes; nunca confirma
una venta ni modifica datos del servidor.

## REQ-01 - Precio distinto

**Cuando** el precio visto en el borrador es distinto del precio de la
instantánea del servidor,
**el sistema** debe marcar la solicitud como `CONFLICTO` y guardar un motivo
con el producto, el precio visto y el precio del servidor.

- Se prueba con: **C2**.
- Aceptación: la solicitud pasa de `PENDIENTE` a `CONFLICTO`; no se modifica
  ninguna fila de PostgreSQL.
- Evidencia: `docs/evidencias/casos_c2_c6.txt`, bloque C2.

## REQ-02 - Stock insuficiente

**Cuando** la cantidad pedida de un producto es mayor que el stock de la
instantánea,
**el sistema** debe marcar la solicitud como `RECHAZADO` con el motivo
`stock insuficiente`.

- Se prueba con: **C3**.
- Aceptación: 5 manzanas contra stock 4 -> `RECHAZADO`; el stock del servidor
  no cambia.
- Evidencia: `docs/evidencias/casos_c2_c6.txt`, bloque C3.

## REQ-03 - Producto inexistente, no disponible o dado de baja

**Cuando** un producto del borrador no existe en la instantánea, está marcado
`disponible = 0` o `eliminado = 1`,
**el sistema** debe marcar la solicitud como `RECHAZADO` y conservar el item
local para poder explicar el motivo.

- Se prueba con: **C4** (baja lógica) y **C7b** (producto inexistente).
- Aceptación: el catálogo disponible ya no muestra el producto, el item local
  sigue existiendo y la solicitud queda `RECHAZADO`.
- Evidencia: `docs/evidencias/casos_c2_c6.txt`, bloque C4;
  `docs/evidencias/04_pruebas_sqlite.txt`, C7b.

## REQ-04 - Idempotencia del reenvío

**Cuando** se reenvía una solicitud con el mismo `solicitud_uuid`,
**el sistema** debe rechazar el duplicado y no volver a evaluar la solicitud ya
resuelta.

- Se prueba con: **C6**.
- Aceptación: `UNIQUE constraint failed: cola_sync.solicitud_uuid`; la fila
  sigue siendo una sola y conserva su estado.
- Evidencia: `docs/evidencias/casos_c2_c6.txt`, bloque C6.
- Nota de defensa: en un sistema real la protección definitiva va en el
  servidor, con `pedido.id_local UNIQUE` y la confirmación de venta dentro de
  una transacción.

## Fuera de alcance

- Interfaz gráfica, app celular y programa Python de simulación.
- Escritura de ventas desde la tablet.
- Sincronización bidireccional automática.
- Datos personales reales.