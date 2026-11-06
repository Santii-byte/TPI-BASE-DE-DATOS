-- ============================================================================
-- TP 6 — Parte 2 / 06: Reversión de la desnormalización
-- ============================================================================
-- Elimina únicamente la estructura derivada y sus disparadores. La fuente
-- de verdad (detalle_pedido, pedido, producto, categoria) no se toca, por
-- lo que la información original queda intacta.
-- ============================================================================

-- Uso: ejecutar con search_path apuntando al esquema de Food Store
--   base acumulada de los TP:  SET search_path TO public;
--   laboratorio reproducible:  SET search_path TO tp6_p2, public;

BEGIN;

DROP TRIGGER IF EXISTS trg_detalle_pedido_resumen ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_pedido_resumen ON pedido;
DROP TRIGGER IF EXISTS trg_pedido_delete_resumen ON pedido;
DROP TRIGGER IF EXISTS trg_producto_resumen ON producto;

DROP FUNCTION IF EXISTS fn_detalle_pedido_resumen();
DROP FUNCTION IF EXISTS fn_pedido_resumen();
DROP FUNCTION IF EXISTS fn_pedido_delete_resumen();
DROP FUNCTION IF EXISTS fn_producto_resumen();
DROP FUNCTION IF EXISTS fn_resumen_aplicar(BIGINT, DATE, NUMERIC);

DROP TABLE IF EXISTS resumen_venta_categoria_dia;

COMMIT;
