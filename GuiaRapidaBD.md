# Guía rápida de uso de la BD JustDo

En este documento se realizará una breve introducción, acompañada de ejemplos de consultas SQL, acerca de cómo configurar la BD para usarla, el significado semántico de los objetos de la BD y cómo se pueden emplear tales objetos para implementar los requisitos funcionales dados.

La manera recomendada de ejecutar las consultas SQL en PHP es con [_prepared statements_](http://php.net/manual/en/mysqli.quickstart.prepared-statements.php), pues evitan inyección SQL y otros problemas de sintaxis que pueden darse con ciertos datos de entrada.

### Obtener la BD y configurar MySQL/MariaDB

Simplemente ejecutar el script `install.sh` adjunto en la máquina virtual de IU como root. La aplicación PHP deberá de conectarse a la BD con el usuario y contraseña dados por `install.sh` (como root también es técnicamente posible, pero es menos seguro).

### Disparadores (reglas ECA) en la BD

La BD tiene implementadas reglas ECA que validan la corrección de los atributos que entran en la BD, y lanzan una excepción SQL de no ser válidos.

### Entidad Usuario

El usuario posee los atributos "nombreUsuario" (hasta 20 caracteres Unicode), "contrasena" (hash MD5, expresado en formato hexadecimal con 32 caracteres) y "esAdmin" (que toma el valor 0 si el usuario no es administrador, y distinto de 0 en caso contrario).

La clave primaria de esta entidad es el nombre de usuario.

Hay un usuario preexistente con privilegios de administrador, que tiene nombre de usuario y contraseña ``admin``.

- **Para obtener los datos de usuarios**: ``SELECT * FROM `USUARIO` ``.
- **Para crear un usuario**: ``INSERT INTO `USUARIO` SET `nombreUsuario` = 'elquesea', `contrasena` = '27bfe1981e965f5f7e30fd69333469f9', `esAdmin` = TRUE/FALSE``.
- **Para editar un usuario**: ``UPDATE `USUARIO` SET `nombreUsuario` = 'elquesea', `contrasena` = '27bfe1981e965f5f7e30fd69333469f9', `esAdmin` = TRUE/FALSE` WHERE `nombreUsuario` = `elqueera` `` (pueden omitirse del UPDATE los atributos que no se modifiquen).
- **Para borrar un usuario**: ``DELETE FROM `USUARIO` WHERE `nombreUsuario` = `elquesea` ``.

### Entidad Trabajo

Trabajo es la superclase abstracta (que no se instancia) de las Tareas y Fases. Todo Trabajo (y, por herencia, Tarea y Fase) tiene los atributos "id" (identificador único generado automáticamente por el SGBD), "descr" (descripción de hasta 1000 caracteres), "fechaAlta" (rellenada automáticamente por el SGBD al insertar la entidad) y "cerrada" (que toma el valor 0 si el trabajo no está cerrado y 1 si lo está). Además, un Trabajo (y, por herencia, una Tarea y Fase) puede tener archivos asociados a él. Los archivos asociados son rutas relativas desde el directorio ``/var/www/html``, que empiezan por /.

La clave primaria de un Trabajo es su identificador.

- **Para obtener los archivos asociados a trabajos (tareas o fases)**: ``SELECT * FROM `ARCHIVOS` ``.
- **Para asociar un archivo con un trabajo (tarea o fase)**: ``INSERT INTO `ARCHIVOS` SET = `idTrabajo` = id, `archivo` = rutaArchivo``. El SGBD comprobará que el fichero existe.
- **Para editar una asociación de archivo con un trabajo (tarea o fase)**: ``UPDATE `ARCHIVOS` SET = `idTrabajo` = idNueva, `archivo` = rutaArchivo WHERE `idTrabajo` = id`` (pueden omitirse del UPDATE los atributos que no se modifiquen). El SGBD comprobará que el fichero existe.
- **Para borrar la asociación de un archivo con un trabajo (tarea o fase)**: ``DELETE FROM `ARCHIVOS` WHERE `idTrabajo` = id``. Al realizar esta acción el fichero asociado no se borra automáticamente del disco.

### Entidad Tarea

Una Tarea es un tipo de Trabajo, que pertenece a una única Categoría y tiene siempre una y solo una Prioridad. Además, una tarea puede tener Contactos asociados.

- **Para obtener los datos de tareas**: ``SELECT * FROM `TAREA_Y_ARCHIVOS` ``. `TAREA_Y_ARCHIVOS` se trata de una vista no modificable que contiene, aparte de todos los atributos de la propia Tarea, atributos de la Prioridad y Categoría a la que pertenece. Los archivos asociados aparecen en una única columna separados por el caracter |.
- **Para crear una tarea**: mediante una llamada al procedimiento almacenado con ``CALL CrearTarea(descr, cerrada, numPrioridad, idCategoria)``.
- **Para editar una tarea**: mediante una llamada al procedimiento almacenado con ``CALL ModificarTarea(idTarea, nuevoIdTarea, descr, cerrada, numPrioridad, idCategoria)``. Normalmente no será necesario ni recomendable cambiar el ID.
- **Para eliminar una tarea**: mediante una llamada al procedimiento almacenado con ``CALL EliminarTarea(idTarea)``.
- **Para vincular un contacto con una tarea**: ``CALL VincularContactoTarea(idContacto, idTarea)``.
- **Para desvincular un contacto de una tarea**: ``CALL DesvincularContactoTarea(idContacto, idTarea)``.
- **Para ver los contactos asociados a tareas**: ``SELECT * FROM `CONTACTOS_TAREA` ``. Esta vista muestra, además, los datos disponibles del contacto asociado.

### Entidad Fase

Una Fase es, esencialmente, una tarea dentro de otra Tarea, por lo que es el segundo y último tipo de Trabajo que implementaremos. Sin embargo, una Fase no tiene Contactos asociados, y tampoco puede tener una Prioridad o Categoría propias (tras leer varias veces los requisitos, me pareció que se deben de interpretar así, teniendo en cuenta las palabras que se usaron en la descripción textual).

A mayores de los atributos de un Trabajo, una Fase tiene el atributo "idTarea", que es el identificador de la Tarea que la contiene.

- **Para obtener los datos de las fases**: ``SELECT * FROM `FASE_Y_ARCHIVOS` ``. De nuevo, se trata de una vista no modificable, donde los archivos se separan por el caracter |.
- **Para crear una fase**: ``CALL CrearFase(descr, cerrada, idTarea)``.
- **Para editar una fase**: ``CALL ModificarFase(idFase, nuevoIdFase, descr, cerrada, idTarea)``. Normalmente no será necesario ni recomendable cambiar el ID.
- **Para eliminar una fase**: ``CALL EliminarFase(idFase)``.

### Entidad Categoría

Una Categoría de Tareas tiene como atributos "id" (su identificador numérico, generado automáticamente por el SGBD) y "nombre" (el nombre de la categoría, de hasta 50 caracteres).

La clave primaria de una Categoría es su identificador. Su nombre consistuye una clave candidata, por lo que no puede haber dos categorías con un mismo nombre.

Al inicializarse la BD, se crea automáticamente una Categoría de nombre "Sin categoría", con identificador 1.

- **Para obtener los datos de las categorías**: ``SELECT * FROM `CATEGORIA` ``.
- **Para crear una categoría**: ``INSERT INTO `CATEGORIA` SET `nombre` = nombre``.
- **Para editar una categoría**: ``UPDATE `CATEGORIA` SET `id` = nuevoidsiaplicable, `nombre` = nombre``. Normalmente no será necesario ni recomendable cambiar el ID.
- **Para eliminar una categoría**: ``DELETE FROM `CATEGORIA` WHERE `id` = id``. Es posible que esta operación dé un error porque la Categoría haya sido asociada a una Tarea, así que hay que desvincular las Tareas de una Categoría antes de proceder a su borrado.

### Entidad Prioridad

Una Prioridad tiene como atributos "num" (su número de prioridad) y "color" (su color, expresado en notación hexadecimal; por ejemplo, el blanco puro sería `ffffff`).

La clave primaria de una Prioridad es su número, por lo que no puede haber más de una prioridad con un mismo número. No obstante, puede haber varias Prioridades con un mismo color.

Al inicializarse la BD, se crea automáticamente una Prioridad de color `d6d6d6` (gris claro) con número 0.

- **Para obtener los datos de las prioridades**: ``SELECT * FROM `PRIORIDAD` ``. Internamente, se trata de una vista semiactualizable, pudiéndose cambiar solamente el valor del atributo "num". Sin embargo, no se recomienda su edición directa.
- **Para crear una prioridad**: ``CALL CrearPrioridad(num, color)``.
- **Para modificar una prioridad**: ``CALL ModificarPrioridad(num, nuevoNum, color)``.
- **Para eliminar una prioridad**: ``DELETE FROM `PRIORIDAD` WHERE `num` = num``. Es posible que esta operación dé un error porque la Prioridad haya sido asociada a una Tarea, así que hay que desvincular las Tareas de una Prioridad antes de proceder a su borrado.

### Entidad Contacto

Los atributos que definen a un Contacto son su "id" (identificador único del contacto, generado automáticamente por el SGBD), "nombre" (de hasta 60 caracteres), "desc" (descripción de hasta 150 caracteres), "telf" (número nacional español de 9 cifras) y "email" (de hasta 60 caracteres).

La clave primaria de un Contacto es su identificador único, por lo que puede haber Contactos duplicados (mantener índices para garantizar la unicidad de todos los atributos, requisito impuesto por MySQL/MariaDB, se ha estimado demasiado caro, y no está especificado en los requisitos).

- **Para obtener los datos de los contactos**: ``SELECT * FROM `CONTACTO` ``.
- **Para crear un contacto**: ``INSERT INTO `CONTACTO` SET `nombre` = nombre, `desc` = descr, `telf` = telf, `email` = email``.
- **Para editar un contacto**: ``UPDATE `CONTACTO` SET `id` = nuevoId, `nombre` = nombre, `desc` = descr, `telf` = telf, `email` = email``. Normalmente no será necesario ni recomendable cambiar el ID, y pueden omitirse del UPDATE atributos que no cambien.
- **Para eliminar un contacto**: ``DELETE FROM `CONTACTO` WHERE `id` = id``. El Contacto será automáticamente desvinculado de cualquier Tarea a la que esté asociado.