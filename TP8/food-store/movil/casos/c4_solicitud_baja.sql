-- Caso C4: nueva solicitud para la yerba mate, ya dada de baja en el servidor.
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-000000000014',
        '99999999-9999-4999-8999-999999999999');

-- El item local sigue existiendo aunque el producto ya no se muestre.
SELECT 'item local conservado' AS control,
       (SELECT count(*) FROM item_borrador
         WHERE id_local = '99999999-9999-4999-8999-999999999999'
           AND producto_id = 6) AS filas_item;

-- La consulta del catalogo disponible ya no muestra el producto 6.
SELECT 'catalogo disponible' AS control,
       (SELECT count(*) FROM producto_cache
         WHERE id = 6 AND disponible = 1 AND eliminado = 0 AND stock > 0) AS filas_visibles;

-- La fila de cache y la instantanea conservan la baja logica.
SELECT 'cache conserva la baja' AS control,
       (SELECT count(*) FROM producto_cache
         WHERE id = 6 AND eliminado = 1) AS filas_cache_eliminadas,
       (SELECT count(*) FROM snapshot_servidor
         WHERE id = 6 AND eliminado = 1) AS filas_snapshot_eliminadas;