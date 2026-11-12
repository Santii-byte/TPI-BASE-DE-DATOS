-- ============================================================================
-- TP8 - Pruebas de la tablet (SQLite)
-- ============================================================================
-- Ejecutar despues de schema_sqlite.sql, importar_snapshot.sql y
-- datos_prueba.sql. No usa el servidor: todo ocurre en el archivo local.
--
-- Con sqlite3:
--   sqlite3 foodstore_movil.db < pruebas_sqlite.sql
-- Con DB Browser: abrir foodstore_movil.db y ejecutar este script.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- C1. El catalogo disponible se consulta SIN el servidor
--     database_list muestra solo "main": no hay adjunto ni conexion remota.
-- ----------------------------------------------------------------------------
PRAGMA database_list;

SELECT 'C1 catalogo local' AS prueba,
       count(*) AS productos_visibles
  FROM producto_cache
 WHERE disponible = 1
   AND eliminado = 0
   AND stock > 0;

SELECT id, nombre, precio_centavos, stock
  FROM producto_cache
 WHERE disponible = 1
   AND eliminado = 0
   AND stock > 0
 ORDER BY nombre
 LIMIT 5;

-- ----------------------------------------------------------------------------
-- 1. Borrador completo guardado con BEGIN ... COMMIT
-- ----------------------------------------------------------------------------
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        'vendedor_parada5', 'EFECTIVO', '2026-11-12T10:00:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 1, 2, 180000),
       ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 3, 1, 320000);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('cccccccc-cccc-4ccc-8ccc-000000000001',
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc');

COMMIT;

SELECT 'borrador completo' AS prueba,
       (SELECT count(*) FROM item_borrador
         WHERE id_local = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') AS items,
       (SELECT count(*) FROM cola_sync
         WHERE id_local = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc') AS solicitudes;

-- ----------------------------------------------------------------------------
-- 2. Borrador descartado con ROLLBACK: no debe quedar ninguna fila
-- ----------------------------------------------------------------------------
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        'cajero_turno_a', 'TARJETA', '2026-11-12T10:05:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 5, 3, 280000);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('dddddddd-dddd-4ddd-8ddd-000000000001',
        'dddddddd-dddd-4ddd-8ddd-dddddddddddd');

ROLLBACK;

SELECT 'rollback' AS prueba,
       (SELECT count(*) FROM pedido_borrador
         WHERE id_local = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') AS borradores,
       (SELECT count(*) FROM item_borrador
         WHERE id_local = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') AS items,
       (SELECT count(*) FROM cola_sync
         WHERE id_local = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd') AS solicitudes;

-- ----------------------------------------------------------------------------
-- C7a. Cantidad 0: el CHECK debe rechazar y no dejar filas nuevas
-- ----------------------------------------------------------------------------
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        'vendedor_parada5', 'EFECTIVO', '2026-11-12T10:10:00');

-- Debe fallar: cantidad > 0
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 1, 0, 180000);

ROLLBACK;

SELECT 'C7a cantidad 0' AS prueba,
       (SELECT count(*) FROM pedido_borrador
         WHERE id_local = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee') AS borradores,
       (SELECT count(*) FROM item_borrador
         WHERE id_local = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee') AS items;

-- ----------------------------------------------------------------------------
-- C7b. Producto inexistente: la FK debe rechazar y no dejar filas nuevas
-- ----------------------------------------------------------------------------
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('ffffffff-ffff-4fff-8fff-ffffffffffff',
        'vendedor_parada5', 'EFECTIVO', '2026-11-12T10:15:00');

-- Debe fallar: producto 999999 no existe en producto_cache
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('ffffffff-ffff-4fff-8fff-ffffffffffff', 999999, 1, 100000);

ROLLBACK;

SELECT 'C7b producto inexistente' AS prueba,
       (SELECT count(*) FROM pedido_borrador
         WHERE id_local = 'ffffffff-ffff-4fff-8fff-ffffffffffff') AS borradores,
       (SELECT count(*) FROM item_borrador
         WHERE id_local = 'ffffffff-ffff-4fff-8fff-ffffffffffff') AS items;

-- Estado final de las pruebas
SELECT 'resumen' AS prueba,
       (SELECT count(*) FROM pedido_borrador) AS pedidos,
       (SELECT count(*) FROM item_borrador)   AS items,
       (SELECT count(*) FROM cola_sync)       AS solicitudes;