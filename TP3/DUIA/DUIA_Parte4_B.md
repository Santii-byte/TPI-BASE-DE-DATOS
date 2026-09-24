# DUIA - Productos sobre el promedio de activos

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Generá una consulta SQL sobre la tabla producto que devuelva el id, nombre y precio de todos los productos activos (activo = true) cuyo precio sea mayor al promedio de precio de todos los productos activos. Ordená por precio descendente. Resolvelo usando una subconsulta en la cláusula WHERE. No uses SELECT *"

## Qué generó
```sql
SELECT id, nombre, precio
FROM producto
WHERE activo = TRUE
  AND precio > (SELECT AVG(precio) FROM producto WHERE activo = TRUE)
ORDER BY precio DESC;
```

Cómo funciona: la subconsulta del `WHERE` calcula una sola vez el precio promedio de los productos activos; la consulta exterior filtra los activos cuyo `precio` supera ese promedio y los ordena de mayor a menor precio. Sin `SELECT *`: solo `id`, `nombre` y `precio`. Documentado en `TP3/DUIA_Parte6.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Consulta entregada en el chat, más este DUIA en `TP3/DUIA_Parte6.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
