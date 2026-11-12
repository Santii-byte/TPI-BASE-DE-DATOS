-- Caso C5: borrador sin cambios, nueva solicitud.
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-000000000015',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

SELECT c.solicitud_uuid, i.producto_id, i.cantidad, i.precio_centavos_visto,
       s.precio_centavos, s.stock, c.estado
  FROM cola_sync AS c
  JOIN item_borrador AS i ON i.id_local = c.id_local
  JOIN snapshot_servidor AS s ON s.id = i.producto_id
 WHERE c.solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000015';