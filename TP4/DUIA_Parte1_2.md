# DUIA - Ranking clientes: índices + agregación temprana

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Tengo este plan de ejecución real sobre PostgreSQL correspondiente a un ranking de clientes con agregación y joins: [plan Limit -> Sort top-N -> GroupAggregate Group Key c.id 16714 grupos -> Sort Key c.id, p.id external merge Disk 7040kB temp read/written -> Hash Join p=dp... wait p.cliente_id=c.id -> Hash Join dp.pedido_id=p.id -> Seq Scan detalle 399993 + Hash de Seq Scan pedido con filtro estado IN (pagado,enviado) AND fecha >= now()-180d que deja 49162 de 200k + Seq Scan cliente activos 19013, Execution Time 295.684 ms]. El tiempo de ejecución es de ~295 ms y hay un Sort external merge de 7040 kB a disco temporal. Propón una combinación de índices y/o reescritura que optimice el filtrado de pedidos y elimine el derrame a disco."

## Qué generó
Diagnóstico: el plan hace 3 cosas caras: (1) `Seq Scan` de los 200k pedidos para quedarse con 49k (filtro `estado` + `fecha`); (2) `Seq Scan` completo de los 400k detalles + doble `Hash Join`; (3) `Sort` de ~94k filas anchas (`width=60`) por `(c.id, p.id)` que derrama 7 MB a disco temporal para alimentar al `GroupAggregate` (16.714 grupos para un Top-20).

**1. Combinación de índices:**

```sql
CREATE INDEX IF NOT EXISTS idx_pedido_estado_fecha
    ON pedido (fecha) WHERE estado IN ('pagado', 'enviado');
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_cover
    ON detalle_pedido (pedido_id) INCLUDE (cantidad, precio_unitario);
VACUUM ANALYZE pedido;
VACUUM ANALYZE detalle_pedido;
```

Por qué: el parcial calza exacto el filtro (parte invariante `estado IN (...)` como predicado, `fecha` ordenada para el rango) → `pedido` pasa de `Seq Scan` de 200k a `Bitmap`/`Index Scan` de ~49k filas. El covering en detalle da `Index-Only Scan` ordenado por `pedido_id` (la pata del join con pedido) sin visitar el heap de 2942 buffers, y deja las filas ordenadas por la futura clave de agregación por pedido.

**2. Reescritura (agregación temprana por pedido):**

```sql
WITH monto_pedido AS (
    SELECT p.id, p.cliente_id,
           SUM(dp.cantidad * dp.precio_unitario) AS monto
    FROM pedido AS p
    JOIN detalle_pedido AS dp ON dp.pedido_id = p.id
    WHERE p.estado IN ('pagado', 'enviado')
      AND p.fecha >= now() - INTERVAL '180 days'
    GROUP BY p.id, p.cliente_id
)
SELECT c.id, c.nombre, SUM(m.monto) AS total
FROM cliente AS c
JOIN monto_pedido AS m ON m.cliente_id = c.id
WHERE c.activo
GROUP BY c.id, c.nombre
ORDER BY total DESC
LIMIT 20;
```

Por qué: agrega las ~98k filas del join a ~49k montos por pedido ANTES de tocar `cliente` (la mitad de filas para ordenar); ese `GROUP BY (pedido_id)` puede alimentarse del covering ya ordenado en modo streaming, sin el `Sort` de 7 MB. El segundo nivel agrega 49k → 16,7k grupos, un sort mucho menor.

**3. Spill:** de forma determinista, `SET LOCAL work_mem = '32MB';` mete en memoria cualquier sort residual (el grande necesita ~7-8 MB). Con reescritura + covering, el sort grande directamente puede desaparecer: verificar con `EXPLAIN (ANALYZE, BUFFERS)` buscando la ausencia del nodo `Sort` bajo el `GroupAggregate`.

**Plan esperado:** `Bitmap`/`Index Scan` en pedido, `Index-Only` en detalle, `Hash Joins` conservados (correcto a este volumen), sorts en memoria o eliminados; objetivo < 100 ms. Documentado en `TP3/DUIA_Parte10.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Propuesta entregada en el chat, más este DUIA en `TP3/DUIA_Parte10.md`. Sin commits por parte de la herramienta (los hace el usuario).

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
