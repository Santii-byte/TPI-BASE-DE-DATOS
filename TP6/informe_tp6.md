# TP 6 — Informe completo: FNBC y desnormalización controlada

**Food Store — Base de Datos II**

- **Integrantes:** Franco Rios y Santino Barone
- **Motor:** PostgreSQL 17
- **Parte 1:** `tp_fnbc_control_lote.sql` + `informe_fnbc.md`
- **Parte 2:** `tp_desnormalizacion_top_categorias.sql` + `informe_parte2.md`

---

# Parte 1 — FNBC sobre `control_lote_almacen`

## 1. Esquema y reglas de negocio

```text
R = control_lote_almacen (LoteID, DepositoID, ResponsableControlID)
PK = (LoteID, DepositoID)
```

Reglas:

1. Para un lote y un depósito dados, el responsable queda unívocamente determinado.
2. Cada responsable pertenece a un único depósito.

## 2. Dependencias funcionales

```text
FD1: {LoteID, DepositoID} → ResponsableControlID
FD2: ResponsableControlID → DepositoID
```

Con abreviaturas `L = LoteID`, `D = DepositoID`, `R = ResponsableControlID`:

```text
F = { LD → R, R → D }
```

## 3. Clausuras y claves candidatas

| `X` | `X⁺` | ¿Superclave? |
|---|---|---|
| `{L}` | `{L}` | No |
| `{D}` | `{D}` | No |
| `{R}` | `{R, D}` | No |
| `{L, D}` | `{L, D, R}` | Sí |
| `{L, R}` | `{L, R, D}` | Sí |
| `{D, R}` | `{D, R}` | No |
| `{L, D, R}` | `{L, D, R}` | Sí, no minimal |

**Claves candidatas:**

```text
{ {LoteID, DepositoID}, {LoteID, ResponsableControlID} }
```

**Atributos primos:** `LoteID`, `DepositoID`, `ResponsableControlID`.
**Atributos no primos:** ninguno.

## 4. Demostración de violación de FNBC

Definición formal: para toda dependencia no trivial `X → Y` de `F⁺`, `X` debe ser superclave.

- `{L, D} → R`: `{L, D}⁺ = {L, D, R}` → `{L, D}` es superclave. **Cumple.**
- `R → D`: `R⁺ = {R, D} ≠ {L, D, R}` → `R` **no es superclave**. **Viola FNBC.**

Por lo tanto, `control_lote_almacen` **no está en FNBC**. La dependencia violatoria es `ResponsableControlID → DepositoID`.

La relación sí está en 3FN porque todos los atributos son primos; es el caso clásico de 3FN sin FNBC.

## 5. Anomalías habilitadas

- **Inserción:** no se puede registrar que el responsable `803` pertenece al depósito `30` si todavía no tiene un lote asignado, porque la PK `(LoteID, DepositoID)` y los `NOT NULL` obligan a inventar un lote; si se lo asigna, se repite el depósito `30`.
- **Borrado:** al eliminar `(503, 31, 802)` se pierde la única fila que registra que `802` pertenece al depósito `31`.
- **Actualización:** si `801` pasa del depósito `30` al `32`, hay que actualizar las filas de `501` y `502`; una actualización parcial deja a `801` en dos depósitos.

## 6. Descomposición sin pérdida

```text
R1 = (ResponsableControlID, DepositoID)   PK: ResponsableControlID
R2 = (LoteID, ResponsableControlID)       PK: (LoteID, ResponsableControlID)
```

- `R1` cumple FNBC: `R → D` y `R` es su clave.
- `R2` cumple FNBC: la clave `{L, R}` determina todos sus atributos y no quedan dependencias no triviales proyectadas.

**Justificación de la reunión sin pérdida:** `R1 ∩ R2 = {ResponsableControlID}`, y ese atributo es superclave (clave primaria) de `R1`. Por el teorema de reunión sin pérdida, la reunión natural de `R1` y `R2` recupera exactamente `R` sin tuplas espurias.

