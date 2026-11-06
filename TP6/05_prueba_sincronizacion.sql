-- ============================================================================
-- TP 6 — Parte 2 / 05: Prueba automática de sincronización de disparadores
-- ============================================================================
-- Ejecuta mutaciones sobre la fuente de verdad dentro de una transacción y,
-- después de cada una, verifica que el resumen coincida exactamente con la
-- fuente. Al final hace ROLLBACK: no deja cambios en la base.
-- ============================================================================

BEGIN;
SET LOCAL search_path TO tp6_p2, public;

-- Función temporal de auditoría: cuenta celdas desincronizadas.
CREATE OR REPLACE FUNCTION pg_temp.desync_count()
RETURNS BIGINT
LANGUAGE sql
AS $$
    WITH fuente AS (
        SELECT pr.categoria_id, p.fecha::date, SUM(dp.subtotal)::NUMERIC(14, 2) AS total
          FROM detalle_pedido dp
          JOIN pedido p     ON p.id = dp.pedido_id
          JOIN producto pr  ON pr.id = dp.producto_id
         WHERE dp.eliminado = FALSE
           AND p.eliminado = FALSE
         GROUP BY pr.categoria_id, p.fecha::date
    ),
    resumen AS (
        SELECT categoria_id, fecha, total_vendido AS total
          FROM resumen_venta_categoria_dia
    )
    SELECT count(*)
      FROM fuente f
      FULL OUTER JOIN resumen r
        ON r.categoria_id = f.categoria_id
       AND r.fecha = f.fecha
     WHERE f.total IS DISTINCT FROM r.total;
$$;

DO $$
DECLARE
    v_pedido    BIGINT;
    v_producto  BIGINT;
    v_categoria BIGINT;
    v_antes     NUMERIC;
    v_despues   NUMERIC;
BEGIN
    SELECT id INTO v_pedido
      FROM pedido
     WHERE fecha::date = CURRENT_DATE
       AND eliminado = FALSE
     ORDER BY id
     LIMIT 1;

    SELECT id INTO v_producto
      FROM producto
     WHERE id NOT IN (SELECT producto_id FROM detalle_pedido WHERE pedido_id = v_pedido)
     ORDER BY id
     LIMIT 1;

    SELECT categoria_id INTO v_categoria FROM producto WHERE id = v_producto;

    -- 1) INSERT de detalle: +5.000 al resumen
    SELECT COALESCE(total_vendido, 0) INTO v_antes
      FROM resumen_venta_categoria_dia
     WHERE categoria_id = v_categoria AND fecha = CURRENT_DATE;
    v_antes := COALESCE(v_antes, 0);

    INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, eliminado)
    VALUES (v_pedido, v_producto, 10, 500.00, FALSE);

    SELECT COALESCE(total_vendido, 0) INTO v_despues
      FROM resumen_venta_categoria_dia
     WHERE categoria_id = v_categoria AND fecha = CURRENT_DATE;
    IF v_despues - v_antes <> 5000.00 THEN
        RAISE EXCEPTION 'Fallo INSERT: delta esperado 5000, obtenido %', v_despues - v_antes;
    END IF;
    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo INSERT: el resumen quedó desincronizado';
    END IF;

    -- 2) UPDATE de cantidad: 10 -> 20, +5.000 adicionales
    UPDATE detalle_pedido
       SET cantidad = 20
     WHERE pedido_id = v_pedido AND producto_id = v_producto;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo UPDATE cantidad: el resumen quedó desincronizado';
    END IF;

    -- 3) Cambio de fecha del pedido: mueve toda la contribución de día
    UPDATE pedido
       SET fecha = CURRENT_DATE - 10
     WHERE id = v_pedido;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo UPDATE fecha de pedido: el resumen quedó desincronizado';
    END IF;

    -- 4) Cambio de categoría del producto: mueve todo el histórico del producto
    UPDATE producto
       SET categoria_id = CASE WHEN v_categoria = 1 THEN 2 ELSE 1 END
     WHERE id = v_producto;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo UPDATE categoria de producto: el resumen quedó desincronizado';
    END IF;

    -- 5) Soft-delete del detalle: deja de sumar
    UPDATE detalle_pedido
       SET eliminado = TRUE
     WHERE pedido_id = v_pedido AND producto_id = v_producto;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo soft-delete de detalle: el resumen quedó desincronizado';
    END IF;

    -- 6) Restauración del detalle: vuelve a sumar
    UPDATE detalle_pedido
       SET eliminado = FALSE
     WHERE pedido_id = v_pedido AND producto_id = v_producto;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo restauración de detalle: el resumen quedó desincronizado';
    END IF;

    -- 7) Borrado físico del detalle: resta su contribución
    DELETE FROM detalle_pedido
     WHERE pedido_id = v_pedido AND producto_id = v_producto;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo DELETE de detalle: el resumen quedó desincronizado';
    END IF;

    -- 8) Soft-delete del pedido completo: resta todos sus detalles visibles
    UPDATE pedido
       SET eliminado = TRUE
     WHERE id = v_pedido;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo soft-delete de pedido: el resumen quedó desincronizado';
    END IF;

    -- 9) Restauración del pedido
    UPDATE pedido
       SET eliminado = FALSE
     WHERE id = v_pedido;

    IF pg_temp.desync_count() <> 0 THEN
        RAISE EXCEPTION 'Fallo restauración de pedido: el resumen quedó desincronizado';
    END IF;

    RAISE NOTICE 'Prueba de sincronización OK: 9 mutaciones verificadas, 0 desincronizaciones.';
END;
$$;

ROLLBACK;
