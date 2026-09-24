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







\# DUIA - Declaración de Uso de IA



\## Herramienta

muse-spark-1.3-contributor-free (opencode)



\## Prompt utilizado

"Analizá estos dos scripts generados por IA: 1) UPDATE funcion SET activa = FALSE; y 2) DELETE FROM categoria WHERE id NOT IN (SELECT categoria\_id FROM producto);. Explicá qué filas afectan realmente tal como están escritos, por qué no cumplen con la consigna pedida y proporcioná la versión corregida de cada uno."



Prompts de seguimiento en el mismo flujo: "opcion A" y "Confirmado".



\## Qué generó

\# 1. Explicación de que el UPDATE sin cláusula WHERE desactiva todas las funciones indiscriminadamente, junto con la consulta corregida usando WHERE pelicula\_id IN (...).





2\. Análisis del operador NOT IN frente a valores NULL (lógica trivaluada/ternaria de SQL donde cualquier comparación con NULL evalúa a UNKNOWN y resulta en 0 filas borradas), y las correcciones usando NOT EXISTS y IS NOT NULL.



\## Qué se aceptó

\* La explicación conceptual de la evaluación lógica de NOT IN con NULL.





\* La corrección del UPDATE vinculando la tabla de películas mediante subconsulta.





\* La solución con NOT EXISTS para el segundo script.



\## Qué se modificó o descartó y por qué

Se descartó la alternativa de NOT IN (... WHERE categoria\_id IS NOT NULL) para la versión final del informe y se priorizó NOT EXISTS, debido a que esta última es el estándar recomendado en PostgreSQL por desempeño y robustez ante nulos.





\* Se adaptó la consulta de UPDATE para contemplar tanto la sintaxis estándar con subconsulta como la sintaxis nativa de PostgreSQL (UPDATE ... FROM ...).



\## Verificación realizada

Se reprodujo la prueba en la base de datos local:





1\. Se insertó una fila en producto con categoria\_id = NULL y se ejecutó el DELETE con NOT IN, comprobando que devolvió DELETE 0 (no borró nada).





2\. Se ejecutó la versión corregida con NOT EXISTS dentro de un bloque BEGIN ... ROLLBACK;, confirmando que eliminó únicamente las categorías sin productos asociados sin verse afectada por los nulos.

