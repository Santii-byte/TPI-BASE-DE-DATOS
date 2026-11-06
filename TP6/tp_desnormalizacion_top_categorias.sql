-- ============================================================================
-- TP 6 — Parte 2: Desnormalización controlada del top 5 de categorías
-- Food Store — PostgreSQL 16+
-- ============================================================================
-- Patrón elegido: TABLA DE RESUMEN PRE-CALCULADA + DISPARADORES.
--
-- Estructura desnormalizada:
--   resumen_venta_categoria_dia (categoria_id, fecha, total_vendido)
--
-- Fuente de verdad: detalle_pedido + pedido + producto.
-- El resumen se mantiene por delta ante INSERT/UPDATE/DELETE de detalle,
-- cambios de fecha o soft-delete de pedido, y cambios de categoría de
-- producto. No se refresca en bloque: se actualiza en la misma transacción
-- que modifica la fuente.
--
-- Requiere: el esquema Food Store acumulado de los TP anteriores (public)
-- extendido con 00_migracion_esquema_tp5.sql, o el entorno de laboratorio
-- tp6_p2 creado por 01_esquema_base.sql + 02_poblado.sql.
--
-- IMPORTANTE: el script no fija el search_path. Debe ejecutarse con el
-- search_path apuntando al esquema de Food Store:
--   - base acumulada de los TP:  SET search_path TO public;
--   - laboratorio reproducible:  SET search_path TO tp6_p2, public;
-- ============================================================================

BEGIN;

-- Limpieza idempotente de la estructura derivada (no toca la fuente de verdad)
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

-- ============================================================================
-- 1. ESTRUCTURA DESNORMALIZADA
-- ============================================================================
CREATE TABLE resumen_venta_categoria_dia (
    categoria_id  BIGINT NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    fecha         DATE NOT NULL,
    total_vendido NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_vendido >= 0),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (categoria_id, fecha)
);

-- Índice que resuelve el top-N del panel: filtra por fecha y ya viene
-- ordenado por monto descendente. Incluye categoria_id para Index Only Scan.
CREATE INDEX idx_resumen_fecha_total
    ON resumen_venta_categoria_dia (fecha, total_vendido DESC)
    INCLUDE (categoria_id);

