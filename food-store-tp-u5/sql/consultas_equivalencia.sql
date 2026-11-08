-- ============================================================================
-- Food Store — TP Unidad 5
-- consultas_equivalencia.sql — Parte D
-- ============================================================================
-- Ejecutar como superusuario:
--   psql -d foodstore_u5 -f sql/consultas_equivalencia.sql
-- ============================================================================

\pset pager off
\pset border 2

\echo '=== A. Consulta de agregación sobre usuario_anon ==='
SELECT rol,
       date_trunc('month', created_at)::date AS mes_alta,
       count(*) AS cantidad
  FROM usuario_anon
 GROUP BY rol, date_trunc('month', created_at)
 ORDER BY mes_alta, rol;

\echo '=== B. Consulta equivalente sobre usuario (tabla real) ==='
SELECT rol,
       date_trunc('month', created_at)::date AS mes_alta,
       count(*) AS cantidad
  FROM usuario
 GROUP BY rol, date_trunc('month', created_at)
 ORDER BY mes_alta, rol;

\echo '=== C. Comparación lado a lado (debe devolver 0 filas) ==='
WITH agregado_anon AS (
    SELECT rol,
           date_trunc('month', created_at)::date AS mes_alta,
           count(*) AS cantidad
      FROM usuario_anon
     GROUP BY rol, date_trunc('month', created_at)
),
agregado_real AS (
    SELECT rol,
           date_trunc('month', created_at)::date AS mes_alta,
           count(*) AS cantidad
      FROM usuario
     GROUP BY rol, date_trunc('month', created_at)
)
SELECT COALESCE(a.rol, r.rol)         AS rol,
       COALESCE(a.mes_alta, r.mes_alta) AS mes_alta,
       a.cantidad                     AS cantidad_anon,
       r.cantidad                     AS cantidad_real
  FROM agregado_anon AS a
  FULL OUTER JOIN agregado_real AS r
    ON r.rol = a.rol
   AND r.mes_alta = a.mes_alta
 WHERE a.cantidad IS DISTINCT FROM r.cantidad
 ORDER BY mes_alta, rol;

\echo '=== D. Totales por rol (lado a lado) ==='
WITH anon AS (
    SELECT rol, count(*) AS cantidad FROM usuario_anon GROUP BY rol
),
real AS (
    SELECT rol, count(*) AS cantidad FROM usuario GROUP BY rol
)
SELECT COALESCE(a.rol, r.rol) AS rol,
       a.cantidad AS cantidad_anon,
       r.cantidad AS cantidad_real
  FROM anon AS a
  FULL OUTER JOIN real AS r ON r.rol = a.rol
 ORDER BY rol;

\echo '=== E. Totales por mes (lado a lado) ==='
WITH anon AS (
    SELECT date_trunc('month', created_at)::date AS mes_alta,
           count(*) AS cantidad
      FROM usuario_anon
     GROUP BY 1
),
real AS (
    SELECT date_trunc('month', created_at)::date AS mes_alta,
           count(*) AS cantidad
      FROM usuario
     GROUP BY 1
)
SELECT COALESCE(a.mes_alta, r.mes_alta) AS mes_alta,
       a.cantidad AS cantidad_anon,
       r.cantidad AS cantidad_real
  FROM anon AS a
  FULL OUTER JOIN real AS r ON r.mes_alta = a.mes_alta
 ORDER BY mes_alta;
