-- ============================================================================
-- TP8 - Unidad 8: la base de la tablet
-- Food Store - esquema del servidor (PostgreSQL 17)
-- ============================================================================
-- Este esquema es una copia de laboratorio con datos inventados. NO se ejecuta
-- sobre la base de produccion. La fuente de verdad sigue siendo PostgreSQL:
-- precios, stock, disponibilidad y bajas logicas se deciden aca.
--
-- Uso:
--   createdb foodstore_u8
--   psql -d foodstore_u8 -v ON_ERROR_STOP=1 -f postgres/01_esquema.sql
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS v_snapshot_movil;
DROP TABLE IF EXISTS control_instalacion CASCADE;
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS tienda CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Tienda / parada de feria
-- ----------------------------------------------------------------------------
CREATE TABLE tienda (
    id       SMALLINT PRIMARY KEY,
    nombre   VARCHAR(120) NOT NULL,
    direccion VARCHAR(160) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. Catalogo del servidor
--    El dinero se guarda en centavos enteros para evitar errores de redondeo
--    y para que el mismo valor viaje sin cambios a SQLite.
-- ----------------------------------------------------------------------------
CREATE TABLE producto (
    id                BIGINT PRIMARY KEY,
    tienda_id         SMALLINT NOT NULL REFERENCES tienda(id) ON DELETE RESTRICT,
    nombre            VARCHAR(120) NOT NULL,
    categoria         VARCHAR(60) NOT NULL,
    precio_centavos   INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock             INTEGER NOT NULL CHECK (stock >= 0),
    disponible        BOOLEAN NOT NULL DEFAULT TRUE,
    eliminado         BOOLEAN NOT NULL DEFAULT FALSE,
    actualizado_en    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_producto_tienda ON producto (tienda_id);

-- ----------------------------------------------------------------------------
-- 3. Pedidos confirmados en el servidor
--    La tablet NUNCA escribe aca. id_local es la clave de idempotencia real:
--    si una solicitud se reenvia, el servidor la rechaza por UNIQUE.
-- ----------------------------------------------------------------------------
CREATE TABLE pedido (
    id              BIGINT PRIMARY KEY,
    tienda_id       SMALLINT NOT NULL REFERENCES tienda(id) ON DELETE RESTRICT,
    id_local        UUID NOT NULL UNIQUE,
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago      TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    total_centavos  INTEGER NOT NULL CHECK (total_centavos >= 0),
    estado          TEXT NOT NULL DEFAULT 'CONFIRMADO'
                    CHECK (estado IN ('CONFIRMADO', 'ANULADO'))
);

CREATE TABLE detalle_pedido (
    pedido_id        BIGINT NOT NULL REFERENCES pedido(id) ON DELETE CASCADE,
    producto_id      BIGINT NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    cantidad         INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    PRIMARY KEY (pedido_id, producto_id)
);

-- ----------------------------------------------------------------------------
-- 4. Vista que se exporta a la tablet
--    Incluye TODAS las filas de la parada 5, incluso las dadas de baja, para
--    que la tablet pueda explicar un RECHAZADO sin perder el item local.
--    fecha_copia queda como texto ISO para que el CSV sea estable.
-- ----------------------------------------------------------------------------
CREATE VIEW v_snapshot_movil AS
SELECT p.id,
       p.nombre,
       p.categoria,
       p.precio_centavos,
       p.stock,
       p.disponible,
       p.eliminado,
       to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS') AS fecha_copia
  FROM producto AS p
 WHERE p.tienda_id = 5;

-- ----------------------------------------------------------------------------
-- 5. Control de inmutabilidad
--    Guarda el estado del servidor al instalar. La verificacion final compara
--    contra estos valores para probar que la simulacion no cambio pedidos ni
--    stock.
-- ----------------------------------------------------------------------------
CREATE TABLE control_instalacion (
    pedidos_base   INTEGER NOT NULL,
    detalles_base  INTEGER NOT NULL,
    stock_base     INTEGER NOT NULL,
    registrado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;

-- Verificacion
SELECT count(*) AS productos_en_parada_5 FROM v_snapshot_movil;