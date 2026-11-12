-- Caso C2, paso 2: nueva solicitud con el precio viejo (95000)
-- La instantanea nueva ya tiene el precio 105000.
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-000000000011',
        '88888888-8888-4888-8888-888888888888');

SELECT solicitud_uuid, id_local, estado, motivo
  FROM cola_sync
 WHERE solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000011';