-- ============================================================================
-- TP 6 — Parte 2 / 00: Migración del esquema Food Store acumulado (TP2–TP5)
-- ============================================================================
-- Extiende la base canónica de los TP anteriores (public) con lo que exige
-- la consulta del panel, SIN recrear ni reemplazar las tablas existentes:
--
--   * categoria (tabla maestra nueva)
--   * producto.categoria_id  -> FK a categoria
--   * producto.eliminado
--   * pedido.eliminado
--   * detalle_pedido.subtotal (columna generada)
--   * detalle_pedido.eliminado
--
-- Respeta el esquema de TP2/TP5:
--   - pedido.fecha sigue siendo TIMESTAMPTZ (no se cambia a DATE).
--   - detalle_pedido conserva su FK ON DELETE CASCADE.
--   - No se eliminan ni renombran tablas, columnas, tipos ni índices previos.
--
-- Uso (sobre una copia de trabajo, nunca sobre producción):
--   psql -d copia_trabajo -f TP6/00_migracion_esquema_tp5.sql
-- ============================================================================

BEGIN;
SET LOCAL search_path TO public;

-- ----------------------------------------------------------------------------
-- 1. Categorías (tabla maestra nueva)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categoria (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE
);

INSERT INTO categoria (nombre)
SELECT 'Categoría ' || lpad(g::text, 2, '0')
FROM generate_series(1, 60) AS g
ON CONFLICT (nombre) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. Columnas nuevas en las tablas existentes (idempotente)
-- ----------------------------------------------------------------------------
ALTER TABLE producto
    ADD COLUMN IF NOT EXISTS categoria_id BIGINT,
    ADD COLUMN IF NOT EXISTS eliminado    BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE pedido
    ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE detalle_pedido
    ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE detalle_pedido
    ADD COLUMN IF NOT EXISTS subtotal NUMERIC(14, 2)
        GENERATED ALWAYS AS (cantidad * precio_unitario) STORED;

-- ----------------------------------------------------------------------------
-- 3. Asignación de categorías a los productos existentes
--    (60 categorías, distribución determinística por id)
-- ----------------------------------------------------------------------------
UPDATE producto
   SET categoria_id = 1 + ((id - 1) % (SELECT count(*) FROM categoria))
 WHERE categoria_id IS NULL;

ALTER TABLE producto
    ALTER COLUMN categoria_id SET NOT NULL;

-- FK a categoria, solo si todavía no existe una FK equivalente
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conrelid = 'producto'::regclass
           AND contype = 'f'
           AND conname = 'producto_categoria_id_fkey'
    ) THEN
        ALTER TABLE producto
            ADD CONSTRAINT producto_categoria_id_fkey
            FOREIGN KEY (categoria_id) REFERENCES categoria(id)
            ON DELETE RESTRICT;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 4. Índices de apoyo (los previos de TP2/TP5 se conservan)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_categoria_id
    ON producto (categoria_id);

-- Índice por fecha para el filtro de "hoy" expresado como rango
-- [CURRENT_DATE, CURRENT_DATE + 1). No se usa una expresión fecha::date
-- porque el cast de TIMESTAMPTZ a DATE depende del TimeZone de la sesión
-- y PostgreSQL no permite indexarlo como IMMUTABLE.
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_eliminado
    ON pedido (fecha)
    WHERE eliminado = FALSE;

-- ----------------------------------------------------------------------------
-- 5. Estadísticas
-- ----------------------------------------------------------------------------
ANALYZE categoria;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

COMMIT;

-- Verificación de la migración
SELECT 'categoria' AS objeto, count(*) AS filas FROM public.categoria
UNION ALL
SELECT 'producto con categoría', count(*) FROM public.producto WHERE categoria_id IS NOT NULL
UNION ALL
SELECT 'producto sin categoría', count(*) FROM public.producto WHERE categoria_id IS NULL
UNION ALL
SELECT 'pedido', count(*) FROM public.pedido
UNION ALL
SELECT 'detalle_pedido', count(*) FROM public.detalle_pedido;