**Migración de la instancia:**

| R1: ResponsableControlID | DepositoID |
|---:|---:|
| 801 | 30 |
| 802 | 31 |

| R2: LoteID | ResponsableControlID |
|---:|---:|
| 501 | 801 |
| 502 | 801 |
| 503 | 802 |

La vista `control_lote_almacen_compat` (reunión natural) devuelve las tres filas originales. El script verifica con `EXCEPT` en ambos sentidos y con una aserción `DO` que aborta si hay diferencias.

**Limitación teórica:** la descomposición es sin pérdida, pero no preserva como restricción local la unicidad original `(LoteID, DepositoID)`. Se documenta en `informe_fnbc.md`.

---

# Parte 2 — Desnormalización controlada del top 5

## 7. Consulta original y medición (antes)

Consulta del panel (versión laboratorio, `pedido.fecha DATE`):

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

En la base canónica TP2–TP5 `pedido.fecha` es `TIMESTAMPTZ`; el filtro equivalente y compatible con índice es:

```sql
WHERE ped.fecha >= CURRENT_DATE
  AND ped.fecha < CURRENT_DATE + 1
```

La Parte 2 se midió sobre dos instancias:

- **Base canónica TP2–TP5 (validación principal):** esquema de `TP2_Concurrencia/Script.sql`, datos de `TP3/carga_masiva.sql` y refuerzo `03b_poblado_pico_hoy.sql`. Queda con 60 categorías, 20.000 clientes, 50.000 productos, 300.000 pedidos (100.215 de hoy), ~800.000 detalles totales y 400.435 detalles de hoy.
- **Laboratorio reproducible `tp6_p2`:** 60 categorías, 20.000 clientes, 30.000 productos, 300.000 pedidos (119.814 de hoy) y 1.199.919 renglones de detalle.

Tres corridas con caché caliente:

| Entorno | Corridas (ms) | Mediana |
|---|---|---:|
| Base canónica TP2–TP5 | 226,875 / 244,707 / 279,576 | **244,707 ms** |
| Laboratorio `tp6_p2` | 324,456 / 289,556 / 286,463 | **289,556 ms** |

Nodo dominante: el `Parallel Hash Join` que une `detalle_pedido` con `pedido` (y luego con `producto` y `categoria`), alimentado por el `Parallel Seq Scan` de `detalle_pedido`: se procesan cientos de miles de filas de detalle para producir 60 grupos. El `Sort` final solo ordena 60 filas (25 kB), por lo que no es el cuello de botella.

Plan representativo (laboratorio):

```text
Limit (actual time=273.263..289.170 rows=5 loops=1)
  ->  Sort  (actual time=273.261..289.166)  top-N heapsort 25kB
        ->  Finalize GroupAggregate (rows=60)
              ->  Gather Merge (Workers Launched: 2)
                    ->  Partial HashAggregate (rows=60 loops=3)
                          ->  Hash Join (actual time=36.679..219.185)
                                ->  Parallel Hash Join (actual time=26.704..152.102)
                                      ->  Parallel Seq Scan on detalle_pedido
                                            (actual time=0.777..49.793 rows=368.000 loops=3)
Execution Time: 289.556 ms
```

Captura completa: `resultados/antes_run2.txt` (laboratorio) y `resultados/tp5_antes_run2.txt` (canónica).

## 8. Patrón elegido y justificación

Se implementó una **tabla de resumen pre-calculada mantenida por disparadores**:

```sql
CREATE TABLE resumen_venta_categoria_dia (
    categoria_id  BIGINT NOT NULL REFERENCES categoria(id),
    fecha         DATE NOT NULL,
    total_vendido NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_vendido >= 0),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (categoria_id, fecha)
);
```

