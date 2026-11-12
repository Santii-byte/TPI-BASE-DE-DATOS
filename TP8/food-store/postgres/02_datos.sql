-- ============================================================================
-- TP8 - Datos inventados de la parada 5 (nunca datos reales)
-- ============================================================================
-- Precios en centavos. Los casos borde son intencionales:
--   * producto 11: stock 8, se usara para pedir 10 (RECHAZADO por stock)
--   * producto 13: stock 0 (RECHAZADO)
--   * producto 14: disponible = FALSE (RECHAZADO)
--   * producto 15: eliminado = TRUE  (RECHAZADO)
--   * producto 4:  precio 450000, el borrador lo tiene a 400000 (CONFLICTO)
-- ============================================================================

BEGIN;

INSERT INTO tienda (id, nombre, direccion) VALUES
    (5, 'Food Store - Parada 5', 'Feria de Villa Nueva, pasillo 3');

INSERT INTO producto
    (id, tienda_id, nombre, categoria, precio_centavos, stock, disponible, eliminado)
VALUES
    ( 1, 5, 'Pan de campo 500 g',            'Panaderia',   180000, 24, TRUE,  FALSE),
    ( 2, 5, 'Leche entera 1 L',              'Lacteos',      95000, 36, TRUE,  FALSE),
    ( 3, 5, 'Cafe molido 250 g',             'Almacen',     320000, 18, TRUE,  FALSE),
    ( 4, 5, 'Queso cremoso 400 g',           'Lacteos',     450000, 12, TRUE,  FALSE),
    ( 5, 5, 'Huevos color x 12',             'Frescos',     280000, 20, TRUE,  FALSE),
    ( 6, 5, 'Yerba mate 1 kg',               'Almacen',     390000, 15, TRUE,  FALSE),
    ( 7, 5, 'Azucar 1 kg',                   'Almacen',     110000, 40, TRUE,  FALSE),
    ( 8, 5, 'Aceite de girasol 1.5 L',       'Almacen',     250000, 22, TRUE,  FALSE),
    ( 9, 5, 'Fideos tallarin 500 g',         'Almacen',      85000, 30, TRUE,  FALSE),
    (10, 5, 'Arroz largo fino 1 kg',         'Almacen',     135000, 25, TRUE,  FALSE),
    (11, 5, 'Tomate perita 1 kg',            'Verduleria',  120000,  8, TRUE,  FALSE),
    (12, 5, 'Manzana roja 1 kg',             'Fruteria',    140000,  4, TRUE,  FALSE),
    (13, 5, 'Agua mineral 2 L',              'Bebidas',      70000,  0, TRUE,  FALSE),
    (14, 5, 'Galletitas de agua 300 g',      'Almacen',      60000, 18, FALSE, FALSE),
    (15, 5, 'Mate cocido 25 saquitos',       'Almacen',      75000, 14, TRUE,  TRUE),
    (16, 5, 'Mermelada de durazno 454 g',    'Almacen',     210000,  9, TRUE,  FALSE);

-- Pedidos ya confirmados en el servidor (datos inventados). Sirven como
-- control: la simulacion de la tablet no debe modificarlos.
INSERT INTO pedido (id, tienda_id, id_local, fecha, forma_pago, total_centavos) VALUES
    (1001, 5, 'f0000000-0000-4000-8000-000000001001', '2026-11-11T10:15:00-03:00', 'EFECTIVO',      680000),
    (1002, 5, 'f0000000-0000-4000-8000-000000001002', '2026-11-11T11:40:00-03:00', 'TARJETA',       450000),
    (1003, 5, 'f0000000-0000-4000-8000-000000001003', '2026-11-11T12:05:00-03:00', 'TRANSFERENCIA', 330000);

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_centavos) VALUES
    (1001, 1, 2, 180000),
    (1001, 3, 1, 320000),
    (1002, 4, 1, 450000),
    (1003, 7, 3, 110000);

-- Foto del estado inicial: la tablet no debe modificarlo.
INSERT INTO control_instalacion (pedidos_base, detalles_base, stock_base)
SELECT (SELECT count(*) FROM pedido),
       (SELECT count(*) FROM detalle_pedido),
       (SELECT sum(stock) FROM producto WHERE tienda_id = 5);

COMMIT;

SELECT count(*) AS filas_cargadas FROM producto WHERE tienda_id = 5;