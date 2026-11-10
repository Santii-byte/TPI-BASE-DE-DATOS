// a) Mostrar todos los pedidos (solo _id y estado)
db.pedidos.find({}, { _id: 1, estado: 1 });

// b) Filtrar por estado 'pagado'
db.pedidos.find({ estado: "pagado" });

// c) Buscar pedidos con producto_id = 1 dentro del arreglo
db.pedidos.find({ "lineas_pedido.producto_id": 1 });

// d) Buscar pedidos con total mayor a $8000.00
db.pedidos.find({ total: { $gt: 8000.00 } });