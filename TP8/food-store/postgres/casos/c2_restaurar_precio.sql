-- Restaurar el precio de la leche para dejar el servidor en el estado base.
BEGIN;

UPDATE producto
   SET precio_centavos = 95000,
       actualizado_en  = now()
 WHERE id = 2;

COMMIT;

SELECT id, nombre, precio_centavos FROM producto WHERE id = 2;