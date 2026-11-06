-- ============================================================================
-- TP 6 — Desnormalización / Forma Normal de Boyce-Codd (FNBC)
-- Food Store — Control de lotes por depósito
-- PostgreSQL 16+
-- ============================================================================
-- Esquema original:
--   control_lote_almacen (LoteID, DepositoID, ResponsableControlID)
--   PK (LoteID, DepositoID)
--
-- Dependencias funcionales:
--   FD1: {LoteID, DepositoID}        -> ResponsableControlID
--   FD2: {ResponsableControlID}      -> DepositoID
--
-- FD2 viola FNBC porque su determinante (ResponsableControlID) no es
-- superclave. La descomposición sin pérdida es:
--   R1 (ResponsableControlID, DepositoID)   PK: ResponsableControlID
--   R2 (LoteID, ResponsableControlID)       PK: (LoteID, ResponsableControlID)
--
-- El script es autocontenido: crea un esquema aislado `tp6_fnbc` con las
-- tablas maestras mínimas asumidas (lote, deposito, usuario), de modo que
-- puede ejecutarse repetidamente sin tocar el resto de la base Food Store.
-- Para inspeccionar sin persistir cambios, reemplazar COMMIT por ROLLBACK.
-- ============================================================================

BEGIN;

DROP SCHEMA IF EXISTS tp6_fnbc CASCADE;
CREATE SCHEMA tp6_fnbc;
SET LOCAL search_path TO tp6_fnbc, public;

-- ============================================================================
-- 0. TABLAS MAESTRAS ASUMIDAS (stubs mínimos para poder ejecutar el TP)
-- ============================================================================
CREATE TABLE lote (
    id          BIGINT PRIMARY KEY,
    descripcion TEXT NOT NULL
);

CREATE TABLE deposito (
    id     BIGINT PRIMARY KEY,
    nombre TEXT NOT NULL
);

CREATE TABLE usuario (
    id     BIGINT PRIMARY KEY,
    nombre TEXT NOT NULL
);

INSERT INTO lote (id, descripcion) VALUES
    (501, 'Lote 501'),
    (502, 'Lote 502'),
    (503, 'Lote 503');

INSERT INTO deposito (id, nombre) VALUES
    (30, 'Depósito Central'),
    (31, 'Depósito Norte');

INSERT INTO usuario (id, nombre) VALUES
    (801, 'Responsable 801'),
    (802, 'Responsable 802');

-- ============================================================================
-- 1. ESQUEMA ORIGINAL (con la instancia de ejemplo de la consigna)
-- ============================================================================
CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id) VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- ============================================================================
-- 2. VERIFICACIÓN PREVIA: FD2 debe cumplirse en los datos de origen
--    (un responsable no puede pertenecer a más de un depósito)
-- ============================================================================
DO $$
DECLARE
    v_responsables_inconsistentes BIGINT;
BEGIN
    SELECT count(*)
      INTO v_responsables_inconsistentes
      FROM (
            SELECT responsable_control_id
              FROM control_lote_almacen
             GROUP BY responsable_control_id
            HAVING count(DISTINCT deposito_id) > 1
           ) AS inconsistentes;

    IF v_responsables_inconsistentes > 0 THEN
        RAISE EXCEPTION
            'Migración abortada: % responsable(s) de control pertenecen a más de un depósito (viola FD2).',
            v_responsables_inconsistentes;
    END IF;

    RAISE NOTICE 'Verificación FD2 OK: cada responsable pertenece a un único depósito.';
END $$;

-- ============================================================================
-- 3. TABLAS RESULTANTES DE LA DESCOMPOSICIÓN EN FNBC
-- ============================================================================

