-- Restaurar el producto 6 para dejar el servidor en el estado base.
BEGIN;

UPDATE producto
   SET eliminado      = FALSE,
       actualizado_en = now()
 WHERE id = 6;

COMMIT;

SELECT id, nombre, eliminado FROM producto WHERE id = 6;