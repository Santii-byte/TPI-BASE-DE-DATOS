# TP 6 — Parte 2: Consulta con desnormalización controlada

**Food Store — Top 5 de categorías por monto vendido en el día**

- **Integrantes:** Franco Rios y Santino Barone
- **Motor:** PostgreSQL 17 (Windows, ejecución local)
- **Entregable principal:** `tp_desnormalizacion_top_categorias.sql`

---

## Instancia utilizada

La Parte 2 se validó de dos formas complementarias:

1. **Sobre la base canónica acumulada de los TP anteriores (TP2–TP5, esquema `public`).** Es la validación principal, porque demuestra que la desnormalización se integra con el modelo real del proyecto y no con un esquema paralelo.
2. **Sobre un laboratorio reproducible aislado (esquema `tp6_p2`).** Sirve para volver a medir desde cero con datos generados de forma determinística.

### Instancia canónica (TP2–TP5)

Se partió de la base creada con `TP2_Concurrencia/Script.sql` y poblada con `TP3/carga_masiva.sql` (20.000 clientes, 50.000 productos, 200.000 pedidos, 400.000 detalles). Luego se aplicó la migración `00_migracion_esquema_tp5.sql`, que **extiende** el esquema existente sin recrearlo, y el refuerzo de volumen `03b_poblado_pico_hoy.sql` para simular el pico del día:

| Tabla | Filas |
|---|---:|
| `categoria` | 60 |
| `cliente` | 20.000 |
| `producto` | 50.000 |
| `pedido` | 300.000 |
| `pedido` de hoy | 100.215 |
| `detalle_pedido` | ~800.000 |
| `detalle_pedido` de hoy | 400.435 |

La migración respeta las definiciones previas: `pedido.fecha` sigue siendo `TIMESTAMPTZ`, `detalle_pedido` conserva su FK `ON DELETE CASCADE`, y no se elimina ni renombra ninguna tabla, columna, tipo o índice de TP2/TP5. Solo agrega `categoria`, `producto.categoria_id`, `producto.eliminado`, `pedido.eliminado`, `detalle_pedido.eliminado` y `detalle_pedido.subtotal`.

### Laboratorio reproducible (`tp6_p2`)

| Tabla | Filas |
|---|---:|
| `categoria` | 60 |
| `cliente` | 20.000 |
| `producto` | 30.000 |
| `pedido` | 300.000 |
| `pedido` de hoy | 119.814 |
| `detalle_pedido` | 1.199.919 |

El esquema base del laboratorio está en `01_esquema_base.sql` y el poblado reproducible (con `setseed`) en `02_poblado.sql`.

> `subtotal` se define como `GENERATED ALWAYS AS (cantidad * precio_unitario) STORED`. No es la desnormalización del TP: es el valor que ya usa la consulta original y no introduce riesgo de desincronización porque lo calcula el motor.

> **Diferencia de fecha entre ambos entornos:** en el laboratorio `pedido.fecha` es `DATE` (`pedido.fecha = CURRENT_DATE`); en la base canónica es `TIMESTAMPTZ` y el filtro "hoy" se expresa como rango `pedido.fecha >= CURRENT_DATE AND pedido.fecha < CURRENT_DATE + 1`. El resultado es equivalente y evita un índice funcional sobre `fecha::date`, que PostgreSQL no acepta como `IMMUTABLE`.

---

## a) EXPLAIN ANALYZE de la consulta original

Consulta ejecutada en el laboratorio (idéntica a la del enunciado, con `pedido.fecha DATE`):

```sql
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
```

En la base canónica la misma consulta usa el rango de día porque `fecha` es `TIMESTAMPTZ`:

```sql
WHERE ped.fecha >= CURRENT_DATE
  AND ped.fecha < CURRENT_DATE + 1
```

Se ejecutó tres veces con caché caliente en cada entorno.

**Laboratorio (`tp6_p2`):**

| Corrida | Execution Time |
|---|---:|
| 1 | 324,456 ms |
| 2 | 289,556 ms |
| 3 | 286,463 ms |

