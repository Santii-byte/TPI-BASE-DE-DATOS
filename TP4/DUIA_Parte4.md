# DUIA - Competencia Top-50 por cliente y forma de pago

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Estamos en la competencia de optimización de la Semana 4 de Base de Datos II. Esta es la consulta común: [plan Limit 50 -> Sort top-N -> GroupAggregate Group Key c.id, p.forma_pago 50126 grupos -> Sort Key c.id, p.forma_pago, p.id external merge Disk 11296kB temp read/written -> Hash Join p.cliente_id=c.id -> Hash Join dp.pedido_id=p.id (Seq Scan detalle 400k + Hash de Bitmap Heap Scan pedido con idx_pedido_estado_fecha ~100k) + Hash de Seq Scan cliente activos, Execution Time 679.428 ms]. Propón la estrategia más agresiva y justificada para minimizar el Execution Time en PostgreSQL sobre una base con 20k clientes, 200k pedidos y 400k detalles: ¿Qué índices adicionales o ajustes de sesión (work_mem) se requieren? ¿Cómo se puede reescribir con agregación anticipada (push-down de agregación) para evitar duplicación de filas en el JOIN? Documenta qué propuestas descartarías por ineficientes o por overhead de mantenimiento."

## Qué generó
Diagnóstico: 679 ms = `Sort` externo de 11 MB (190k filas × `width=43` ordenadas por 3 claves para el `GroupAggregate` de 50k grupos) + doble `Hash Join` sobre 200k filas. Los índices existentes ya hacen su parte (`idx_pedido_estado_fecha` en uso); lo que falta es achicar lo que entra al sort y meterlo en memoria.

**1. Índices adicionales + sesión:**

```sql
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_cover
    ON detalle_pedido (pedido_id) INCLUDE (cantidad, precio_unitario);
VACUUM ANALYZE detalle_pedido;
SET LOCAL work_mem = '64MB';
```

Por qué: el covering da `Index-Only Scan` ordenado por `pedido_id` sobre los 400k detalles (adiós visitas al heap); `work_mem` 64 MB absorbe el sort de 11 MB + las tablas hash (6.5 MB) con margen, eliminando todo `temp written` de forma determinista. Solo sesión (`SET LOCAL`), no global: en competencia no se reinicia el servidor por un query.

**2. Reescritura con push-down (agregación por pedido antes del JOIN con cliente):**

```sql
WITH monto_pedido AS (
    SELECT p.id, p.cliente_id, p.forma_pago,
           SUM(dp.cantidad * dp.precio_unitario) AS monto
    FROM pedido AS p
    JOIN detalle_pedido AS dp ON dp.pedido_id = p.id
    WHERE p.estado IN ('pagado', 'enviado')
      AND p.fecha >= now() - INTERVAL '365 days'
    GROUP BY p.id, p.cliente_id, p.forma_pago
)
SELECT c.id, c.nombre, m.forma_pago, SUM(m.monto) AS total
FROM cliente AS c
JOIN monto_pedido AS m ON m.cliente_id = c.id
WHERE c.activo
GROUP BY c.id, c.nombre, m.forma_pago
ORDER BY total DESC
LIMIT 50;
```

Por qué: cada pedido tiene UNA sola `forma_pago`, así que pre-agregar por pedido es exacto y baja de 200k filas duplicadas a ~100k montos antes de tocar `cliente`; el segundo nivel agrega 100k → 50k grupos, y con el `work_mem` alto el planificador puede usar `HashAggregate` (sin entrada ordenada) en ambos niveles: cero `Sort`, cero spill. Verificar con `EXPLAIN (ANALYZE, BUFFERS)` que no aparezca ningún `Sort` bajo los agregados.

**3. Propuestas descartadas (y por qué):**

* Índice simple en `detalle_pedido(producto_id)` o en `cliente`: inútiles acá, ningún filtro ni join los usa; solo overhead de mantenimiento en escritura.
* Índice en `pedido(cliente_id)` o `(cliente_id, fecha)`: el join con 100k filas es óptimo por hash; forzar `Nested Loop` con 100k probes sería más lento.
* `MATERIALIZED VIEW` / tabla de resumen: ganaría el benchmark pero con costo de refresco, almacenamiento duplicado y datos potencialmente rancios; solo si la competencia permite pre-cómputo y la consulta se repite idéntica.
* `CLUSTER`, `VACUUM FULL` o particionado: bloqueos/overhead groseros para 400k filas; el orden físico no paga lo que cuesta.
* Subir `max_parallel_workers` a ciegas: este plan corre sin workers (`loops=1`); si el entorno lo permite, probar `SET LOCAL max_parallel_workers_per_gather = 2`, pero el paralelismo no quita el spill, solo lo reparte.

**Plan esperado:** `Bitmap` en pedido, `Index-Only` en detalle, agregación en 2 niveles por hash en memoria, `Limit` intacto; objetivo < 150 ms. Documentado en `TP3/DUIA_Parte14.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Propuesta entregada en el chat, más este DUIA en `TP3/DUIA_Parte14.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
