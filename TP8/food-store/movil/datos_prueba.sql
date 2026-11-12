-- ============================================================================
-- TP8 - Borradores de prueba de la tablet (datos inventados)
-- ============================================================================
-- Se ejecuta despues de importar la instantanea inicial. Deja diez borradores
-- con solicitudes PENDIENTE para que semaforo.sql los clasifique.
-- Los UUID son ficticios y fijos para que la evidencia sea reproducible.
-- ============================================================================

PRAGMA foreign_keys = ON;

BEGIN;

DELETE FROM cola_sync;
DELETE FROM item_borrador;
DELETE FROM pedido_borrador;

-- 1) Todo coincide: debe quedar SIMULADO_APROBADO
INSERT INTO pedido_borrador VALUES
    ('11111111-1111-4111-8111-111111111111', 'vendedor_parada5', 'EFECTIVO', '2026-11-12T09:00:00');
INSERT INTO item_borrador VALUES
    ('11111111-1111-4111-8111-111111111111', 1, 2, 180000),
    ('11111111-1111-4111-8111-111111111111', 3, 1, 320000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000001', '11111111-1111-4111-8111-111111111111');

-- 2) Precio visto 400000 vs servidor 450000: debe quedar CONFLICTO
INSERT INTO pedido_borrador VALUES
    ('22222222-2222-4222-8222-222222222222', 'vendedor_parada5', 'TARJETA', '2026-11-12T09:05:00');
INSERT INTO item_borrador VALUES
    ('22222222-2222-4222-8222-222222222222', 4, 1, 400000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000002', '22222222-2222-4222-8222-222222222222');

-- 3) Pide 10 tomates y hay 8: RECHAZADO por stock
INSERT INTO pedido_borrador VALUES
    ('33333333-3333-4333-8333-333333333333', 'cajero_turno_a', 'TRANSFERENCIA', '2026-11-12T09:10:00');
INSERT INTO item_borrador VALUES
    ('33333333-3333-4333-8333-333333333333', 11, 10, 120000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000003', '33333333-3333-4333-8333-333333333333');

-- 4) Producto 15 eliminado en el servidor: RECHAZADO
INSERT INTO pedido_borrador VALUES
    ('44444444-4444-4444-8444-444444444444', 'cajero_turno_a', 'EFECTIVO', '2026-11-12T09:15:00');
INSERT INTO item_borrador VALUES
    ('44444444-4444-4444-8444-444444444444', 15, 1, 75000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000004', '44444444-4444-4444-8444-444444444444');

-- 5) Producto 13 con stock 0: RECHAZADO
INSERT INTO pedido_borrador VALUES
    ('55555555-5555-4555-8555-555555555555', 'vendedor_parada5', 'EFECTIVO', '2026-11-12T09:20:00');
INSERT INTO item_borrador VALUES
    ('55555555-5555-4555-8555-555555555555', 13, 1, 70000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000005', '55555555-5555-4555-8555-555555555555');

-- 6) Producto 14 no disponible: RECHAZADO
INSERT INTO pedido_borrador VALUES
    ('66666666-6666-4666-8666-666666666666', 'vendedor_parada5', 'TARJETA', '2026-11-12T09:25:00');
INSERT INTO item_borrador VALUES
    ('66666666-6666-4666-8666-666666666666', 14, 1, 60000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000006', '66666666-6666-4666-8666-666666666666');

-- 7) Caso C3: 5 manzanas y hay 4: RECHAZADO
INSERT INTO pedido_borrador VALUES
    ('77777777-7777-4777-8777-777777777777', 'cajero_turno_a', 'EFECTIVO', '2026-11-12T09:30:00');
INSERT INTO item_borrador VALUES
    ('77777777-7777-4777-8777-777777777777', 12, 5, 140000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000007', '77777777-7777-4777-8777-777777777777');

-- 8) Caso C2: precio correcto al inicio (95000)
INSERT INTO pedido_borrador VALUES
    ('88888888-8888-4888-8888-888888888888', 'vendedor_parada5', 'EFECTIVO', '2026-11-12T09:35:00');
INSERT INTO item_borrador VALUES
    ('88888888-8888-4888-8888-888888888888', 2, 2, 95000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000008', '88888888-8888-4888-8888-888888888888');

-- 9) Caso C4: producto vigente al inicio
INSERT INTO pedido_borrador VALUES
    ('99999999-9999-4999-8999-999999999999', 'cajero_turno_a', 'TRANSFERENCIA', '2026-11-12T09:40:00');
INSERT INTO item_borrador VALUES
    ('99999999-9999-4999-8999-999999999999', 6, 1, 390000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000009', '99999999-9999-4999-8999-999999999999');

-- 10) Caso C5: borrador sin cambios
INSERT INTO pedido_borrador VALUES
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'vendedor_parada5', 'EFECTIVO', '2026-11-12T09:45:00');
INSERT INTO item_borrador VALUES
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 7, 1, 110000);
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
    ('aaaaaaaa-aaaa-4aaa-8aaa-000000000010', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

COMMIT;

SELECT (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador)   AS items,
       (SELECT count(*) FROM cola_sync WHERE estado = 'PENDIENTE') AS pendientes;