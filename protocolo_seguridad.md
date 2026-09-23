Copia: Se trabajará siempre sobre una base de desarrollo aislada mediante comandos como createdb -T plantilla\_base copia\_trabajo, garantizando que nunca se toquen datos reales.  


Transacción: Todo script autogenerado se ejecutará envuelto en un bloque BEGIN; ... ROLLBACK; para inspeccionar las filas afectadas y los mensajes del motor antes de aplicar un cambio definitivo. Nunca se harán commits directamente, solo editaras archivos locales y yo hare los commits aparte.


Respaldo: Se ejecutará un dump de seguridad (pg\_dump copia\_trabajo > backup.sql) antes de aplicar cambios estructurales (DDL) para tener un punto de retorno manual.



Documentación: Cada vez que se haga un cambio o accion debe ser documentado en un archivo donde tendra una estructura llamada DUIA, cada DUIA tiene que incluir los siguientes campos: Herramienta, prompt utilizado, que generó, que se aceptó, que se modifico o descarto y porque, verificacion realizada. Vas a generar la plantilla en md y vas a rellenar automaticamente los campos herramienta con el modelo usado, prompts con los usados, EN CAMPO DE "que se genero" DEVOLVER EXACTAMENTE LA MISMA RESPUESTA QUE PROPORCIONASTE DEESPUES DE MI PROMPT. Los campos de "que se modifico" y "verificacion" quedaran blanco para yo rellenarlos. Debes generar un archivo md distinto para cada vez que ocurra un cambio o solicitud y le pondras un nombre que creas conveniente del cambio o solicitu, a menos que yo te de el nombre, en ese caso usaras ese. Este archivo se guardara en una caperta llamada cambios.

