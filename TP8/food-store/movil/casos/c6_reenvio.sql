-- Caso C6: reenviar exactamente la misma solicitud C5.
-- La PK de cola_sync debe rechazar el duplicado; el semaforo no re-evalua.
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-000000000015',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

SELECT 'C6 reenvio' AS control,
       (SELECT count(*) FROM cola_sync
         WHERE solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000015') AS filas,
       (SELECT estado FROM cola_sync
         WHERE solicitud_uuid = 'aaaaaaaa-aaaa-4aaa-8aaa-000000000015') AS estado;