# DUIA - Informe Concurrencia

## Herramienta
nemotron-3-ultra-free (opencode)

## Prompt utilizado
"Acabo de ejecutar estos comandos BEGIN; SELECT * FROM pedido WHERE id = 1 FOR UPDATE; en dos sesiones concurrentes y ocurrio un bloqueo en la segunda ventana. ¿Por qué pasó esto y qué nivel de aislamiento o mecanismo lo evita?"

## Qué generó
**Por qué ocurrió el bloqueo:**

`SELECT ... FOR UPDATE` adquiere un **lock exclusivo (row-level lock)** en la fila seleccionada. La primera sesión mantiene ese lock hasta que hace `COMMIT` o `ROLLBACK`. La segunda sesión intenta adquirir el mismo lock y se bloquea esperando.

**Niveles de aislamiento y mecanismos:**

| Nivel/Mecanismo | Comportamiento con `FOR UPDATE` |
|-----------------|--------------------------------|
| **Read Committed** (default) | Bloquea hasta que la 1ª transacción termina |
| **Repeatable Read** | Igual - `FOR UPDATE` siempre toma lock exclusivo |
| **Serializable** | Igual + posible `serialization_failure` al commit |
| **`FOR NO KEY UPDATE`** | Lock más débil (permite `INSERT` en tablas hijas con FK) |
| **`FOR SHARE`** | Lock compartido (varias transacciones pueden leer, nadie puede escribir) |
| **`NOWAIT` / `SKIP LOCKED`** | Evita espera: falla inmediato o salta filas bloqueadas |

**Para evitar el bloqueo en tu caso:**

1. **`SELECT ... FOR SHARE`** - si solo necesitas leer consistentemente sin modificar
2. **`SELECT ... FOR UPDATE SKIP LOCKED`** - procesa filas no bloqueadas (patrón worker queue)
3. **`SELECT ... FOR UPDATE NOWAIT`** - error inmediato si está bloqueada
4. **Reducir tiempo de transacción** - commit/rollback rápido tras el `SELECT`

¿Qué intención tienes con ese `FOR UPDATE`? ¿Actualizas la fila después o solo necesitas lectura consistente?

## Qué se aceptó
No hubo cambios que aceptar

## Qué se modificó o descartó y por qué
-

## Verificación realizada
Se verifico la veracidad de las recomendacioens para que no ocurra dicho bloqueo en la BD.