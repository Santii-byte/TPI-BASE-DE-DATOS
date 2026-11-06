# TP 6 — Food Store: FNBC y desnormalización controlada

Trabajo práctico de normalización (Forma Normal de Boyce-Codd) sobre la relación
`control_lote_almacen` y de desnormalización controlada del reporte top 5 de
categorías de Food Store.

- **Integrantes:** Franco Rios y Santino Barone
- **Motor:** PostgreSQL 17
- **Herramienta:** OpenCode

## Contenido

| Archivo | Descripción |
|---|---|
| `tp_fnbc_control_lote.sql` | **Parte 1:** esquema original, instancia, tablas descompuestas, vista de compatibilidad, migración y verificaciones. |
| `informe_fnbc.md` | **Parte 1:** resolución escrita a) a f): dependencias funcionales, clausuras, claves candidatas, FNBC, anomalías y reunión sin pérdida. |
| `tp_desnormalizacion_top_categorias.sql` | **Parte 2:** tabla de resumen, disparadores de sincronización, consulta desnormalizada y auditoría. |
| `informe_parte2.md` | **Parte 2:** EXPLAIN ANALYZE antes/después, justificación del patrón, auditoría y reversibilidad. |
| `informe_tp6.md` | **Informe completo** (Parte 1 + Parte 2) para convertir a PDF/Word. |
| `00_migracion_esquema_tp5.sql` | Extiende la base canónica TP2–TP5 (`public`) con lo que necesita la Parte 2. |
| `00_ejecutar_tp5.sql` / `00_ejecutar_laboratorio.sql` | Wrappers que fijan el `search_path` y ejecutan el entregable. |
| `01_esquema_base.sql` … `07b_auditoria_tp5.sql` | Scripts reproducibles del laboratorio y de la base canónica: esquema, poblado, mediciones, prueba de sincronización, rollback y auditoría. |
| `cambios/` | Declaraciones de uso de IA (DUIA) de cada cambio. |

## Resumen de la Parte 1

```text
F = { {LoteID, DepositoID} → ResponsableControlID,
      ResponsableControlID  → DepositoID }

Claves candidatas: {LoteID, DepositoID}, {LoteID, ResponsableControlID}
Todos los atributos son primos → 3FN, pero no FNBC.

Violación: ResponsableControlID → DepositoID
Descomposición sin pérdida:
  R1 (ResponsableControlID, DepositoID)
  R2 (LoteID, ResponsableControlID)
```

## Resumen de la Parte 2

| Métrica | Base canónica TP2–TP5 | Laboratorio `tp6_p2` |
|---|---:|---:|
| Top 5 categorías del día, antes (mediana de 3) | 244,707 ms | 289,556 ms |
| Top 5 categorías del día, después (mediana de 3) | 0,183 ms | 0,239 ms |
| Nodo dominante antes | `Parallel Hash Join` + `Parallel Seq Scan` de `detalle_pedido` | igual |
| Nodo dominante después | `Index Only Scan` sobre `resumen_venta_categoria_dia` | igual |
| Auditoría de desincronización | 0 filas | 0 filas |

Patrón elegido: tabla de resumen `resumen_venta_categoria_dia` mantenida por
disparadores sobre `detalle_pedido`, `pedido` y `producto`. Es reversible sin
pérdida mediante `06_rollback.sql`.

## Integración con los TP anteriores

La Parte 1 no toca el esquema Food Store: trabaja en `tp6_fnbc`.

La Parte 2 se ejecuta sobre la base canónica de TP2–TP5 sin recrearla. La
migración `00_migracion_esquema_tp5.sql` solo agrega `categoria`,
`producto.categoria_id`, `producto.eliminado`, `pedido.eliminado`,
`detalle_pedido.eliminado` y `detalle_pedido.subtotal` (generada). Se conservan
`pedido.fecha TIMESTAMPTZ` y la FK `detalle_pedido → pedido ON DELETE CASCADE`.

## Ejecución

### Parte 1

```bash
psql -d copia_trabajo -f TP6/tp_fnbc_control_lote.sql
```

El script es idempotente y trabaja en el esquema aislado `tp6_fnbc`, sin tocar
las tablas de la base Food Store. Para inspeccionar el resultado sin persistirlo,
reemplazar `COMMIT;` por `ROLLBACK;` al final del bloque transaccional.

### Parte 2 — sobre la base canónica acumulada (recomendado)

```bash
# Partiendo de una copia de trabajo con TP2/TP3 ya cargados
psql -d copia_trabajo -f TP6/00_migracion_esquema_tp5.sql
psql -d copia_trabajo -f TP6/03b_poblado_pico_hoy.sql
psql -d copia_trabajo -f TP6/03c_consulta_antes_tp5.sql
psql -d copia_trabajo -f TP6/00_ejecutar_tp5.sql
psql -d copia_trabajo -f TP6/04b_consulta_despues_tp5.sql
psql -d copia_trabajo -f TP6/07b_auditoria_tp5.sql
psql -d copia_trabajo -f TP6/05b_prueba_sincronizacion_tp5.sql
```

### Parte 2 — laboratorio reproducible (`tp6_p2`)

```bash
psql -d copia_trabajo -f TP6/01_esquema_base.sql
psql -d copia_trabajo -f TP6/02_poblado.sql
psql -d copia_trabajo -f TP6/03_consulta_antes.sql
psql -d copia_trabajo -f TP6/00_ejecutar_laboratorio.sql
psql -d copia_trabajo -f TP6/04_consulta_despues.sql
psql -d copia_trabajo -f TP6/07_auditoria.sql
```

El laboratorio es reproducible (`setseed`) y genera ~1,2 M de renglones de detalle.

## Verificación rápida

Parte 1:

```sql
SELECT * FROM tp6_fnbc.control_lote_almacen_compat
ORDER BY lote_id, deposito_id;
```

Debe devolver exactamente las tres filas originales:

| lote_id | deposito_id | responsable_control_id |
|---:|---:|---:|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

Parte 2:

```sql
SELECT c.nombre, r.total_vendido
  FROM resumen_venta_categoria_dia r
  JOIN categoria c ON c.id = r.categoria_id
 WHERE r.fecha = CURRENT_DATE
 ORDER BY r.total_vendido DESC
 LIMIT 5;
```

En la base canónica, anteponer `public.` si el `search_path` no lo incluye.
```
