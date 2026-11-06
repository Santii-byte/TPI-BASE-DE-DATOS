-- ============================================================================
-- TP 6 — Parte 2 / 01: Esquema base Food Store extendido
-- PostgreSQL 16+
-- ============================================================================
-- Crea un esquema aislado `tp6_p2` con las tablas que necesita la consulta
-- del panel: categoria, cliente, producto (con categoria_id y eliminado),
-- pedido (con fecha DATE y eliminado) y detalle_pedido (con subtotal
-- generado y eliminado).
--
-- Este esquema NO forma parte del entregable de desnormalización: es la
-- fuente de verdad sobre la que se mide el "antes" y se construye el
-- resumen desnormalizado.
-- ============================================================================

BEGIN;

DROP SCHEMA IF EXISTS tp6_p2 CASCADE;
CREATE SCHEMA tp6_p2;
SET LOCAL search_path TO tp6_p2, public;

CREATE TYPE estado_pedido AS ENUM ('pendiente', 'pagado', 'enviado', 'cancelado');
CREATE TYPE metodo_pago AS ENUM ('efectivo', 'tarjeta_credito', 'tarjeta_debito', 'transferencia');

CREATE TABLE categoria (
    id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE cliente (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,
    activo     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE producto (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(120) NOT NULL,
    precio       NUMERIC(12, 2) NOT NULL CHECK (precio >= 0),
    stock        INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    activo       BOOLEAN NOT NULL DEFAULT TRUE,
    categoria_id BIGINT NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    eliminado    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pedido (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id BIGINT NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT,
    fecha      DATE NOT NULL DEFAULT CURRENT_DATE,
    total      NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    estado     estado_pedido NOT NULL DEFAULT 'pendiente',
    forma_pago metodo_pago NOT NULL DEFAULT 'efectivo',
    eliminado  BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE detalle_pedido (
    pedido_id       BIGINT NOT NULL REFERENCES pedido(id) ON DELETE RESTRICT,
    producto_id     BIGINT NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    cantidad        INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario > 0),
    -- Columna derivada determinística: no es la desnormalización del TP,
    -- es el subtotal que usa la consulta original del panel.
    subtotal        NUMERIC(14, 2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    eliminado       BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (pedido_id, producto_id)
);

-- Índices realistas de operación (los que tendría Food Store antes del TP).
CREATE INDEX idx_pedido_fecha_visible
    ON pedido (fecha)
    WHERE eliminado = FALSE;

CREATE INDEX idx_pedido_cliente
    ON pedido (cliente_id);

CREATE INDEX idx_detalle_pedido_pedido
    ON detalle_pedido (pedido_id)
    INCLUDE (producto_id, subtotal, eliminado);

CREATE INDEX idx_detalle_pedido_producto
    ON detalle_pedido (producto_id);

CREATE INDEX idx_producto_categoria
    ON producto (categoria_id)
    INCLUDE (precio);

COMMIT;
