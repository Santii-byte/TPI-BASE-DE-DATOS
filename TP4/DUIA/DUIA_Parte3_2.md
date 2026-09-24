# DUIA - Pedidos sobre el promedio del propio cliente

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Actúa como DBA en PostgreSQL. En base al esquema Food Store (cliente, pedido), resuelve el siguiente requerimiento analítico bajo dos estructuras sintácticas distintas: Requerimiento: Identificar los pedidos pagados o enviados cuyo monto total supere el promedio del gasto de los pedidos realizados por ese mismo cliente en el último año. Tablas involucradas: cliente y pedido. Condiciones de filtrado: Clientes activos (cliente.activo = true), pedidos con estado IN ('pagado', 'enviado') y fecha >= now() - INTERVAL '365 days'. Columnas de salida: id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido. Ordenamiento: id_cliente ASC, monto_pedido DESC. Restricción: No usar SELECT *. Genera: Versión 1: Resuelta utilizando una subconsulta correlacionada en la cláusula WHERE. Versión 2: Resuelta utilizando un JOIN con tabla derivada o CTE agregada. La consulta de verificación con EXCEPT en ambos sentidos."

## Qué generó
Decisión de lectura (ajustable): el promedio por cliente se calcula sobre TODOS sus pedidos del último año (la especificación no le pone filtro de estado al promedio; el filtro `pagado/enviado` aplica solo a los pedidos candidatos). Ambas versiones usan el mismo criterio, así que son comparables.

**Versión 1 – subconsulta correlacionada en el WHERE:**

```sql
SELECT c.id AS id_cliente,
       c.nombre AS nombre_cliente,
       p.id AS id_pedido,
       p.fecha AS fecha_pedido,
       p.total AS monto_pedido
FROM cliente AS c
JOIN pedido AS p ON p.cliente_id = c.id
WHERE c.activo = TRUE
  AND p.estado IN ('pagado', 'enviado')
  AND p.fecha >= now() - INTERVAL '365 days'
  AND p.total > (SELECT AVG(p2.total)
                 FROM pedido AS p2
                 WHERE p2.cliente_id = c.id
                   AND p2.fecha >= now() - INTERVAL '365 days')
ORDER BY id_cliente ASC, monto_pedido DESC;
```

**Versión 2 – JOIN con CTE agregada:**

```sql
WITH promedio_cliente AS (
    SELECT cliente_id, AVG(total) AS promedio
    FROM pedido
    WHERE fecha >= now() - INTERVAL '365 days'
    GROUP BY cliente_id
)
SELECT c.id AS id_cliente,
       c.nombre AS nombre_cliente,
       p.id AS id_pedido,
       p.fecha AS fecha_pedido,
       p.total AS monto_pedido
FROM cliente AS c
JOIN pedido AS p ON p.cliente_id = c.id
JOIN promedio_cliente AS pc ON pc.cliente_id = c.id
WHERE c.activo = TRUE
  AND p.estado IN ('pagado', 'enviado')
  AND p.fecha >= now() - INTERVAL '365 days'
  AND p.total > pc.promedio
ORDER BY id_cliente ASC, monto_pedido DESC;
```

**Verificación con EXCEPT en ambos sentidos (debe devolver 0 filas):**

```sql
WITH v1 AS (
    [bloque SELECT de la Versión 1 sin el ORDER BY final]
),
v2 AS (
    [bloque SELECT de la Versión 2 sin el ORDER BY final]
)
(SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v1
 EXCEPT
 SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v2)
UNION ALL
(SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v2
 EXCEPT
 SELECT id_cliente, nombre_cliente, id_pedido, fecha_pedido, monto_pedido FROM v1);
```

Notas: el `ORDER BY` final se quita dentro de `v1`/`v2` porque no se permite en ramas de `EXCEPT` (solo al final del todo); el `INNER JOIN` con la CTE descarta clientes sin pedidos en el año, igual que la correlacionada descarta cuando el promedio es `NULL`. Sin `SELECT *` en ninguna. Documentado en `TP3/DUIA_Parte13.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Consultas entregadas en el chat, más este DUIA en `TP3/DUIA_Parte13.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
En la Versión 1: La subconsulta calcula AVG(p2.total) promediando todos los pedidos del cliente en el último año, sin importar si están cancelados o pendientes (no tiene filtro de estado en la subconsulta).  
En la Versión 2: En la CTE promedio_cliente tampoco filtró por estado. Sin embargo, si en el negocio el promedio debía ser solo sobre pedidos válidos (pagado, enviado), ambas consultas promedian pedidos cancelados. El error de consistencia: En la Versión 1 y Versión 2, la IA promedia sobre pedidos de cualquier estado, pero en el WHERE externo solo evalúa pedidos pagados/enviados

## Verificación realizada
-
