# DUIA - Clientes con gasto vía subconsulta correlacionada

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Ahora escribí una segunda versión alternativa de esa misma consulta, pero en lugar de usar LEFT JOIN con GROUP BY, resolvela usando una subconsulta correlacionada en el SELECT que responda exactamente lo mismo."

## Qué generó
```sql
SELECT
    c.id,
    c.nombre,
    COALESCE(
        (SELECT SUM(p.total)
         FROM pedido AS p
         WHERE p.cliente_id = c.id
           AND p.estado = 'pagado'),
        0.00
    ) AS total_gastado
FROM cliente AS c
WHERE c.activo = TRUE
ORDER BY total_gastado DESC, c.id ASC;
```

Cómo funciona: por cada cliente activo, la subconsulta correlacionada (`p.cliente_id = c.id`) suma solo sus pedidos `pagado`; si no tiene ninguno, el `SUM` da `NULL` y el `COALESCE(..., 0.00)` lo convierte en `0.00`. No hay `GROUP BY` porque la agregación ocurre dentro de la subconsulta, una por fila. El `ORDER BY` es idéntico al de la v1 (gasto DESC, `id` ASC), así que responde exactamente lo mismo. Nota de rendimiento: corre una agregación por cliente (20k), eficiente solo si existe índice sobre `pedido(cliente_id)` —lo hay (`idx_pedido_cliente_id`, y mejor aún el compuesto de `optimizacion.sql`). Documentado en `TP3/DUIA_Parte5.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Consulta entregada en el chat, más este DUIA en `TP3/DUIA_Parte5.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
