Script 1



¿Qué filas afectaría realmente tal como está escrito?

Afecta a todas y cada una de las filas existentes en la tabla funcion, sin excepción.



¿Por qué no coincide con la consigna?

La consigna pedía dar de baja únicamente las funciones pertenecientes a películas que fueron retiradas de cartel. Al omitir por completo la cláusula WHERE (o el filtro de relación con la tabla de películas), la sentencia desactiva también las funciones de películas que siguen vigentes y en cartelera, provocando una caída total e inadvertida del catálogo disponible.



Versión corregida:



UPDATE funcion

SET activa = FALSE

WHERE pelicula\_id IN (

&#x20;   SELECT id 

&#x20;   FROM pelicula 

&#x20;   WHERE en\_cartel = FALSE

);



Script 2



¿Qué filas afectaría realmente tal como está escrito?

Si existe al menos un solo producto con categoria\_id IS NULL, la subconsulta devuelve un conjunto que incluye NULL. Por la lógica ternaria de SQL (TRUE, FALSE, UNKNOWN), la comparación id NOT IN (..., NULL) siempre evalúa a UNKNOWN/falso para todas las filas. En ese escenario, no elimina absolutamente ninguna fila (0 filas afectadas).



¿Por qué no coincide con la consigna?

El operador NOT IN es muy peligroso frente a valores nulos. Si hay productos huérfanos o sin categoría asignada (NULL), la condición no se cumplirá jamás y el script fallará silenciosamente en su tarea de limpieza sin arrojar ningún error de sintaxis, dejando la base en un estado inconsistente con lo que el operador pretendía realizar.



Versión corregida:



DELETE FROM categoria c

WHERE NOT EXISTS (

&#x20;   SELECT 1 

&#x20;   FROM producto p 

&#x20;   WHERE p.categoria\_id = c.id

);



