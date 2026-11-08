# Verificación de equivalencia de la anonimización (Parte D)

- **Script de anonimización:** `sql/usuario_anon.sql`.
- **Consultas:** `sql/consultas_equivalencia.sql`.
- **Salida completa:** `docs/resultados_equivalencia.txt`.
- **Filas:** 6000 en `usuario` y 6000 en `usuario_anon`.
- **Agrupamientos:** 5 roles × 12 meses = 60 celdas.

---

## 1. Criterio de anonimización

`usuario_anon` conserva:

- `id` (para mantener la cardinalidad y la relación con otras tablas),
- `rol`,
- `activo`,
- `created_at` (necesario para agrupar por mes de alta).

`usuario_anon` reemplaza:

- `email` → `anon<id>@example.test`,
- `nombre` → `Persona Anónima <id>`,
- `password_hash` → `anon-<md5(id)>` (valor inútil, no reversible al hash real),
- `ultimo_acceso` → `NULL` (evita exponer hábitos de uso).

El mapeo es determinista: el mismo `id` produce siempre el mismo email, nombre y
hash sintético. No se usa `random()`.

## 2. Consultas generadas

### 2.1 Consulta sobre `usuario_anon`

```sql
SELECT rol,
       date_trunc('month', created_at)::date AS mes_alta,
       count(*) AS cantidad
  FROM usuario_anon
 GROUP BY rol, date_trunc('month', created_at)
 ORDER BY mes_alta, rol;
```

### 2.2 Consulta equivalente sobre `usuario`

```sql
SELECT rol,
       date_trunc('month', created_at)::date AS mes_alta,
       count(*) AS cantidad
  FROM usuario
 GROUP BY rol, date_trunc('month', created_at)
 ORDER BY mes_alta, rol;
```

## 3. Evidencia de equivalencia

### 3.1 Comparación lado a lado por celda

La siguiente consulta une ambos agregados por `(rol, mes_alta)` y muestra
únicamente las diferencias. Debe devolver **0 filas**:

```sql
WITH agregado_anon AS (
    SELECT rol, date_trunc('month', created_at)::date AS mes_alta, count(*) AS cantidad
      FROM usuario_anon
     GROUP BY rol, date_trunc('month', created_at)
),
agregado_real AS (
    SELECT rol, date_trunc('month', created_at)::date AS mes_alta, count(*) AS cantidad
      FROM usuario
     GROUP BY rol, date_trunc('month', created_at)
)
SELECT COALESCE(a.rol, r.rol)             AS rol,
       COALESCE(a.mes_alta, r.mes_alta)   AS mes_alta,
       a.cantidad                         AS cantidad_anon,
       r.cantidad                         AS cantidad_real
  FROM agregado_anon AS a
  FULL OUTER JOIN agregado_real AS r
    ON r.rol = a.rol
   AND r.mes_alta = a.mes_alta
 WHERE a.cantidad IS DISTINCT FROM r.cantidad
 ORDER BY mes_alta, rol;
```

Resultado: **0 filas**.

```text
 rol | mes_alta | cantidad_anon | cantidad_real
-----+----------+---------------+---------------
(0 filas)
```

### 3.2 Totales por rol (lado a lado)

| Rol | `usuario_anon` | `usuario` |
|---|---:|---:|
| `admin_datos` | 1200 | 1200 |
| `analista_ventas` | 1201 | 1201 |
| `auditor_seguridad` | 1200 | 1200 |
| `operador_ventas` | 1199 | 1199 |
| `soporte_cliente` | 1200 | 1200 |
| **Total** | **6000** | **6000** |

### 3.3 Totales por mes de alta (lado a lado)

| Mes de alta | `usuario_anon` | `usuario` |
|---|---:|---:|
| 2025-12-01 | 500 | 500 |
| 2026-01-01 | 500 | 500 |
| 2026-02-01 | 500 | 500 |
| 2026-03-01 | 500 | 500 |
| 2026-04-01 | 500 | 500 |
| 2026-05-01 | 500 | 500 |
| 2026-06-01 | 500 | 500 |
| 2026-07-01 | 500 | 500 |
| 2026-08-01 | 500 | 500 |
| 2026-09-01 | 500 | 500 |
| 2026-10-01 | 500 | 500 |
| 2026-11-01 | 500 | 500 |
| **Total** | **6000** | **6000** |

La salida completa con las 60 filas de cada consulta está en
`docs/resultados_equivalencia.txt`.

## 4. Qué información no debería salir sin anonimizar

No deberían enviarse a un asistente de IA, sin pasar antes por este proceso,
los emails, nombres, teléfonos, direcciones, documentos, historiales de compra,
fechas de alta individuales, hashes de contraseña ni datos de pago de clientes o
usuarios de Food Store. Tampoco deberían salir logs crudos con literales SQL,
porque pueden contener esos mismos datos y contraseñas. Solo deberían salir
agregados, identificadores sintéticos o muestras anonimizadas de forma
determinista y verificada.