-- ============================================================================
-- 2. FUNCIÓN AUXILIAR: aplica un delta al resumen de forma atómica
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_resumen_aplicar(
    p_categoria_id BIGINT,
    p_fecha        DATE,
    p_delta        NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_delta = 0 THEN
        RETURN;
    END IF;

    -- Se actualiza primero para que un delta negativo no viole el CHECK
    -- sobre la tupla propuesta por un INSERT ... ON CONFLICT.
    UPDATE resumen_venta_categoria_dia
       SET total_vendido  = total_vendido + p_delta,
           actualizado_en = now()
     WHERE categoria_id = p_categoria_id
       AND fecha = p_fecha;

    IF NOT FOUND THEN
        IF p_delta < 0 THEN
            RAISE EXCEPTION
                'Resumen inconsistente: no existe la celda (categoría %, fecha %) para aplicar un delta negativo %.',
                p_categoria_id, p_fecha, p_delta;
        END IF;

        INSERT INTO resumen_venta_categoria_dia (categoria_id, fecha, total_vendido, actualizado_en)
        VALUES (p_categoria_id, p_fecha, p_delta, now())
        ON CONFLICT (categoria_id, fecha) DO UPDATE
           SET total_vendido  = resumen_venta_categoria_dia.total_vendido + EXCLUDED.total_vendido,
               actualizado_en = now();
    END IF;

    -- Si la celda queda en cero, se elimina para que el resumen represente
    -- exactamente las combinaciones (categoría, día) con ventas visibles.
    DELETE FROM resumen_venta_categoria_dia
     WHERE categoria_id = p_categoria_id
       AND fecha = p_fecha
       AND total_vendido = 0;
END;
$$;

-- ============================================================================
-- 3. SINCRONIZACIÓN ANTE CAMBIOS EN detalle_pedido
--    Cubre INSERT, UPDATE (cantidad, precio, producto, eliminado) y DELETE.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_detalle_pedido_resumen()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_categoria_id BIGINT;
    v_fecha        DATE;
    v_visible      BOOLEAN;
BEGIN
    -- Contribución anterior (solo en UPDATE o DELETE)
    IF TG_OP = 'DELETE' THEN
        SELECT pr.categoria_id,
               p.fecha::date,
               (NOT OLD.eliminado AND NOT p.eliminado)
          INTO v_categoria_id, v_fecha, v_visible
          FROM pedido AS p
          JOIN producto AS pr ON pr.id = OLD.producto_id
         WHERE p.id = OLD.pedido_id;

        -- Si el pedido ya no existe, estamos ante el borrado en cascada de
        -- detalle_pedido (FK ON DELETE CASCADE del esquema TP2/TP5). En ese
        -- caso la contribución ya fue restada por el trigger BEFORE DELETE
        -- de pedido; no hay que restarla dos veces.
        IF NOT FOUND THEN
            RETURN NULL;
        END IF;

        IF v_visible THEN
            PERFORM fn_resumen_aplicar(v_categoria_id, v_fecha, -OLD.subtotal);
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT pr.categoria_id,
               p.fecha::date,
               (NOT OLD.eliminado AND NOT p.eliminado)
          INTO v_categoria_id, v_fecha, v_visible
          FROM pedido AS p
          JOIN producto AS pr ON pr.id = OLD.producto_id
         WHERE p.id = OLD.pedido_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'No se encontró el pedido % o el producto % al revertir el detalle.',
                OLD.pedido_id, OLD.producto_id;
        END IF;

        IF v_visible THEN
            PERFORM fn_resumen_aplicar(v_categoria_id, v_fecha, -OLD.subtotal);
        END IF;
    END IF;

    -- Contribución nueva (solo en INSERT o UPDATE)
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        SELECT pr.categoria_id,
               p.fecha::date,
               (NOT NEW.eliminado AND NOT p.eliminado)
          INTO v_categoria_id, v_fecha, v_visible
          FROM pedido AS p
          JOIN producto AS pr ON pr.id = NEW.producto_id
         WHERE p.id = NEW.pedido_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'No se encontró el pedido % o el producto % al aplicar el detalle.',
                NEW.pedido_id, NEW.producto_id;
        END IF;

        IF v_visible THEN
            PERFORM fn_resumen_aplicar(v_categoria_id, v_fecha, NEW.subtotal);
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_detalle_pedido_resumen
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_detalle_pedido_resumen();

-- ============================================================================
-- 4. SINCRONIZACIÓN ANTE CAMBIOS DE FECHA O SOFT-DELETE DEL PEDIDO
--    Mueve (o quita) todos los renglones del pedido en una sola operación.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_pedido_resumen()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    IF (OLD.fecha IS DISTINCT FROM NEW.fecha)
       OR (OLD.eliminado IS DISTINCT FROM NEW.eliminado) THEN

        -- Revertir la contribución anterior si estaba visible
        IF NOT OLD.eliminado THEN
            FOR r IN
                SELECT pr.categoria_id, SUM(dp.subtotal) AS monto
                  FROM detalle_pedido AS dp
                  JOIN producto AS pr ON pr.id = dp.producto_id
                 WHERE dp.pedido_id = OLD.id
                   AND dp.eliminado = FALSE
                 GROUP BY pr.categoria_id
            LOOP
                PERFORM fn_resumen_aplicar(r.categoria_id, OLD.fecha::date, -r.monto);
            END LOOP;
        END IF;

        -- Aplicar la contribución nueva si queda visible
        IF NOT NEW.eliminado THEN
            FOR r IN
                SELECT pr.categoria_id, SUM(dp.subtotal) AS monto
                  FROM detalle_pedido AS dp
                  JOIN producto AS pr ON pr.id = dp.producto_id
                 WHERE dp.pedido_id = NEW.id
                   AND dp.eliminado = FALSE
                 GROUP BY pr.categoria_id
            LOOP
                PERFORM fn_resumen_aplicar(r.categoria_id, NEW.fecha::date, r.monto);
            END LOOP;
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_pedido_resumen
AFTER UPDATE OF fecha, eliminado ON pedido
FOR EACH ROW
EXECUTE FUNCTION fn_pedido_resumen();

-- Borrado físico del pedido: en el esquema TP2/TP5 la FK de detalle_pedido
-- es ON DELETE CASCADE. El trigger BEFORE DELETE resta la contribución
-- mientras el pedido todavía existe; luego el borrado en cascada de los
-- detalles no vuelve a restar (ver fn_detalle_pedido_resumen).
CREATE OR REPLACE FUNCTION fn_pedido_delete_resumen()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    IF NOT OLD.eliminado THEN
        FOR r IN
            SELECT pr.categoria_id, SUM(dp.subtotal) AS monto
              FROM detalle_pedido AS dp
              JOIN producto AS pr ON pr.id = dp.producto_id
             WHERE dp.pedido_id = OLD.id
               AND dp.eliminado = FALSE
             GROUP BY pr.categoria_id
        LOOP
            PERFORM fn_resumen_aplicar(r.categoria_id, OLD.fecha::date, -r.monto);
        END LOOP;
    END IF;

    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_pedido_delete_resumen
BEFORE DELETE ON pedido
FOR EACH ROW
EXECUTE FUNCTION fn_pedido_delete_resumen();

-- ============================================================================
-- 5. SINCRONIZACIÓN ANTE CAMBIO DE CATEGORÍA DE UN PRODUCTO
--    Mueve todo el histórico del producto de una categoría a otra.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_producto_resumen()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
BEGIN
    IF OLD.categoria_id IS DISTINCT FROM NEW.categoria_id THEN
        FOR r IN
            SELECT p.fecha::date, SUM(dp.subtotal) AS monto
              FROM detalle_pedido AS dp
              JOIN pedido AS p ON p.id = dp.pedido_id
             WHERE dp.producto_id = NEW.id
               AND dp.eliminado = FALSE
               AND p.eliminado = FALSE
             GROUP BY p.fecha::date
        LOOP
            PERFORM fn_resumen_aplicar(OLD.categoria_id, r.fecha, -r.monto);
            PERFORM fn_resumen_aplicar(NEW.categoria_id, r.fecha,  r.monto);
        END LOOP;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_producto_resumen
AFTER UPDATE OF categoria_id ON producto
FOR EACH ROW
EXECUTE FUNCTION fn_producto_resumen();

-- ============================================================================
-- 6. CARGA INICIAL DEL RESUMEN (backfill desde la fuente de verdad)
-- ============================================================================
INSERT INTO resumen_venta_categoria_dia (categoria_id, fecha, total_vendido)
SELECT pr.categoria_id,
       p.fecha::date,
       SUM(dp.subtotal)::NUMERIC(14, 2)
  FROM detalle_pedido AS dp
  JOIN pedido AS p   ON p.id = dp.pedido_id
  JOIN producto AS pr ON pr.id = dp.producto_id
 WHERE dp.eliminado = FALSE
   AND p.eliminado = FALSE
 GROUP BY pr.categoria_id, p.fecha::date;

COMMIT;

-- Estadísticas para el plan del "después"
VACUUM ANALYZE resumen_venta_categoria_dia;
ANALYZE categoria;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- ============================================================================
-- 7. CONSULTA DEL PANEL LEYENDO LA ESTRUCTURA DESNORMALIZADA
-- ============================================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       r.total_vendido
  FROM resumen_venta_categoria_dia AS r
  JOIN categoria AS c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;

SELECT c.nombre AS categoria,
       r.total_vendido
  FROM resumen_venta_categoria_dia AS r
  JOIN categoria AS c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;

-- ============================================================================
-- 8. AUDITORÍA DE DESINCRONIZACIÓN
--    Compara la fuente de verdad contra el resumen. Debe devolver 0 filas.
-- ============================================================================
WITH fuente AS (
    SELECT pr.categoria_id,
           p.fecha::date,
           SUM(dp.subtotal)::NUMERIC(14, 2) AS total_vendido
      FROM detalle_pedido AS dp
      JOIN pedido AS p    ON p.id = dp.pedido_id
      JOIN producto AS pr ON pr.id = dp.producto_id
     WHERE dp.eliminado = FALSE
       AND p.eliminado = FALSE
     GROUP BY pr.categoria_id, p.fecha::date
),
resumen AS (
    SELECT categoria_id, fecha, total_vendido
      FROM resumen_venta_categoria_dia
)
SELECT COALESCE(f.categoria_id, r.categoria_id) AS categoria_id,
       COALESCE(f.fecha, r.fecha)               AS fecha,
       f.total_vendido                          AS total_fuente,
       r.total_vendido                          AS total_resumen,
       CASE
           WHEN f.categoria_id IS NULL THEN 'fila sobrante en el resumen'
           WHEN r.categoria_id IS NULL THEN 'fila faltante en el resumen'
           ELSE 'total desincronizado'
       END AS problema
  FROM fuente AS f
  FULL OUTER JOIN resumen AS r
    ON r.categoria_id = f.categoria_id
   AND r.fecha = f.fecha
 WHERE f.total_vendido IS DISTINCT FROM r.total_vendido
 ORDER BY fecha, categoria_id;

-- Control adicional: suma global fuente vs resumen (una sola fila, TRUE)
SELECT (SELECT COALESCE(SUM(total_vendido), 0) FROM resumen_venta_categoria_dia) =
       (SELECT COALESCE(SUM(dp.subtotal), 0)
          FROM detalle_pedido dp
          JOIN pedido p ON p.id = dp.pedido_id
         WHERE dp.eliminado = FALSE
           AND p.eliminado = FALSE) AS suma_global_coincide;
