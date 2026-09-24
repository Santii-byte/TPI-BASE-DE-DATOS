Declaración de Uso de IA (DUIA) - Food Store

Parte B: Vistas para los reportes del sistema

Herramientas utilizadas: Kiro (para especificar los requerimientos) y OpenCode (como agente generador de código SQL).

Propósito: Crear vistas que simplifiquen el acceso a los datos de los reportes frecuentes y aplicar restricciones de seguridad sobre los datos sensibles de los clientes.

Prompt / Spec entregado: Se elaboraron tres especificaciones (ej. spec_vista_pedidos_cliente.md) donde se indicó el objetivo de unir las tablas pedido y cliente, listando explícitamente las columnas a mostrar (id pedido, fecha, total, estado, id cliente, nombre cliente) y especificando la exclusión obligatoria de las columnas email y telefono.

Propuesta de la IA: OpenCode generó los scripts CREATE VIEW correspondientes, incluyendo los JOIN estructuralmente correctos basados en el schema.sql provisto.

Decisión y Justificación Técnica: Se aceptaron las propuestas generadas, pero ninguna se ejecutó a ciegas.

Verificación de equivalencia (Requisito obligatorio): Antes de dar por válidas las vistas, se ejecutó SELECT * FROM vista_pedidos_cliente y se comparó el resultado línea por línea con la consulta manual SELECT p.id, p.fecha, p.total, p.estado, c.id, c.nombre FROM pedido p JOIN cliente c ON p.cliente_id = c.id. Se comprobó que arrojaban el mismo resultado.

Criterio de seguridad: Se validó técnicamente que la vista no expone email ni telefono, permitiendo así otorgar permisos de SELECT a roles de analistas sin vulnerar la privacidad de los usuarios.