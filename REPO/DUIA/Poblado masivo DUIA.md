# DUIA - Poblado masivo

## Herramienta
muse-spark-1.3-contributor-free (opencode)

## Prompt utilizado
"Generá un script SQL puro para PostgreSQL llamado poblado_masivo.sql para insertar datos masivos usando generate_series() y funciones aleatorias (random()). Debe cargar: 1) 20.000 clientes con emails únicos tipo 'clienteN@test.com'. 2) 50.000 productos con precios entre 500 y 5000 y stock entre 0 y 200. 3) 200.000 pedidos vinculados a clientes aleatorios con fechas del último año. 4) 400.000 registros en detalle_pedido vinculando pedidos y productos aleatorios con cantidad entre 1 y 5. Al final, incluir el comando ANALYZE para todas las tablas. No uses PL/pgSQL complejo si se puede hacer con INSERT INTO ... SELECT generate_series()."

## Qué generó
Listo: `poblado_masivo.sql` creado en la raíz del repo (sin commit, como exige tu protocolo). Solo SQL puro con `INSERT INTO ... SELECT generate_series()`, sin PL/pgSQL:

* **Clientes (20.000):** `clienteN@test.com` únicos vía `generate_series(1,20000)`; teléfono 80% presente / 20% NULL; 95% activos; `created_at` aleatorio del último año.
* **Productos (50.000):** precio `(500 + random()*4500)::NUMERIC(12,2)`, stock `0..200`, 90% activos.
* **Pedidos (200.000):** `cliente_id` aleatorio `1..20000`, fecha `now() - random()*365 días` (respeta `CHECK fecha <= now()`), estado/forma_pago aleatorios de los ENUMs, total provisorio `0.00`.
* **Detalle (400.000):** pares pedido/producto aleatorios, cantidad `1..5`, `precio_unitario` copiado del precio real del producto (garantiza `> 0`); `ON CONFLICT DO NOTHING` evita que una colisión aleatoria de la PK compuesta aborte la carga (el conteo final puede quedar levemente debajo de 400.000).
* **Coherencia extra:** `UPDATE` que recalcula `pedido.total = SUM(cantidad*precio_unitario)`.
* **Cierre:** todo en una transacción, `ANALYZE` por tabla y `SELECT` de conteos para verificar.

Supuesto documentado en la cabecera: base recién creada desde `Script.sql` (ids 1..N). Ejecución: `psql -d copia_trabajo -f poblado_masivo.sql` (en copia aislada, con `BEGIN; ... ROLLBACK;` previo según protocolo). DUIA en `cambios/poblado_masivo.md`, con verificación pendiente para que la rellenes vos.

## Qué se aceptó
Archivo `poblado_masivo.sql` nuevo en la raíz del repo, más este DUIA en `cambios/poblado_masivo.md`. Sin commits por parte de la herramienta (los hace el usuario).

Nota de verificación posterior: `poblado_masivo.sql` ya figura commiteado en `8864e95` ("Create poblado_masivo.sql", Franco Rios) con contenido idéntico al generado (hash de disco = hash de HEAD); solo este DUIA queda pendiente de `git add`/commit por el usuario.

## Qué se modificó o descartó y por qué
-

## Verificación realizada
-
