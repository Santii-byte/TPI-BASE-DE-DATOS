# DUIA - Informe Concurrencia
# Informe de Concurrencia (Parte 2)

## Escenario 1: Espera por bloqueo

* **Escenario:** Espera por bloqueo.
* **Cómo se reprodujo:**
  1. Primero abrí la Sesión A y mandé: `BEGIN; SELECT * FROM pedido WHERE id = 1 FOR UPDATE;`
  2. Después fui a la Sesión B y mandé exactamente lo mismo: `BEGIN; SELECT * FROM pedido WHERE id = 1 FOR UPDATE;`
  3. Volví a la Sesión A y cerré con: `COMMIT;`
* **Qué se observó:**[cite: 1] 
  Cuando tiré el primer select en la Sesión A, me devolvió los datos al toque. Pero cuando tiré el mismo select en la Sesión B, DBeaver se quedó tildado cargando, como esperando algo. Recién cuando le di `COMMIT` a la Sesión A, la Sesión B se destrabó y me tiró el resultado.
* **Explicación de la IA:**
  > Por qué ocurrió el bloqueo:
  > SELECT ... FOR UPDATE adquiere un lock exclusivo (row-level lock) en la fila seleccionada. La primera sesión mantiene ese lock hasta que hace COMMIT o ROLLBACK. La segunda sesión intenta adquirir el mismo lock y se bloquea esperando.
  > 
  > Niveles de aislamiento y mecanismos:
  > Nivel/Mecanismo | Comportamiento con FOR UPDATE
  > Read Committed (default) | Bloquea hasta que la 1ª transacción termina
  > Repeatable Read | Igual - FOR UPDATE siempre toma lock exclusivo
  > Serializable | Igual + posible serialization_failure al commit
  > FOR NO KEY UPDATE | Lock más débil (permite INSERT en tablas hijas con FK)
  > FOR SHARE | Lock compartido (varias transacciones pueden leer, nadie puede escribir)
  > NOWAIT / SKIP LOCKED | Evita espera: falla inmediato o salta filas bloqueadas
  > 
  > Para evitar el bloqueo en tu caso:
  > SELECT ... FOR SHARE - si solo necesitas leer consistentemente sin modificar
  > SELECT ... FOR UPDATE SKIP LOCKED - procesa filas no bloqueadas (patrón worker queue)
  > SELECT ... FOR UPDATE NOWAIT - error inmediato si está bloqueada
  > Reducir tiempo de transacción - commit/rollback rápido tras el SELECT
* **Verificación en el motor:**
  Volví a hacer la prueba para ver si la IA tenía razón con lo de las soluciones. En la Sesión A bloqueé la fila igual que antes, pero en la Sesión B le agregué el `NOWAIT` a la consulta (`SELECT * FROM pedido WHERE id = 1 FOR UPDATE NOWAIT;`). Efectivamente, en vez de quedarse cargando para siempre, me tiró un error al instante diciendo que no podía bloquear el registro porque otra sesión lo estaba usando.
* **Conclusión:**
  La IA le pegó. El problema acá es que `FOR UPDATE` te secuestra la fila literalmente, así que no importa si cambias el nivel de aislamiento de la transacción (Read Committed, Serializable, etc.), el choque va a existir igual. La forma real de evitar que el sistema se cuelgue es atajándolo desde el código SQL, usando cosas como `NOWAIT` para que tire error de una, o hacer transacciones lo más cortas posibles para no hacer esperar al resto.




##DUIA

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