**Justificación (una síntesis):** la medición de 289,6 ms muestra que el costo está en recorrer y unir 1,1 millón de renglones para producir 60 grupos; una vista materializada requeriría repetir ese recorrido completo en cada `REFRESH` para mantenerse en tiempo real, mientras que el resumen por `(categoria_id, fecha)` se actualiza por delta en la misma transacción de cada cambio mediante disparadores sobre `detalle_pedido`, `pedido` y `producto`, usando un upsert atómico que evita desincronizaciones concurrentes. Es reversible sin pérdida porque solo se derivan agregados: la fuente de verdad queda intacta y el resumen puede recalcularse o eliminarse (`06_rollback.sql`).

## 9. Implementación de la sincronización

- **`fn_detalle_pedido_resumen`** (AFTER INSERT/UPDATE/DELETE en `detalle_pedido`): resta `OLD.subtotal` y suma `NEW.subtotal` cuando el renglón y el pedido están visibles; contempla cantidad, precio, producto y soft-delete.
- **`fn_pedido_resumen`** (AFTER UPDATE OF `fecha`, `eliminado` en `pedido`): mueve la contribución de todos los renglones del pedido al día nuevo o la quita si el pedido se elimina lógicamente.
- **`fn_pedido_delete_resumen`** (BEFORE DELETE en `pedido`): resta la contribución antes del borrado físico y evita el doble descuento que provocaría el `ON DELETE CASCADE` de `detalle_pedido` del esquema TP2/TP5.
- **`fn_producto_resumen`** (AFTER UPDATE OF `categoria_id` en `producto`): mueve todo el histórico del producto entre categorías.
- **`fn_resumen_aplicar`**: actualización atómica de la celda con `UPDATE` primero e `INSERT ... ON CONFLICT` para altas concurrentes; elimina celdas que quedan en cero.

El script no fija `search_path`; se ejecuta con `00_ejecutar_tp5.sql` (base canónica, `public`) o `00_ejecutar_laboratorio.sql` (laboratorio, `tp6_p2`).

## 10. Consulta desnormalizada y comparación (después)

```sql
SELECT c.nombre AS categoria,
       r.total_vendido
  FROM resumen_venta_categoria_dia AS r
  JOIN categoria AS c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;
```

Tres corridas:

| Entorno | Corridas (ms) | Mediana |
|---|---|---:|
| Base canónica TP2–TP5 | 0,208 / 0,183 / 0,151 | **0,183 ms** |
| Laboratorio `tp6_p2` | 0,280 / 0,239 / 0,176 | **0,239 ms** |

Plan representativo (laboratorio):

```text
Limit (actual time=0.160..0.181 rows=5 loops=1)
  ->  Nested Loop (actual time=0.157..0.178 rows=5 loops=1)
        ->  Index Only Scan using idx_resumen_fecha_total
              on resumen_venta_categoria_dia r
              (actual time=0.129..0.142 rows=5 loops=1)
              Index Cond: (fecha = CURRENT_DATE)
        ->  Memoize
              ->  Index Scan using categoria_pkey on categoria c
Execution Time: 0.239 ms
```

### Tabla antes / después

| Entorno | Antes | Después | Mejora |
|---|---:|---:|---:|
| Base canónica TP2–TP5 | **244,707 ms** | **0,183 ms** | **~1.337×** |
| Laboratorio `tp6_p2` | **289,556 ms** | **0,239 ms** | **~1.212×** |

| Métrica | Antes | Después |
|---|---|---|
| Nodo dominante | `Parallel Hash Join` + `Parallel Seq Scan` sobre `detalle_pedido` | `Index Only Scan` sobre `idx_resumen_fecha_total` + `Nested Loop`/`Memoize` con `categoria_pkey` |
| Filas recorridas (canónica) | ~400.000 detalles de hoy + 300.000 pedidos + 50.000 productos | 5 entradas del índice + 5 búsquedas de categoría |

Ambas consultas devuelven el mismo top 5 y los mismos totales:

| Categoría | Total vendido |
|---|---:|
| Categoría 36 | 64.342.270,62 |
| Categoría 01 | 62.851.384,37 |
| Categoría 05 | 61.870.718,70 |
| Categoría 22 | 61.288.080,44 |
| Categoría 56 | 61.014.674,18 |

