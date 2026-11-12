-- ============================================================================
-- TP8 - Semaforo de sincronizacion (SQLite)
-- ============================================================================
-- Compara cada solicitud PENDIENTE con snapshot_servidor y escribe en
-- cola_sync el estado y el motivo:
--
--   RECHAZADO          rojo: producto inexistente, dado de baja, no disponible
--                      o stock insuficiente.
--   CONFLICTO          amarillo: no hay rojo, pero cambio algun precio.
--   SIMULADO_APROBADO  verde: todo coincide.
--
-- Reglas:
--   * Solo se evaluan solicitudes PENDIENTE.
--   * No se escribe nada en PostgreSQL.
--   * No se confirma ninguna venta: SIMULADO_APROBADO no es una venta.
--   * Repetir la simulacion no cambia filas ya evaluadas.
-- ============================================================================

PRAGMA foreign_keys = ON;

BEGIN;

WITH base AS (
    SELECT c.solicitud_uuid,
           i.producto_id,
           i.cantidad,
           i.precio_centavos_visto,
           s.id                AS servidor_id,
           s.stock             AS stock_servidor,
           s.disponible        AS disponible_servidor,
           s.eliminado         AS eliminado_servidor,
           s.precio_centavos   AS precio_servidor
      FROM cola_sync AS c
      JOIN item_borrador AS i ON i.id_local = c.id_local
      LEFT JOIN snapshot_servidor AS s ON s.id = i.producto_id
     WHERE c.estado = 'PENDIENTE'
),
agg AS (
    SELECT solicitud_uuid,
           SUM(CASE WHEN servidor_id IS NULL THEN 1 ELSE 0 END) AS n_inexistente,
           SUM(CASE WHEN servidor_id IS NOT NULL AND eliminado_servidor = 1 THEN 1 ELSE 0 END) AS n_baja,
           SUM(CASE WHEN servidor_id IS NOT NULL AND disponible_servidor = 0 THEN 1 ELSE 0 END) AS n_no_disponible,
           SUM(CASE WHEN servidor_id IS NOT NULL AND stock_servidor = 0 THEN 1 ELSE 0 END) AS n_sin_stock,
           SUM(CASE WHEN servidor_id IS NOT NULL AND stock_servidor > 0 AND cantidad > stock_servidor THEN 1 ELSE 0 END) AS n_stock_insuficiente,
           SUM(CASE WHEN servidor_id IS NOT NULL AND precio_centavos_visto <> precio_servidor THEN 1 ELSE 0 END) AS n_precio_distinto,
           group_concat(CASE WHEN servidor_id IS NULL
                             THEN 'id ' || producto_id || ' inexistente' END, ', ') AS d_inexistente,
           group_concat(CASE WHEN servidor_id IS NOT NULL AND eliminado_servidor = 1
                             THEN 'id ' || producto_id || ' dado de baja' END, ', ') AS d_baja,
           group_concat(CASE WHEN servidor_id IS NOT NULL AND disponible_servidor = 0
                             THEN 'id ' || producto_id || ' no disponible' END, ', ') AS d_no_disponible,
           group_concat(CASE WHEN servidor_id IS NOT NULL AND stock_servidor = 0
                             THEN 'id ' || producto_id || ' sin stock' END, ', ') AS d_sin_stock,
           group_concat(CASE WHEN servidor_id IS NOT NULL AND stock_servidor > 0 AND cantidad > stock_servidor
                             THEN 'id ' || producto_id || ': pedidas ' || cantidad
                                  || ', stock ' || stock_servidor END, ', ') AS d_stock_insuficiente,
           group_concat(CASE WHEN servidor_id IS NOT NULL AND precio_centavos_visto <> precio_servidor
                             THEN 'id ' || producto_id || ': visto ' || precio_centavos_visto
                                  || ', servidor ' || precio_servidor END, ', ') AS d_precio
      FROM base
     GROUP BY solicitud_uuid
),
evaluacion AS (
    SELECT solicitud_uuid,
           CASE
               WHEN n_inexistente > 0
                 OR n_baja > 0
                 OR n_no_disponible > 0
                 OR n_sin_stock > 0
                 OR n_stock_insuficiente > 0 THEN 'RECHAZADO'
               WHEN n_precio_distinto > 0 THEN 'CONFLICTO'
               ELSE 'SIMULADO_APROBADO'
           END AS estado,
           COALESCE(
               NULLIF(
                   TRIM(
                       CASE WHEN n_inexistente > 0         THEN 'producto inexistente en servidor: ' || d_inexistente || '; ' ELSE '' END ||
                       CASE WHEN n_baja > 0                THEN 'producto dado de baja: '          || d_baja        || '; ' ELSE '' END ||
                       CASE WHEN n_no_disponible > 0       THEN 'producto no disponible: '        || d_no_disponible || '; ' ELSE '' END ||
                       CASE WHEN n_sin_stock > 0           THEN 'sin stock: '                      || d_sin_stock   || '; ' ELSE '' END ||
                       CASE WHEN n_stock_insuficiente > 0  THEN 'stock insuficiente: '             || d_stock_insuficiente || '; ' ELSE '' END ||
                       CASE WHEN n_precio_distinto > 0     THEN 'precio cambiado: '                || d_precio      || '; ' ELSE '' END
                   ),
                   ''
               ),
               'precio, stock y disponibilidad coinciden'
           ) AS motivo
      FROM agg
)
UPDATE cola_sync
   SET estado = e.estado,
       motivo = e.motivo,
       actualizado_en = datetime('now')
  FROM evaluacion AS e
 WHERE cola_sync.solicitud_uuid = e.solicitud_uuid
   AND cola_sync.estado = 'PENDIENTE';

COMMIT;

-- Resultado para leer en clase
SELECT c.solicitud_uuid,
       c.id_local,
       c.estado,
       c.motivo
  FROM cola_sync AS c
 ORDER BY c.id_local, c.solicitud_uuid;