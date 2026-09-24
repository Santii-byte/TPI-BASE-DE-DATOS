\# Informe de Mediciones y Plan de Indexado — Food Store



\- \*\*Integrantes:\*\* Franco Rios y Santino Barone

\- \*\*Materia:\*\* Base de Datos II — Unidad 3, Semana 5



\---



\## 4.1. Parte A — Plan de Indexado Asistido por IA



\### Consulta 1: Filtrado de pedidos por cliente y rango de fecha reciente



```sql

EXPLAIN ANALYZE

SELECT id, fecha, total, estado 

FROM pedido 

WHERE cliente\_id = 12450 

&#x20; AND fecha >= now() - INTERVAL '90 days';



Índice aplicado: idx\_pedido\_cliente\_fecha sobre pedido (cliente\_id, fecha)



Antes:

Planning Time: 3.085 ms



Execution Time: 0.115 ms



Después:

Planning Time: 0.148 ms



Execution Time: 0.065 ms





Consulta 2: Catálogo de productos activos ordenado por precio



EXPLAIN ANALYZE

SELECT id, nombre, precio, stock

FROM producto

WHERE activo = TRUE AND precio BETWEEN 1000.00 AND 3000.00

ORDER BY precio DESC

LIMIT 50;



Índice aplicado: idx\_producto\_precio\_activo (B-Tree)



Antes:

Planning Time: 2.558 ms



Execution Time: 0.210 ms



Después:

Planning Time: 2.285 ms



Execution Time: 0.059 ms



Consulta 3: Agregación masiva de unidades y facturación por producto



EXPLAIN ANALYZE

SELECT 

&#x20;   dp.producto\_id,

&#x20;   SUM(dp.cantidad) AS unidades\_vendidas,

&#x20;   SUM(dp.cantidad \* dp.precio\_unitario) AS facturacion\_total

FROM detalle\_pedido dp

GROUP BY dp.producto\_id;



Índice aplicado: idx\_detalle\_producto\_cover (Covering Index con INCLUDE)



Antes:

Planning Time: 3.678 ms



Execution Time: 160.109 ms



Después:

Planning Time: 0.145 ms



Execution Time: 151.994 ms