Captura completa: `resultados/despues_run2.txt` (laboratorio) y `resultados/tp5_despues_run2.txt` (canónica).

> El resumen guarda `categoria_id` y no el nombre, para no añadir una segunda redundancia sensible a cambios. El join contra `categoria` es de 60 filas y se resuelve por PK; no recorre `detalle_pedido`, `producto` ni `pedido`.

## 11. Auditoría de desincronización

El script `07_auditoria.sql` (laboratorio) / `07b_auditoria_tp5.sql` (canónica), también incluidos en el entregable, recalcula la fuente y la compara con el resumen usando `FULL OUTER JOIN` por `(categoria_id, fecha)`, detectando filas faltantes, sobrantes y totales distintos. Resultado en ambos entornos: 0 filas.

```text
 categoria_id | fecha | total_fuente | total_resumen | problema
--------------+-------+--------------+---------------+----------
(0 filas)

 suma_global_coincide
----------------------
 t
```

Además, `05_prueba_sincronizacion.sql` (laboratorio) y `05b_prueba_sincronizacion_tp5.sql` (canónica) ejecutan 9 mutaciones dentro de una transacción y verifican la auditoría después de cada una:

```text
NOTICE: Prueba de sincronización OK: 9 mutaciones verificadas, 0 desincronizaciones.
```

## 12. Reversibilidad

`06_rollback.sql` elimina la tabla de resumen, sus índices, funciones y disparadores. No modifica `detalle_pedido`, `pedido`, `producto` ni `categoria`, por lo que no hay pérdida de información: la consulta original sigue funcionando y el resumen puede reconstruirse con el backfill. Funciona igual en la base canónica y en el laboratorio, porque toma el `search_path` de la sesión.

---

## Integración con los TP anteriores

La Parte 1 ya era compatible por diseño: trabaja en el esquema aislado `tp6_fnbc` y no toca las tablas de Food Store.

La Parte 2 se integró explícitamente con el esquema canónico de TP2–TP5:

- `00_migracion_esquema_tp5.sql` **extiende** el esquema `public` existente (agrega `categoria`, claves foráneas y columnas de soft-delete/subtotal) sin recrear ni reemplazar tablas.
- Se conserva `pedido.fecha TIMESTAMPTZ` y la FK `detalle_pedido → pedido ON DELETE CASCADE`; por eso se agregó el trigger `BEFORE DELETE` sobre `pedido`.
- Se conservan todos los índices y constraints previos.
- La validación final se corrió sobre una base creada desde `TP2_Concurrencia/Script.sql` y poblada con `TP3/carga_masiva.sql`, no solo sobre el laboratorio.

---

## Archivos del TP

```text
TP6/
├── tp_fnbc_control_lote.sql                  # Parte 1 (entregable)
├── tp_desnormalizacion_top_categorias.sql    # Parte 2 (entregable)
├── 00_migracion_esquema_tp5.sql
├── 00_ejecutar_tp5.sql
├── 00_ejecutar_laboratorio.sql
├── 01_esquema_base.sql
├── 02_poblado.sql
├── 03_consulta_antes.sql
├── 03b_poblado_pico_hoy.sql
├── 03c_consulta_antes_tp5.sql
├── 04_consulta_despues.sql
├── 04b_consulta_despues_tp5.sql
├── 05_prueba_sincronizacion.sql
├── 05b_prueba_sincronizacion_tp5.sql
├── 06_rollback.sql
├── 07_auditoria.sql
├── 07b_auditoria_tp5.sql
├── informe_fnbc.md
├── informe_parte2.md
├── informe_tp6.md                         # este informe completo
├── README.md
├── cambios/
│   ├── DUIA_TP6_Desnormalizacion_FNBC.md
│   └── DUIA_TP6_Parte2_Desnormalizacion.md
└── resultados/
```
