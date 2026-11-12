-- Caso C2 - el servidor sube el precio de la leche (id 2).
-- Antes: 95000 centavos. Despues: 105000 centavos.
BEGIN;

UPDATE producto
   SET precio_centavos = 105000,
       actualizado_en  = now()
 WHERE id = 2;

COMMIT;

SELECT id, nombre, precio_centavos, stock, disponible, eliminado
  FROM v_snapshot_movil
 WHERE id = 2;