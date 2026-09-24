# DUIA - Clientes activos con gasto en pagados

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Generá una consulta SQL sobre el esquema de Food Store que liste a todos los clientes activos (activo = TRUE). Para cada uno, debe devolver su id, su nombre y el total acumulado gastado en pedidos con estado 'pagado', mostrando 0.00 para aquellos clientes que no tengan ningún pedido pagado. La salida debe ordenarse de mayor a menor según el total gastado, y por id ascendente en caso de empate. No uses SELECT *"

## Qué generó
```sql
SELECT
    c.id,
    c.nombre,
    COALESCE(SUM(p.total), 0.00) AS total_gastado
FROM cliente AS c
LEFT JOIN pedido AS p
    ON p.cliente_id = c.id
    AND p.estado = 'pagado'
WHERE c.activo = TRUE
GROUP BY c.id, c.nombre
ORDER BY total_gastado DESC, c.id ASC;
```

Cómo funciona: el `LEFT JOIN` con la condición `p.estado = 'pagado'` en el `ON` (no en el `WHERE`) conserva a los clientes sin pedidos pagados; `SUM` acumula sus totales y `COALESCE(..., 0.00)` convierte el `NULL` en `0.00`. `GROUP BY c.id, c.nombre` agrega por cliente y el `ORDER BY` aplica mayor-gasto-primero con desempate por `id`. Sin `SELECT *`: solo las 3 columnas pedidas. Documentado en `TP3/DUIA_Parte4.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Consulta entregada en el chat, más este DUIA en `TP3/DUIA_Parte4.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
