-- Caso C4 - baja logica del producto 6 (yerba mate).
-- El producto no se borra fisicamente: se marca eliminado = TRUE.
BEGIN;

UPDATE producto
   SET eliminado      = TRUE,
       actualizado_en = now()
 WHERE id = 6;

COMMIT;

SELECT id, nombre, stock, disponible, eliminado
  FROM v_snapshot_movil
 WHERE id = 6;