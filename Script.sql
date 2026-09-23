-- Limpieza inicial para garantizar que sea ejecutable de principio a fin varias veces
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TYPE IF EXISTS estado_pedido CASCADE;
DROP TYPE IF EXISTS metodo_pago CASCADE;

-- ============================================================================
-- 1. TIPOS ENUMERADOS (Dominios cerrados)
-- ============================================================================
CREATE TYPE estado_pedido AS ENUM ('pendiente', 'pagado', 'enviado', 'cancelado');
CREATE TYPE metodo_pago AS ENUM ('efectivo', 'tarjeta_credito', 'tarjeta_debito', 'transferencia');

-- ============================================================================
-- 2. TABLAS FUERTES / MAESTRAS
-- ============================================================================

CREATE TABLE cliente (
    -- Identificador autogenerado estándar SQL
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    -- Clave candidata: restricción UNIQUE
    email VARCHAR(255) NOT NULL UNIQUE,
    telefono VARCHAR(20), -- Nulable si la participación era parcial
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE producto (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    -- Montos monetarios con precisión fija (NUMERIC / DECIMAL)
    -- CHECK 1: precio positivo
    precio NUMERIC(12, 2) NOT NULL CHECK (precio >= 0),
    -- CHECK 2: stock no negativo
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 3. TABLAS DEPENDIENTES (Relación 1:N)
-- ============================================================================

CREATE TABLE pedido (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- FK hacia cliente (participación total: NOT NULL)
    -- RESTRICT evita borrar un cliente si ya tiene pedidos registrados por auditoría contable
    cliente_id BIGINT NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
    total NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    estado estado_pedido NOT NULL DEFAULT 'pendiente',
    forma_pago metodo_pago NOT NULL
);

-- ============================================================================
-- 4. TABLA INTERMEDIA (Relación N:M entre Pedido y Producto)
-- ============================================================================

CREATE TABLE detalle_pedido (
    -- CASCADE elimina los renglones si se anula/borra físicamente el pedido padre
    pedido_id BIGINT NOT NULL REFERENCES pedido(id) ON DELETE CASCADE,
    -- RESTRICT impide eliminar un producto del catálogo histórico si formó parte de una venta
    producto_id BIGINT NOT NULL REFERENCES producto(id) ON DELETE RESTRICT,
    -- CHECK 3: cantidad debe ser estrictamente mayor a cero
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12, 2) NOT NULL CHECK (precio_unitario >= 0),
    
    -- Clave primaria compuesta
    PRIMARY KEY (pedido_id, producto_id)
);

-- ============================================================================
-- 5. ÍNDICES DE RENDIMIENTO (Con justificación)
-- ============================================================================

-- Acelera la búsqueda de todos los pedidos históricos asociados a un cliente
CREATE INDEX idx_pedido_cliente_id ON pedido(cliente_id);

-- Acelera la consulta y filtrado de productos disponibles/vigentes para el catálogo
CREATE INDEX idx_producto_activo ON producto(activo) WHERE activo = TRUE;