Parte B: Vistas para los reportes del sistema

Verificación de equivalencia de resultados y Seguridad

Tal como se exige en el criterio de aceptación del trabajo, se procedió a verificar la exactitud de los datos expuestos por las vistas creadas, sin delegar la confianza ciegamente:

Metodología de prueba: Se ejecutó una consulta completa a la vista vista\_pedidos\_cliente (SELECT \* FROM vista\_pedidos\_cliente;).

Consulta de control: Inmediatamente después, se ejecutó la consulta manual equivalente (SELECT p.id, p.fecha, p.total, p.estado, c.id, c.nombre FROM pedido p JOIN cliente c ON p.cliente\_id = c.id;).

Resultado de equivalencia: Se compararon ambos conjuntos de resultados. Se verificó que ambas consultas devuelven exactamente la misma cantidad de filas y los mismos datos.

Criterio de seguridad: A su vez, se comprobó visualmente que la vista oculta por diseño las columnas privadas email y telefono de la tabla cliente. Esto garantiza que se pueda hacer un GRANT SELECT sobre esta vista para un analista de datos sin violar los principios de menor privilegio ni exponer información sensible de los usuarios.

