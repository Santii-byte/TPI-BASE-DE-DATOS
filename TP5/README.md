# Food Store — TP Unidad 3 Semana 5: Índices y Vistas

Trabajo práctico de diseño y optimización de base de datos en PostgreSQL 16+.

- **Integrantes:** Franco Rios y Santino Barone
- **Herramientas utilizadas:** OpenCode, Kiro, Git/GitHub, PostgreSQL

---

## Estructura del Proyecto

* `schema.sql`: Definición del modelo de datos relacional (DDL).
* `data.sql`: Carga y poblado de datos de prueba.
* `indices.sql`: Sentencias CREATE INDEX optimizadas y documentadas (Parte A).
* `views.sql`: Vistas de negocio, vistas con criterio de seguridad y vista materializada (Partes B y C).
* `medicion_escritura.sql`: Script de benchmark para medir el impacto de índices en operaciones INSERT.
* `specs/`: Especificaciones funcionales y requerimientos previos de optimización (flujo Kiro).
* `informe_mediciones.md`: Registro de planes de ejecución (EXPLAIN ANALYZE) antes/después y justificaciones técnicas.
* `duia.md`: Declaración de Uso de Inteligencia Artificial (bitácora de prompts y decisiones).