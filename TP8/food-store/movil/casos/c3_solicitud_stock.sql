-- Caso C3: nueva solicitud para el borrador que pide 5 manzanas (hay 4).
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-000000000013',
        '77777777-7777-4777-8777-777777777777');

SELECT c.solicitud_uuid, i.producto_id, i.cantidad, s.stock, c.estado
  FROM cola_sync AS c
  JOIN item_borrador AS i ON i.id_local = c.id_local
  LEFT JOIN snapshot_servidor AS s ON s.id = i.producto_id
 WHERE c.solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000013';