**Mediana: 289,556 ms.**

**Base canónica (TP2–TP5):**

| Corrida | Execution Time |
|---|---:|
| 1 | 226,875 ms |
| 2 | 244,707 ms |
| 3 | 279,576 ms |

**Mediana: 244,707 ms.**

Fragmento representativo del plan (corrida 2):

```text
Limit (actual time=273.263..289.170 rows=5 loops=1)
  ->  Sort  (actual time=273.261..289.166 rows=5 loops=1)
        Sort Method: top-N heapsort  Memory: 25kB
        ->  Finalize GroupAggregate  (actual time=273.151..289.135 rows=60 loops=1)
              ->  Gather Merge  (Workers Launched: 2)
                    ->  Partial HashAggregate  (actual time=249.827..249.844 rows=60 loops=3)
                          ->  Hash Join  (actual time=36.679..219.185 rows=139.387 loops=3)
                                ->  Hash Join  (actual time=36.185..200.469 rows=139.387 loops=3)
                                      ->  Parallel Hash Join  (actual time=26.704..152.102 rows=139.387 loops=3)
                                            ->  Parallel Seq Scan on detalle_pedido dp
                                                  (actual time=0.777..49.793 rows=368.000 loops=3)
                                                  Filter: (NOT eliminado)
                                            ->  Parallel Hash  (rows=37.907 loops=3)
                                                  ->  Parallel Seq Scan on pedido ped
                                                        Filter: ((NOT eliminado) AND (fecha = CURRENT_DATE))
                                      ->  Hash  (rows=30.000 loops=3)
                                            ->  Seq Scan on producto pr
                                ->  Hash  (rows=60 loops=3)
                                      ->  Seq Scan on categoria c
Execution Time: 289.556 ms
```

**Nodo que domina el costo:** el `Parallel Hash Join` que une `detalle_pedido` con `pedido` (y encadena los joins con `producto` y `categoria`), alimentado por el `Parallel Seq Scan` de `detalle_pedido`. Se procesan 1.104.000 filas visibles de detalle (368.000 por worker × 3) para terminar produciendo solo 60 grupos. El `Sort` final no es el problema: ordena 60 filas y usa 25 kB de memoria.

El plan completo está en `resultados/antes_run2.txt` (laboratorio) y `resultados/tp5_antes_run2.txt` (base canónica). El resultado funcional del laboratorio es:

| Categoría | Total vendido |
|---|---:|
| Categoría 36 | 64.342.270,62 |
| Categoría 01 | 62.851.384,37 |
| Categoría 05 | 61.870.718,70 |
| Categoría 22 | 61.288.080,44 |
| Categoría 56 | 61.014.674,18 |

---

## b) Patrón elegido y justificación

Se elige una **tabla de resumen pre-calculada mantenida por disparadores** (`resumen_venta_categoria_dia`), en lugar de una vista materializada. La evidencia de (a) es que la consulta tarda 289,6 ms y su costo está dominado por recorrer y unir 1,1 millón de renglones de detalle para producir apenas 60 grupos y 5 filas; una vista materializada obligaría a repetir ese mismo recorrido completo en cada `REFRESH` para mantenerse al día, y sin refresco frecuente quedaría desactualizada, algo incompatible con un panel que exige actualización frecuente y en tiempo real. En cambio, el resumen por `(categoria_id, fecha)` se actualiza por delta en la misma transacción que modifica la fuente de verdad mediante disparadores sobre `detalle_pedido` (INSERT/UPDATE/DELETE), sobre `pedido` (cambios de `fecha` o `eliminado`) y sobre `producto` (cambio de `categoria_id`), usando un `UPDATE`/`INSERT ... ON CONFLICT` atómico que serializa las escrituras concurrentes sobre la misma celda. El dato redundante no puede desincronizarse silenciosamente: toda mutación pasa por los disparadores y, además, el script de auditoría recalcula la fuente completa y compara celda por celda. La desnormalización es **reversible sin pérdida**: la tabla de resumen contiene únicamente agregados derivados; la fuente de verdad (`detalle_pedido`, `pedido`, `producto`, `categoria`) permanece intacta, por lo que basta eliminar los disparadores y la tabla (`06_rollback.sql`) para volver al esquema original, y el resumen puede reconstruirse en cualquier momento con el backfill.

