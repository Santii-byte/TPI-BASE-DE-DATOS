-- ============================================================================
-- TP8 - Verificacion final del lado PostgreSQL
-- ============================================================================
-- Se ejecuta despues de todos los casos C2-C6. Debe devolver VERDE:
-- la tablet no confirmo ventas, no desconto stock y no cambio precios de
-- pedidos ya confirmados. Los unicos cambios permitidos fueron los que el
-- servidor hizo a proposito en los casos (precio de leche, baja de yerba mate),
-- y al final se restauraron.
-- ============================================================================

WITH actual AS (
    SELECT (SELECT count(*) FROM pedido)                         AS pedidos,
           (SELECT count(*) FROM detalle_pedido)                 AS detalles,
           (SELECT sum(stock) FROM producto WHERE tienda_id = 5) AS stock
)
SELECT c.pedidos_base,
       a.pedidos,
       c.detalles_base,
       a.detalles,
       c.stock_base,
       a.stock,
       CASE
           WHEN a.pedidos  = c.pedidos_base
            AND a.detalles = c.detalles_base
            AND a.stock    = c.stock_base
           THEN 'VERDE: pedidos y stock sin cambios'
           ELSE 'ROJO: la simulacion modifico el servidor'
       END AS veredicto
  FROM control_instalacion AS c
 CROSS JOIN actual AS a;

-- Detalle de pedidos: siguen siendo los tres del servidor.
SELECT p.id, p.id_local, p.forma_pago, p.total_centavos, p.estado,
       count(d.producto_id) AS lineas
  FROM pedido AS p
  LEFT JOIN detalle_pedido AS d ON d.pedido_id = p.id
 GROUP BY p.id, p.id_local, p.forma_pago, p.total_centavos, p.estado
 ORDER BY p.id;

-- Stock por producto: ningun valor fue tocado por la tablet.
SELECT id, nombre, precio_centavos, stock, disponible, eliminado
  FROM producto
 WHERE tienda_id = 5
 ORDER BY id;