-- R1(ResponsableControlID, DepositoID)
-- Aquí se materializa FD2: ResponsableControlID -> DepositoID.
CREATE TABLE responsable_control (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

-- R2(LoteID, ResponsableControlID)
-- La clave es (LoteID, ResponsableControlID); ya no contiene DepositoID.
CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_control(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- ============================================================================
-- 4. MIGRACIÓN DE DATOS DESDE EL ESQUEMA ORIGINAL
-- ============================================================================

-- R1: una fila por responsable (DISTINCT elimina la redundancia de 801).
INSERT INTO responsable_control (responsable_control_id, deposito_id)
SELECT DISTINCT
       responsable_control_id,
       deposito_id
  FROM control_lote_almacen;

-- R2: una fila por par (lote, responsable).
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id,
       responsable_control_id
  FROM control_lote_almacen;

-- ============================================================================
-- 5. VISTA DE COMPATIBILIDAD: reconstruye la relación original mediante
--    reunión natural por el atributo común ResponsableControlID.
-- ============================================================================
CREATE VIEW control_lote_almacen_compat AS
SELECT c.lote_id,
       r.deposito_id,
       c.responsable_control_id
  FROM control_lote AS c
  NATURAL JOIN responsable_control AS r;

-- ============================================================================
-- 6. VERIFICACIÓN DE EQUIVALENCIA
-- ============================================================================

-- 6.1. Cardinalidades: 3 filas originales -> 2 en R1 + 3 en R2.
SELECT 'control_lote_almacen' AS relacion, count(*) AS filas
  FROM control_lote_almacen
UNION ALL
SELECT 'responsable_control', count(*)
  FROM responsable_control
UNION ALL
SELECT 'control_lote', count(*)
  FROM control_lote
UNION ALL
SELECT 'control_lote_almacen_compat', count(*)
  FROM control_lote_almacen_compat;

-- 6.2. Contenido reconstruido por la vista (debe ser idéntico al original).
SELECT lote_id, deposito_id, responsable_control_id
  FROM control_lote_almacen_compat
 ORDER BY lote_id, deposito_id;

-- 6.3. Diferencia simétrica: ambas consultas deben devolver 0 filas.
WITH solo_original AS (
    SELECT lote_id, deposito_id, responsable_control_id
      FROM control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
      FROM control_lote_almacen_compat
),
solo_vista AS (
    SELECT lote_id, deposito_id, responsable_control_id
      FROM control_lote_almacen_compat
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
      FROM control_lote_almacen
)
SELECT 'solo_en_original' AS diferencia, count(*) AS filas FROM solo_original
UNION ALL
SELECT 'solo_en_vista', count(*) FROM solo_vista;

-- 6.4. Aserción automática: si la reunión no es equivalente, aborta.
DO $$
DECLARE
    v_diferencia BIGINT;
BEGIN
    -- Se cuentan por separado para no depender de UNION con tipos distintos.
    SELECT (SELECT count(*) FROM (
                SELECT lote_id, deposito_id, responsable_control_id
                  FROM control_lote_almacen
                EXCEPT
                SELECT lote_id, deposito_id, responsable_control_id
                  FROM control_lote_almacen_compat
            ) AS a)
         + (SELECT count(*) FROM (
                SELECT lote_id, deposito_id, responsable_control_id
                  FROM control_lote_almacen_compat
                EXCEPT
                SELECT lote_id, deposito_id, responsable_control_id
                  FROM control_lote_almacen
            ) AS b)
      INTO v_diferencia;

    IF v_diferencia <> 0 THEN
        RAISE EXCEPTION
            'La vista de compatibilidad NO reconstruye la relación original: % fila(s) de diferencia.',
            v_diferencia;
    END IF;

    RAISE NOTICE 'Verificación OK: la reunión natural reconstruye exactamente las 3 filas originales.';
END $$;

COMMIT;

-- ============================================================================
-- 7. CONSULTAS DE CONTROL POST-EJECUCIÓN (fuera de la transacción)
-- ============================================================================
-- SELECT * FROM tp6_fnbc.control_lote_almacen_compat ORDER BY lote_id, deposito_id;
-- SELECT * FROM tp6_fnbc.responsable_control ORDER BY responsable_control_id;
-- SELECT * FROM tp6_fnbc.control_lote ORDER BY lote_id;
--
-- NOTA: la descomposición es sin pérdida (lossless join) y elimina la
-- redundancia de FD2, pero no preserva como restricción local la unicidad
-- original de (LoteID, DepositoID). Ver justificación en informe_fnbc.md.