---

## c) Implementación

El script `tp_desnormalizacion_top_categorias.sql` contiene:

1. **Estructura desnormalizada:**

```sql
CREATE TABLE resumen_venta_categoria_dia (
    categoria_id  BIGINT NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT,
    fecha         DATE NOT NULL,
    total_vendido NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_vendido >= 0),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (categoria_id, fecha)
);
```

2. **Índice para el top-N:**

```sql
CREATE INDEX idx_resumen_fecha_total
    ON resumen_venta_categoria_dia (fecha, total_vendido DESC)
    INCLUDE (categoria_id);
```

3. **Sincronización por disparadores:**
   - `fn_detalle_pedido_resumen`: aplica `-OLD.subtotal` y `+NEW.subtotal` según corresponda; contempla cantidad, precio, producto y soft-delete del renglón.
   - `fn_pedido_resumen`: si cambia `fecha` o `eliminado`, resta la contribución anterior y suma la nueva de todos los renglones del pedido.
   - `fn_pedido_delete_resumen`: `BEFORE DELETE` sobre `pedido`. Resta la contribución del pedido antes del borrado físico y evita que el `ON DELETE CASCADE` de `detalle_pedido`, propio del esquema TP2/TP5, la reste dos veces. El trigger de detalle detecta que el pedido ya no existe y omite el segundo ajuste.
   - `fn_producto_resumen`: si cambia `categoria_id`, mueve todo el histórico del producto entre categorías.
   - `fn_resumen_aplicar`: actualización atómica de la celda, con `UPDATE` primero para no violar el `CHECK` cuando el delta es negativo, y `INSERT ... ON CONFLICT` para altas concurrentes.

4. **Backfill inicial** desde la fuente de verdad.

5. **Consulta del panel (d)** y **auditoría (e)**.

El entregable es **agnóstico al esquema**: no fija el `search_path`. Se ejecuta con un wrapper que lo orienta:

- `00_ejecutar_tp5.sql` → `SET search_path TO public; \ir tp_desnormalizacion_top_categorias.sql` sobre la base canónica.
- `00_ejecutar_laboratorio.sql` → `SET search_path TO tp6_p2, public; \ir ...` sobre el laboratorio.

La migración `00_migracion_esquema_tp5.sql` es la que prepara la base canónica para este TP sin reemplazar el esquema de TP2/TP5.

---

## d) Consulta sobre la estructura desnormalizada y comparación

```sql
SELECT c.nombre AS categoria,
       r.total_vendido
  FROM resumen_venta_categoria_dia AS r
  JOIN categoria AS c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;
```

Se ejecutó tres veces con `EXPLAIN (ANALYZE, BUFFERS)`.

**Laboratorio (`tp6_p2`):**

| Corrida | Execution Time |
|---|---:|
| 1 | 0,280 ms |
| 2 | 0,239 ms |
| 3 | 0,176 ms |

**Mediana: 0,239 ms.**

**Base canónica (TP2–TP5):**

| Corrida | Execution Time |
|---|---:|
| 1 | 0,208 ms |
| 2 | 0,183 ms |
| 3 | 0,151 ms |

**Mediana: 0,183 ms.**

Plan representativo (corrida 2):

```text
Limit (actual time=0.160..0.181 rows=5 loops=1)
  ->  Nested Loop (actual time=0.157..0.178 rows=5 loops=1)
        ->  Index Only Scan using idx_resumen_fecha_total
              on resumen_venta_categoria_dia r
              (actual time=0.129..0.142 rows=5 loops=1)
              Index Cond: (fecha = CURRENT_DATE)
              Heap Fetches: 3
        ->  Memoize (actual time=0.006..0.006 rows=1 loops=5)
              ->  Index Scan using categoria_pkey on categoria c
                    Index Cond: (id = r.categoria_id)
Execution Time: 0.239 ms
```

