# DUIA - Ranking con DENSE_RANK dos versiones

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Actúa como DBA en PostgreSQL. En base al modelo de datos Food Store (cliente, pedido, detalle_pedido, producto), genera una consulta SQL a partir de la siguiente especificación estricta: Tablas involucradas: cliente y pedido. Condiciones de filtrado: Solo clientes activos (cliente.activo = true) que posean pedidos confirmados (pedido.estado IN ('pagado', 'enviado')). Columnas de salida: id_cliente, nombre_cliente, total_gastado (suma de pedido.total) y ranking_gasto. Criterio analítico: Utilizar la función de ventana DENSE_RANK() para calcular la posición de mayor a menor gasto total. En caso de empate en el total gastado, desempatar por id_cliente ascendente dentro del ORDER BY de la ventana. Restricciones: No usar SELECT *. Adicionalmente, genera una segunda versión estructuralmente distinta (por ejemplo, una que calcule el ranking sobre una CTE agrupada y otra que use una subconsulta en la cláusula FROM / tabla derivada), garantizando que ambas devuelvan exactamente el mismo resultado para contrastarlas con EXCEPT"

## Qué generó
**Versión A – ranking sobre CTE agrupada:**

```sql
WITH gasto AS (
    SELECT c.id AS id_cliente,
           c.nombre AS nombre_cliente,
           SUM(p.total) AS total_gastado
    FROM cliente AS c
    JOIN pedido AS p ON p.cliente_id = c.id
    WHERE c.activo = TRUE
      AND p.estado IN ('pagado', 'enviado')
    GROUP BY c.id, c.nombre
)
SELECT id_cliente,
       nombre_cliente,
       total_gastado,
       DENSE_RANK() OVER (ORDER BY total_gastado DESC, id_cliente ASC) AS ranking_gasto
FROM gasto
ORDER BY ranking_gasto ASC, id_cliente ASC;
```

**Versión B – ranking sobre tabla derivada en el FROM:**

```sql
SELECT g.id_cliente,
       g.nombre_cliente,
       g.total_gastado,
       DENSE_RANK() OVER (ORDER BY g.total_gastado DESC, g.id_cliente ASC) AS ranking_gasto
FROM (
    SELECT c.id AS id_cliente,
           c.nombre AS nombre_cliente,
           SUM(p.total) AS total_gastado
    FROM cliente AS c
    JOIN pedido AS p ON p.cliente_id = c.id
    WHERE c.activo = TRUE
      AND p.estado IN ('pagado', 'enviado')
    GROUP BY c.id, c.nombre
) AS g
ORDER BY ranking_gasto ASC, id_cliente ASC;
```

Notas: el `INNER JOIN` deja afuera a los activos sin pedidos confirmados (coincide con "que posean pedidos confirmados"); el desempate por `id_cliente` dentro de la ventana hace el ranking totalmente determinístico. Para contrastarlas: `(versión_A EXCEPT versión_B) UNION ALL (versión_B EXCEPT versión_A)` debe devolver 0 filas (ojo: `EXCEPT` compara con igualdad de tipos; ambas devuelven los mismos tipos porque comparten la agregación). Sin `SELECT *` en ninguna. Documentado en `TP3/DUIA_Parte12.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Consultas entregadas en el chat, más este DUIA en `TP3/DUIA_Parte12.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
