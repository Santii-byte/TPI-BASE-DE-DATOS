# DUIA - Productos sobre el promedio vía CTE

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Ahora escribí una segunda versión alternativa de esa misma consulta, pero en lugar de poner la subconsulta en el WHERE, resolvela calculando el promedio en un CTE (WITH) y combinándolo con un CROSS JOIN."

## Qué generó
```sql
WITH promedio_activos AS (
    SELECT AVG(precio) AS precio_promedio
    FROM producto
    WHERE activo = TRUE
)
SELECT p.id, p.nombre, p.precio
FROM producto AS p
CROSS JOIN promedio_activos AS pa
WHERE p.activo = TRUE
  AND p.precio > pa.precio_promedio
ORDER BY p.precio DESC;
```

Cómo funciona: el CTE `promedio_activos` calcula una sola fila con el promedio de los activos; el `CROSS JOIN` la adosa a cada fila de `producto` (producto cartesiano 1×N, sin condición de join), y el `WHERE` filtra activos con precio mayor al promedio, ordenados de mayor a menor. Responde exactamente lo mismo que la v1 con subconsulta en el `WHERE`. Documentado en `TP3/DUIA_Parte7.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Consulta entregada en el chat, más este DUIA en `TP3/DUIA_Parte7.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