### Tabla comparativa antes / después

| Entorno | Antes (fuente normalizada) | Después (resumen) | Mejora |
|---|---:|---:|---:|
| Base canónica TP2–TP5 | **244,707 ms** | **0,183 ms** | **~1.337×** |
| Laboratorio `tp6_p2` | **289,556 ms** | **0,239 ms** | **~1.212×** |

| Métrica | Antes | Después |
|---|---|---|
| Nodo dominante | `Parallel Hash Join` + `Parallel Seq Scan` sobre `detalle_pedido` | `Index Only Scan` sobre `idx_resumen_fecha_total` + `Nested Loop`/`Memoize` con `categoria_pkey` |
| Filas recorridas (canónica) | ~400.000 detalles de hoy + 300.000 pedidos + 50.000 productos | 5 entradas del índice + 5 búsquedas por clave de categoría |

La consulta desnormalizada devuelve exactamente el mismo top 5 y los mismos totales que la consulta original en ambos entornos. Los planes completos están en `resultados/despues_run2.txt` (laboratorio) y `resultados/tp5_despues_run2.txt` (canónica).

> **Sobre el join con `categoria`:** el resumen guarda `categoria_id`, no el nombre, para no introducir una segunda redundancia sensible a cambios (un `UPDATE` de nombre obligaría a otro disparador y otro riesgo de desincronización). El join es contra una tabla de 60 filas y se resuelve con un `Index Scan` sobre la PK; no recorre ninguna de las tres tablas pesadas de la consulta original.

---

## e) Auditoría de desincronización

El script `07_auditoria.sql` (laboratorio) y `07b_auditoria_tp5.sql` (base canónica) —ambos incluidos también en el entregable principal— recalculan la fuente de verdad y la comparan contra el resumen con un `FULL OUTER JOIN`:

```sql
WITH fuente AS (
    SELECT pr.categoria_id, p.fecha,
           SUM(dp.subtotal)::NUMERIC(14, 2) AS total_vendido
      FROM detalle_pedido dp
      JOIN pedido p     ON p.id = dp.pedido_id
      JOIN producto pr  ON pr.id = dp.producto_id
     WHERE dp.eliminado = FALSE
       AND p.eliminado = FALSE
     GROUP BY pr.categoria_id, p.fecha
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
  FROM fuente f
  FULL OUTER JOIN resumen r
    ON r.categoria_id = f.categoria_id
   AND r.fecha = f.fecha
 WHERE f.total_vendido IS DISTINCT FROM r.total_vendido;
```

**Resultado sobre la base migrada:** 0 filas en ambos entornos (`resultados/auditoria.txt` y `resultados/tp5_auditoria.txt`).

```text
 categoria_id | fecha | total_fuente | total_resumen | problema
--------------+-------+--------------+---------------+----------
(0 filas)
```

Control global adicional:

```text
 suma_global_coincide
----------------------
 t
```

El script detecta los tres casos posibles: fila faltante en el resumen, fila sobrante y total distinto. Además, `05_prueba_sincronizacion.sql` (laboratorio) y `05b_prueba_sincronizacion_tp5.sql` (canónica) ejecutan 9 mutaciones dentro de una transacción (INSERT, UPDATE de cantidad, cambio de fecha de pedido, cambio de categoría de producto, soft-delete y restauración de detalle, DELETE físico, soft-delete y restauración de pedido) y verifican después de cada una que la auditoría siga vacía; el resultado fue en ambos casos:

```text
NOTICE: Prueba de sincronización OK: 9 mutaciones verificadas, 0 desincronizaciones.
```

---

## Reversibilidad y trade-off

La desnormalización es reversible: `06_rollback.sql` elimina únicamente el resumen, sus índices, funciones y disparadores. La fuente de verdad no se modifica, por lo que la información original se conserva y la consulta normalizada sigue funcionando.

