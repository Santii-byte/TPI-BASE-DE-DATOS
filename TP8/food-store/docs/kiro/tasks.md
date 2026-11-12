# Tareas - TP8

Generadas por OpenCode a partir de `requirements.md` y ejecutadas en este
orden. Cada tarea indica su evidencia.

## Preparación

- [x] Definir los cuatro requisitos EARS (REQ-01 a REQ-04).
- [x] Crear la base de laboratorio `foodstore_u8` con datos inventados.
- [x] Documentar que no se usan datos personales reales.

## Consigna 1 - Base de la tablet

- [x] Elegir los datos que viajan y los que no (`docs/informe.pdf`, 1.a).
- [x] Crear `movil/schema_sqlite.sql` con las cuatro tablas `STRICT`, PK, FK,
      checks y `PRAGMA foreign_keys = ON`.
- [x] Crear `snapshot_servidor` y `snapshot_raw` para la instantánea.
- [x] Probar C1 (catálogo local sin servidor).
- [x] Probar un borrador completo con `COMMIT`.
- [x] Probar un borrador descartado con `ROLLBACK`.
- [x] Probar C7a (cantidad 0) y C7b (producto inexistente) sin filas nuevas.
- Evidencia: `docs/evidencias/03_carga_y_semaforo_inicial.txt` y
  `docs/evidencias/04_pruebas_sqlite.txt`.

## Consigna 2 - Sincronizar y resolver

- [x] Crear `v_snapshot_movil` y exportar `servidor_snapshot.csv`.
- [x] Importar el CSV en SQLite con staging y normalización `t/f -> 1/0`.
- [x] Implementar `semaforo.sql` con precedencia rojo > amarillo > verde.
- [x] Evaluar solo `PENDIENTE`; repetir la simulación no cambia nada.
- [x] Caso C2: precio cambiado -> `CONFLICTO`; cliente acepta -> nueva solicitud
      `SIMULADO_APROBADO`.
- [x] Caso C3: 5 manzanas con stock 4 -> `RECHAZADO`.
- [x] Caso C4: baja lógica -> `RECHAZADO`; item local conservado.
- [x] Caso C5: sin cambios -> `SIMULADO_APROBADO`.
- [x] Caso C6: reenvío del mismo UUID -> duplicado rechazado.
- [x] Verificar en PostgreSQL que pedidos y stock no cambiaron.
- Evidencia: `docs/evidencias/casos_c2_c6.txt` y
  `docs/evidencias/05_verificacion_postgres.txt`.

## Consigna 3 - Integrar y revisar

- [x] Armar el mapa de PostgreSQL / MongoDB / SQLite.
- [x] Extender el plan de mantenimiento de la Unidad 6: respaldo, restauración
      y revisión de solicitudes en conflicto.
- [x] Revisar todos los scripts de la cursada con OpenCode en modo Plan.
- [x] Registrar hallazgos aceptados, corregidos y descartados con fundamento.
- Evidencia: `docs/informe.pdf`, secciones 3.a, 3.b y 3.c.

## Consigna 4 - Kiro, bitácora y defensa

- [x] Escribir `docs/kiro/requirements.md` antes de dar por cerrado el código.
- [x] Generar `design.md` y `tasks.md` desde los requisitos.
- [x] Registrar al menos tres entradas en `docs/bitacora_ia.md`.
- [x] Escribir `docs/DUIA.md`.
- [x] Escribir el README con el orden de creación desde cero.
- [x] Preparar el ensayo de defensa de 10 minutos.
- Evidencia: `docs/informe.pdf`, `docs/bitacora_ia.md`, `docs/DUIA.md` y
  `README.md`.

## Pendiente para la entrega

- [ ] Exportar el `.zip` o subir el repositorio con la etiqueta `tp8`.
- [ ] Revisar que el `.zip` incluya `movil/foodstore_movil.db` y
      `movil/servidor_snapshot.csv`.
- [ ] Ensayar la defensa con cronómetro (10 minutos).