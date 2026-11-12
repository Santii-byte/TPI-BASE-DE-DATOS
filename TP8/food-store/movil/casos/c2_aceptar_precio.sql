-- Caso C2, paso 3: el cliente acepta el precio del servidor.
-- Se actualiza el precio visto del borrador y se crea una solicitud nueva.
UPDATE item_borrador
   SET precio_centavos_visto = 105000
 WHERE id_local = '88888888-8888-4888-8888-888888888888'
   AND producto_id = 2;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-000000000012',
        '88888888-8888-4888-8888-888888888888');

SELECT i.id_local, i.producto_id, i.precio_centavos_visto, c.solicitud_uuid, c.estado
  FROM item_borrador AS i
  JOIN cola_sync AS c ON c.id_local = i.id_local
 WHERE i.id_local = '88888888-8888-4888-8888-888888888888'
 ORDER BY c.solicitud_uuid;