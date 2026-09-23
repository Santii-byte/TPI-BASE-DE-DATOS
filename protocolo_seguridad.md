Copia: Se trabajará siempre sobre una base de desarrollo aislada mediante comandos como createdb -T plantilla\_base copia\_trabajo, garantizando que nunca se toquen datos reales.  
Transacción: Todo script autogenerado se ejecutará envuelto en un bloque BEGIN; ... ROLLBACK; para inspeccionar las filas afectadas y los mensajes del motor antes de aplicar un COMMIT definitivo.  
Respaldo: Se ejecutará un dump de seguridad (pg\_dump copia\_trabajo > backup.sql) antes de aplicar cambios estructurales (DDL) para tener un punto de retorno manual.

Documentación: Cada cambio hecho y confirmado debe ser documentado en un archivo pdf llamado documentacion\_cambios, si este no existe créalo.

