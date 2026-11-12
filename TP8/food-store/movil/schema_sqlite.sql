-- ============================================================================
-- TP8 - Unidad 8: esquema SQLite de la tablet (Food Store - parada 5)
-- ============================================================================
-- Ejecutar con sqlite3 o DB Browser for SQLite:
--   sqlite3 foodstore_movil.db < schema_sqlite.sql
--
-- Decisiones:
--   * STRICT en las cuatro tablas operativas: el motor rechaza tipos que no
--     corresponden (por ejemplo, texto en cantidad).
--   * El dinero viaja en centavos enteros; no se usan REAL.
--   * Las claves foraneas estan activas (PRAGMA foreign_keys = ON).
--   * fecha_copia queda como texto ISO 8601 para conservar la fecha exacta
--     de la instancia tomada en PostgreSQL.
-- ============================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS snapshot_raw;
DROP TABLE IF EXISTS snapshot_servidor;
DROP TABLE IF EXISTS producto_cache;

-- ----------------------------------------------------------------------------
-- 1. Catalogo local (copia de trabajo del servidor)
-- ----------------------------------------------------------------------------
CREATE TABLE producto_cache (
    id                INTEGER PRIMARY KEY,
    nombre            TEXT    NOT NULL,
    categoria         TEXT    NOT NULL,
    precio_centavos   INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock             INTEGER NOT NULL CHECK (stock >= 0),
    disponible        INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado         INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia       TEXT    NOT NULL
) STRICT;

-- ----------------------------------------------------------------------------
-- 2. Borrador local
-- ----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local     TEXT PRIMARY KEY,
    usuario      TEXT NOT NULL,
    forma_pago   TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha        TEXT NOT NULL
) STRICT;

CREATE TABLE item_borrador (
    id_local               TEXT    NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id            INTEGER NOT NULL REFERENCES producto_cache(id)     ON DELETE RESTRICT,
    cantidad               INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto  INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

CREATE INDEX idx_item_borrador_producto ON item_borrador (producto_id);

-- ----------------------------------------------------------------------------
-- 3. Cola de sincronizacion
--    La PK (solicitud_uuid) es la proteccion de idempotencia en la tablet.
-- ----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY,
    id_local        TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
                    CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo          TEXT,
    actualizado_en  TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

CREATE INDEX idx_cola_sync_estado ON cola_sync (estado);

-- ----------------------------------------------------------------------------
-- 4. Instantanea del servidor
--    snapshot_raw es una tabla de staging de texto porque PostgreSQL exporta
--    los booleanos como t/f. importar_snapshot.sql la convierte a 1/0.
-- ----------------------------------------------------------------------------
CREATE TABLE snapshot_raw (
    id                TEXT,
    nombre            TEXT,
    categoria         TEXT,
    precio_centavos   TEXT,
    stock             TEXT,
    disponible        TEXT,
    eliminado         TEXT,
    fecha_copia       TEXT
);

CREATE TABLE snapshot_servidor (
    id                INTEGER PRIMARY KEY,
    nombre            TEXT    NOT NULL,
    categoria         TEXT    NOT NULL,
    precio_centavos   INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock             INTEGER NOT NULL CHECK (stock >= 0),
    disponible        INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado         INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia       TEXT    NOT NULL
) STRICT;

SELECT 'esquema_sqlite' AS objeto, count(*) AS tablas
  FROM sqlite_master
 WHERE type = 'table'
   AND name IN ('producto_cache', 'pedido_borrador', 'item_borrador', 'cola_sync',
                'snapshot_servidor', 'snapshot_raw');