El costo del patrón es el overhead de escritura: cada cambio en `detalle_pedido` ejecuta un disparador `FOR EACH ROW` que actualiza una celda del resumen; los cambios de pedido o de categoría de producto hacen un procesamiento por conjunto sobre los renglones afectados. Ese costo es acotado y se paga en escrituras, a cambio de eliminar por completo el costo de lectura del panel. Si el panel dejara de necesitar actualización en tiempo real, una vista materializada con refresco periódico sería una alternativa válida; con los requisitos actuales, la tabla con disparadores es la opción que mejor equilibra frescura y latencia.

---

## Archivos y orden de ejecución

```text
TP6/
├── tp_fnbc_control_lote.sql                  # Parte 1 (entregable)
├── tp_desnormalizacion_top_categorias.sql    # Parte 2 (entregable)
├── 00_migracion_esquema_tp5.sql              # extiende la base canónica TP2–TP5
├── 00_ejecutar_tp5.sql                       # wrapper: search_path public + entregable
├── 00_ejecutar_laboratorio.sql               # wrapper: search_path tp6_p2 + entregable
├── 01_esquema_base.sql                       # laboratorio: esquema Food Store
├── 02_poblado.sql                            # laboratorio: datos reproducibles
├── 03_consulta_antes.sql                     # laboratorio: EXPLAIN ANALYZE antes
├── 03b_poblado_pico_hoy.sql                  # canónica: refuerzo de volumen del día
├── 03c_consulta_antes_tp5.sql                # canónica: EXPLAIN ANALYZE antes
├── 04_consulta_despues.sql                   # laboratorio: EXPLAIN ANALYZE después
├── 04b_consulta_despues_tp5.sql              # canónica: EXPLAIN ANALYZE después
├── 05_prueba_sincronizacion.sql              # laboratorio: 9 mutaciones + ROLLBACK
├── 05b_prueba_sincronizacion_tp5.sql         # canónica: 9 mutaciones + ROLLBACK
├── 06_rollback.sql                           # reversión sin pérdida (ambos entornos)
├── 07_auditoria.sql                          # laboratorio: auditoría independiente
├── 07b_auditoria_tp5.sql                     # canónica: auditoría independiente
├── informe_fnbc.md                           # informe Parte 1
├── informe_parte2.md                         # este informe
├── informe_tp6.md                            # informe completo Parte 1 + Parte 2
├── README.md
├── cambios/                                  # declaraciones DUIA
└── resultados/
    ├── antes_run1..3.txt / despues_run1..3.txt
    ├── tp5_antes_run1..3.txt / tp5_despues_run1..3.txt
    ├── auditoria.txt / tp5_auditoria.txt
    └── prueba_sincronizacion.txt / tp5_prueba_sincronizacion.txt
```

### Sobre la base canónica acumulada (recomendado)

```bash
# 1. Copia de trabajo con el esquema y los datos de TP2/TP3 ya cargados
psql -d copia_trabajo -f TP6/00_migracion_esquema_tp5.sql
psql -d copia_trabajo -f TP6/03b_poblado_pico_hoy.sql
psql -d copia_trabajo -f TP6/03c_consulta_antes_tp5.sql
psql -d copia_trabajo -f TP6/00_ejecutar_tp5.sql       # entregable Parte 2
psql -d copia_trabajo -f TP6/04b_consulta_despues_tp5.sql
psql -d copia_trabajo -f TP6/07b_auditoria_tp5.sql
psql -d copia_trabajo -f TP6/05b_prueba_sincronizacion_tp5.sql
```

### Laboratorio reproducible aislado

```bash
psql -d copia_trabajo -f TP6/01_esquema_base.sql
psql -d copia_trabajo -f TP6/02_poblado.sql
psql -d copia_trabajo -f TP6/03_consulta_antes.sql
psql -d copia_trabajo -f TP6/00_ejecutar_laboratorio.sql
psql -d copia_trabajo -f TP6/04_consulta_despues.sql
psql -d copia_trabajo -f TP6/07_auditoria.sql
```
