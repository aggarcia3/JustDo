-- --------------------------------------------------- --
-- Script de creación de la BD para el proyecto JustDo --
-- --------------------------------------------------- --
-- Autor: Alejandro González García
-- Fecha de creación: 14/12/2018

-- Desactivamos la creación y confirmación automática de transacciones,
-- pues queremos que la inicialización de la BD sea una operación atómica,
-- consistente y aislada, y empezamos la transacción
SET autocommit = 0;
START TRANSACTION;

-- ----------------------------------------- --
-- Borrado de usuarios, BD y objetos creados --
-- ----------------------------------------- --

DROP USER IF EXISTS 'JustDo';

-- Al borrar la BD, se borran todos los objetos de ella: tablas, procedimientos, vistas...
DROP DATABASE IF EXISTS `JustDo`;

-- -------------------- --
-- Creación de usuarios --
-- -------------------- --

-- Usuario JustDo, contraseña 'JustDo', autorizado a conectarse
-- desde el host local
CREATE OR REPLACE USER 'JustDo'@'localhost' IDENTIFIED BY 'JustDo';

-- -------------- --
-- Creación de BD --
-- -------------- --

-- BD JustDo, con codificación de caracteres UTF-8 de hasta 4 bytes que soporta
-- cualquier caracter del estándar Unicode (más allá del BMP), y una
-- colación de caracteres de español tradicional (donde ch y ll cuentan como una letra,
-- para acomodar texto en gallego) que no distingue entre mayúsculas y minúsculas
CREATE DATABASE IF NOT EXISTS `JustDo`
	DEFAULT CHARACTER SET = 'utf8mb4'
	DEFAULT COLLATE = 'utf8mb4_spanish2_ci';

-- ---------------------------- --
-- Creación de tablas e índices --
-- ---------------------------- --

-- Tabla (e índice compuesto por nombreUsuario y contrasena) para las entidades
-- Usuario normal y Administrador, especializaciones totales de Usuario que se
-- distinguen por el valor del atributo esAdmin (más eficiente en CPU, evita uniones
-- para realizar la autenticación)

-- Información relevante para el usuario de la BD: esAdmin es un entero sin signo de un byte
-- (booleano al estilo C), y el nombre de usuario tiene hasta 20 caracteres de longitud
-- (los caracteres multibyte se cuentan como un carácter). Las comparaciones con el nombre de usuario
-- tienen en cuenta diferencias entre mayúsculas y minúsculas
CREATE TABLE IF NOT EXISTS `JustDo`.`USUARIO` (
	`nombreUsuario` VARCHAR(20) COLLATE 'utf8mb4_bin' NOT NULL,
	`contrasena` CHAR(32) CHARACTER SET 'ascii' COLLATE 'ascii_general_ci' NOT NULL COMMENT 'Hash MD5 de la contraseña del usuario en formato hexadecimal',
	`esAdmin` TINYINT UNSIGNED NOT NULL,

	CONSTRAINT `pk_usuario` PRIMARY KEY USING HASH (`nombreUsuario`)
);

-- Tabla e índice simple para la superclase Trabajo, que es una generalización de las subclases
-- Tarea y Fase (una Tarea contiene Fases). La diferencia entre ellas son las relaciones que
-- mantienen con otras entidades. Se crearon varias tablas para minimizar la ocurrencia de
-- valores nulos, que aparecerán bastantes, a costa de tener que realizar joins

-- Información relevante para el usuario de la BD: id es un entero sin signo de 4 bytes
-- y se rellena automáticamente, desc admite hasta 1000 caracteres, fechaAlta se rellena automáticamente
-- con la fecha y hora actuales y puede presentar el problema Y2K38 (aunque no se estima importante), y
-- cerrado es un booleano al estilo C (entero sin signo de un byte)
CREATE TABLE IF NOT EXISTS `JustDo`.`TRABAJO` (
	`id` INT UNSIGNED AUTO_INCREMENT,
	`desc` VARCHAR(1000) NOT NULL,
	`fechaAlta` TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`cerrado` TINYINT UNSIGNED NOT NULL,

	CONSTRAINT `pk_trabajo` PRIMARY KEY USING HASH (`id`)
);

-- Implementa el atributo multivaluado ficheros para la entidad Trabajo

-- Información relevante para el usuario de la BD: véase el COMMENT del atributo archivo tres líneas más abajo
CREATE TABLE IF NOT EXISTS `JustDo`.`ARCHIVOS` (
	`idTrabajo` INT UNSIGNED NOT NULL,
	`archivo` VARCHAR(255) CHARACTER SET 'ascii' COLLATE 'ascii_bin' NOT NULL COMMENT 'Ruta relativa al fichero, colgando de /var/www/html, con / inicial. Ejemplo: /Files/mifichero.pdf, que haría referencia a /var/www/html/Files/mifichero.pdf',

	CONSTRAINT `pk_archivos` PRIMARY KEY USING HASH (`idTrabajo`, `archivo`),
	CONSTRAINT `fk_archivos` FOREIGN KEY (`idTrabajo`) REFERENCES `JustDo`.`TRABAJO`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Tabla e índices simples para la subclase Fase. Ésta se relaciona con la Tarea que la contiene de modo total
-- (no hay una Fase sin una Tarea que la contiene)
CREATE TABLE IF NOT EXISTS `JustDo`.`FASE` (
	`idTrabajo` INT UNSIGNED NOT NULL,
	`idTarea` INT UNSIGNED NOT NULL,

	CONSTRAINT `pk_fase` PRIMARY KEY USING HASH (`idTrabajo`),
	CONSTRAINT `fk_fase_trabajo` FOREIGN KEY (`idTrabajo`) REFERENCES `JustDo`.`TRABAJO`(`id`) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Tabla e índice simple por la PK para la entidad Contacto

-- Información relevante para el usuario de la BD: nombre tiene hasta 60 caracteres y desc hasta 150 y
-- email hasta 60, distinguiendo entre mayúsculas y minúsculas. El id se genera automáticamente
CREATE TABLE IF NOT EXISTS `JustDo`.`CONTACTO` (
	`id` INT UNSIGNED AUTO_INCREMENT,
	`nombre` VARCHAR(60) NOT NULL,
	`desc` VARCHAR(150) NOT NULL,
	`telf` INT UNSIGNED NOT NULL COMMENT 'Número nacional español',	-- Porque log2(999 999 999 + 1) = 29,897 y un INT ocupa 32 bits
	`email` VARCHAR(60) COLLATE 'utf8mb4_bin' NOT NULL,

	CONSTRAINT `pk_contacto` PRIMARY KEY USING HASH (`id`)
);

-- Tabla e índices simples para la entidad Prioridad

-- Información relevante para el usuario de la BD: color se representa como un número. Para construir
-- el valor de color a guardar en la BD a partir de una representación RGB es necesario usar operadores
-- de bits (máscaras y desplazamientos). Este proceso es reversible sin pérdida de información
CREATE TABLE IF NOT EXISTS `JustDo`.`PRIORI` (
	`num` SMALLINT UNSIGNED NOT NULL,
	`color` INT UNSIGNED NOT NULL COMMENT 'Representado como el número equivalente al color hexadecimal en HTML/CSS, sin transparencia',

	CONSTRAINT `pk_priori` PRIMARY KEY USING HASH (`num`)
);

-- Tabla e índices simples para la entidad Categoría

-- Información relevante para el usuario de la BD: el nombre alberga hasta 50 caracteres, y el id
-- se genera automáticamente
CREATE TABLE IF NOT EXISTS `JustDo`.`CATEGORIA` (
	`id` SMALLINT UNSIGNED AUTO_INCREMENT,
	`nombre` VARCHAR(50) NOT NULL,

	CONSTRAINT `pk_categoria` PRIMARY KEY USING HASH (`id`),
	CONSTRAINT `clave_candidata_categoria` UNIQUE USING HASH (`nombre`)
);

-- Tabla e índices simples para la subclase Tarea. Ésta se relaciona con una Prioridad y una Categoría
-- de modo total (no hay Tareas sin una Prioridad o Categoría asociada)
CREATE TABLE IF NOT EXISTS `JustDo`.`TAREA` (
	`idTrabajo` INT UNSIGNED NOT NULL,
	`numPrioridad` SMALLINT UNSIGNED NOT NULL,
	`idCategoria` SMALLINT UNSIGNED NOT NULL,

	CONSTRAINT `pk_tarea` PRIMARY KEY USING HASH (`idTrabajo`),
	CONSTRAINT `fk_tarea_trabajo` FOREIGN KEY (`idTrabajo`) REFERENCES `JustDo`.`TRABAJO`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT `fk_tarea_prioridad` FOREIGN KEY (`numPrioridad`) REFERENCES `JustDo`.`PRIORI`(`num`) ON DELETE NO ACTION ON UPDATE CASCADE,
	CONSTRAINT `fk_tarea_categoria` FOREIGN KEY (`idCategoria`) REFERENCES `JustDo`.`CATEGORIA`(`id`) ON DELETE NO ACTION ON UPDATE CASCADE
);

-- Añadimos la restricción de FK que no fue posible añadir antes porque las tablas necesarias no estaban
-- definidas
ALTER TABLE `JustDo`.`FASE` ADD CONSTRAINT `fk_fase_tarea` FOREIGN KEY (`idTarea`) REFERENCES `JustDo`.`TAREA`(`idTrabajo`) ON DELETE NO ACTION ON UPDATE CASCADE;

-- Relación se-asocia-con varios a varios sin participación total de Contacto con Tarea
CREATE TABLE `JustDo`.`CONTACTO_TAREA` (
	`idContacto` INT UNSIGNED NOT NULL,
	`idTarea` INT UNSIGNED NOT NULL,

	CONSTRAINT `pk_contacto_tarea` PRIMARY KEY USING HASH (`idContacto`, `idTarea`),
	CONSTRAINT `fk_contacto_tarea_contacto` FOREIGN KEY (`idContacto`) REFERENCES `JustDo`.`CONTACTO`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT `fk_contacto_tarea_tarea` FOREIGN KEY (`idTarea`) REFERENCES `JustDo`.`TAREA`(`idTrabajo`) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ------------------------------------ --
-- Sentencias DDL de creación de vistas --
-- ------------------------------------ --

SET @@GLOBAL.group_concat_max_len = 4294967295;

-- Vista no actualizable para recuperar todos los datos disponibles de una Tarea.
-- Los archivos asociados a ella se devuelven como un atributo monovaluado, separando los diferentes
-- valores por el caracter |
CREATE OR REPLACE ALGORITHM = UNDEFINED SQL SECURITY DEFINER
	VIEW `JustDo`.`TAREA_Y_ARCHIVOS`(`id`, `desc`, `fechaAlta`, `cerrada`, `archivos`, `numPrioridad`, `colorPrioridad`, `idCategoria`, `nombreCategoria`)
	AS SELECT `TRABAJO`.`id`, `desc`, `fechaAlta`, `cerrado`, GROUP_CONCAT(`archivo` SEPARATOR '|'), `numPrioridad`, LOWER(HEX(`color`)), `CATEGORIA`.`ID`, `nombre`
	FROM (`JustDo`.`TRABAJO`, `JustDo`.`TAREA`, `JustDo`.`CATEGORIA`, `JustDo`.`PRIORI`) LEFT JOIN `JustDo`.`ARCHIVOS` ON `TAREA`.`idTrabajo` = `ARCHIVOS`.`idTrabajo`
	WHERE `TRABAJO`.`id` = `TAREA`.`idTrabajo` AND `TAREA`.`idCategoria` = `CATEGORIA`.`id`
	AND `TAREA`.`numPrioridad` = `PRIORI`.`num`;

-- Vista actualizable para recuperar y modificar los Contactos asociados a cada Tarea
-- ¡OJO! No se puede borrar tuplas de esta vista
CREATE OR REPLACE ALGORITHM = UNDEFINED SQL SECURITY DEFINER
	VIEW `JustDo`.`CONTACTOS_TAREA`(`idTarea`, `idContacto`, `nombre`, `desc`, `telf`, `email`)
	AS SELECT `idTarea`, `idContacto`, `nombre`, `desc`, `telf`, `email`
	FROM `JustDo`.`CONTACTO_TAREA` NATURAL JOIN `JustDo`.`CONTACTO`;

-- Vista no actualizable para recuperar todos los datos disponibles de una Fase.
-- Los archivos asociados a ella se devuelven como un atributo monovaluado, separando los diferentes
-- valores por el caracter |
CREATE OR REPLACE ALGORITHM = UNDEFINED SQL SECURITY DEFINER
	VIEW `JustDo`.`FASE_Y_ARCHIVOS`(`id`, `idTarea`, `desc`, `fechaAlta`, `cerrada`, `archivos`)
	AS SELECT `id`, `idTarea`, `desc`, `fechaAlta`, `cerrado`, GROUP_CONCAT(`archivo` SEPARATOR '|')
	FROM (`JustDo`.`TRABAJO`, `JustDo`.`FASE`) LEFT JOIN `JustDo`.`ARCHIVOS` ON `FASE`.`idTrabajo` = `ARCHIVOS`.`idTrabajo`
	WHERE `TRABAJO`.`id` = `FASE`.`idTrabajo`;

-- Vista para recuperar los datos de una Prioridad, transformando el entero guardado para el atributo
-- color a una cadena de texto en hexadecimal para la visualización
CREATE OR REPLACE ALGORITHM = UNDEFINED SQL SECURITY DEFINER
	VIEW `JustDo`.`PRIORIDAD`(`num`, `color`)
	AS SELECT `num`, LPAD(LOWER(HEX(`color`)), 6, '0') FROM `JustDo`.`PRIORI`;

-- ------------------------------------------ --
-- Sentencias DML para inicializar las tablas --
-- ------------------------------------------ --

-- Usuario administrador preexistente, de nombre de usuario "admin" y contraseña "admin"
INSERT INTO `JustDo`.`USUARIO` SET `nombreUsuario` = 'admin', `contrasena` = '21232f297a57a5a743894a0e4a801fc3', `esAdmin` = TRUE;

-- Categoría por defecto. Usada cuando no se asignó otra a la tarea
INSERT INTO `JustDo`.`CATEGORIA` SET `nombre` = 'Sin categoría';
-- Prioridad por defecto, con color gris claro (#d6d6d6). Usada cuando no se asignó otra a la tarea
INSERT INTO `JustDo`.`PRIORI` SET `num` = 0, `color` = 14079702;

-- ------------------------------------------------------ --
-- Sentencias de definición de procedimientos y funciones --
-- ------------------------------------------------------ --

-- Cambiamos el delimitador de sentencias a /; debido a que usaremos el ;
-- dentro de cada sentencia SQL compuesta para los procedimientos
DELIMITER /;

-- Inserta una nueva Tarea en el sistema, como una operación atómica
CREATE PROCEDURE `JustDo`.`CrearTarea`(IN descr VARCHAR(1000), IN cerrada TINYINT UNSIGNED, IN prioridad SMALLINT UNSIGNED, IN categoria SMALLINT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';
	-- El valor a insertar en la BD para el atributo cerrada
	DECLARE valCerrado TINYINT UNSIGNED;
	-- ID de la tupla insertada
	DECLARE id INT UNSIGNED;

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(descr) OR ISNULL(cerrada) OR ISNULL(prioridad) OR ISNULL(categoria) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'Algún atributo de la tarea es nulo.';
	END IF;

	-- Normalizar el valor del atributo cerrada
	IF cerrada = 0 THEN
		SET valCerrado = FALSE;
	ELSE
		SET valCerrado = TRUE;
	END IF;

	-- Realizar sentencias DML para insertar tuplas en la superclase y subclase
	START TRANSACTION;
	INSERT INTO `TRABAJO` SET `desc` = descr, `cerrado` = valCerrado;
	SET id = LAST_INSERT_ID();
	INSERT INTO `TAREA` SET `idTrabajo` = id, `numPrioridad` = prioridad, `idCategoria` = categoria;
	COMMIT;
END/;

-- Elimina una tarea del sistema, como una operación atómica, a partir de su ID.
-- Este procedimiento es necesario porque no se pueden borrar tuplas de la vista
-- correspondiente
CREATE PROCEDURE `JustDo`.`EliminarTarea`(IN tarea INT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(tarea) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'El ID de la tarea a eliminar no puede ser nulo.';
	END IF;

	-- Realizar sentencia DML para borrar el objeto de su superclase
	-- (la declaración como ON DELETE CASCADE de la FK borrará la entidad automáticamente de las subclases)
	START TRANSACTION;
	DELETE FROM `TRABAJO` WHERE `id` = tarea;
	COMMIT;
END/;

-- Vincula un contacto de una Tarea, a partir de los ID de ambos. Esta operación no crea
-- Contactos o Tareas
CREATE PROCEDURE `JustDo`.`VincularContactoTarea`(IN contacto INT UNSIGNED, IN tarea INT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(contacto) OR ISNULL(tarea) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'No se pueden vincular contactos de tareas cuando uno de ellos tiene una clave primaria especificada nula.';
	END IF;

	-- Realizar sentencias DML para crear una instancia particular de la relación Contacto-Tarea
	START TRANSACTION;
	INSERT INTO `CONTACTO_TAREA` SET `idContacto` = contacto, `idTarea` = tarea;
	COMMIT;
END/;

-- Desvincula un contacto de una Tarea, a partir de los ID de ambos. Esta operación no borra
-- Contactos o Tareas, que seguirán existiendo en la BD, aunque ya no aparecerán relacionados en la vista
-- CONTACTOS_TAREA
CREATE PROCEDURE `JustDo`.`DesvincularContactoTarea`(IN contacto INT UNSIGNED, IN tarea INT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(contacto) OR ISNULL(tarea) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'No se pueden desvincular contactos de tareas cuando uno de ellos tiene una clave primaria especificada nula.';
	END IF;

	-- Realizar sentencias DML para borrar una instancia particular de la relación Contacto-Tarea
	START TRANSACTION;
	DELETE FROM `CONTACTO_TAREA` WHERE `idContacto` = contacto AND `idTarea` = tarea;
	COMMIT;
END/;

-- Modifica una Tarea existente
CREATE PROCEDURE `JustDo`.`ModificarTarea`(IN tarea INT UNSIGNED, IN nuevoId INT UNSIGNED, IN descr VARCHAR(1000), IN cerrada TINYINT UNSIGNED, IN prioridad SMALLINT UNSIGNED, IN categoria SMALLINT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(tarea) OR ISNULL(nuevoId) OR ISNULL(descr) OR ISNULL(cerrada) OR ISNULL(prioridad) OR ISNULL(categoria) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'No se puede modificar un atributo de una tarea a un valor nulo.';
	END IF;

	-- Realizar sentencias DML para la actualización de los atributos de la superclase y la subclase
	START TRANSACTION;
	UPDATE `TRABAJO` SET `id` = nuevoId, `desc` = descr, `cerrado` = cerrada WHERE `id` = tarea;
	UPDATE `TAREA` SET `numPrioridad` = prioridad, `idCategoria` = categoria WHERE `idTrabajo` = nuevoId;
	COMMIT;
END/;

-- Inserta una nueva Fase en el sistema, como una operación atómica
CREATE PROCEDURE `JustDo`.`CrearFase`(IN descr VARCHAR(1000), IN cerrada TINYINT UNSIGNED, IN tarea INT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';
	-- El valor a insertar en la BD para el atributo cerrada
	DECLARE valCerrado TINYINT UNSIGNED;
	-- ID de la tupla insertada
	DECLARE id INT UNSIGNED;

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(descr) OR ISNULL(cerrada) OR ISNULL(tarea) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'Algún atributo de la fase es nulo.';
	END IF;

	-- Normalizar el valor del atributo cerrado
	IF cerrada = 0 THEN
		SET valCerrado = FALSE;
	ELSE
		SET valCerrado = TRUE;
	END IF;

	-- Realizar sentencias DML para insertar tuplas en la superclase y subclase
	START TRANSACTION;
	INSERT INTO `TRABAJO` SET `desc` = descr, `cerrado` = valCerrado;
	SET id = LAST_INSERT_ID();
	INSERT INTO `FASE` SET `idTrabajo` = id, `idTarea` = tarea;
	COMMIT;
END/;

-- Elimina una fase del sistema, como una operación atómica, a partir de su ID.
-- Este procedimiento es necesario porque no se pueden borrar tuplas de la vista
-- correspondiente
CREATE PROCEDURE `JustDo`.`EliminarFase`(IN fase INT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(fase) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'El ID de la fase a eliminar no puede ser nulo.';
	END IF;

	-- Realizar sentencia DML para borrar el objeto de su superclase
	-- (la declaración como ON DELETE CASCADE de la FK borrará la entidad automáticamente de las subclases)
	START TRANSACTION;
	DELETE FROM `TRABAJO` WHERE `id` = fase;
	COMMIT;
END/;

-- Modifica una Fase existente
CREATE PROCEDURE `JustDo`.`ModificarFase`(IN fase INT UNSIGNED, IN nuevoId INT UNSIGNED, IN descr VARCHAR(1000), IN cerrada TINYINT UNSIGNED, IN tarea INT UNSIGNED)
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo
	DECLARE paramNulo CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepción de parámetro nulo
	DECLARE EXIT HANDLER FOR paramNulo
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(fase) OR ISNULL(nuevoId) OR ISNULL(descr) OR ISNULL(cerrada) OR ISNULL(tarea) THEN
		SIGNAL paramNulo SET MESSAGE_TEXT = 'No se puede modificar un atributo de una fase a un valor nulo.';
	END IF;

	-- Realizar sentencias DML para la actualización de los atributos de la superclase y la subclase
	START TRANSACTION;
	UPDATE `TRABAJO` SET `id` = nuevoId, `desc` = descr, `cerrado` = cerrada WHERE `id` = fase;
	UPDATE `FASE` SET `idTarea` = tarea WHERE `idTrabajo` = nuevoId;
	COMMIT;
END/;

-- Añade una nueva Prioridad a la BD
CREATE PROCEDURE `JustDo`.`CrearPrioridad`(IN numero SMALLINT UNSIGNED, IN colorHex CHAR(6))
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo o inválido
	DECLARE paramInvalido CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepciones lanzadas por nosotros
	DECLARE EXIT HANDLER FOR paramInvalido
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(numero) OR ISNULL(colorHex) THEN
		SIGNAL paramInvalido SET MESSAGE_TEXT = 'Algún atributo de la prioridad es nulo.';
	END IF;

	-- Comprobar que la representación del color es correcta
	IF colorHex NOT REGEXP '^[0-9A-Fa-f]{6}$' THEN
		SIGNAL paramInvalido SET MESSAGE_TEXT = 'El color especificado no está en formato hexadecimal, o contiene datos de transparencia.';
	END IF;

	-- Realizar sentencia DML para insertar la Prioridad, convirtiendo el color a una
	-- representación canónica
	START TRANSACTION;
	INSERT INTO `PRIORI` SET `num` = numero, `color` = CONV(colorHex, 16, 10);
	COMMIT;
END/;

-- Modifica una prioridad existente en la BD
CREATE PROCEDURE `JustDo`.`ModificarPrioridad`(IN numero SMALLINT UNSIGNED, IN nuevoNumero SMALLINT UNSIGNED, IN colorHex CHAR(6))
	DETERMINISTIC MODIFIES SQL DATA SQL SECURITY DEFINER
BEGIN
	-- La excepción que vamos a lanzar si algún parámetro es nulo o inválido
	DECLARE paramInvalido CONDITION FOR SQLSTATE 'HY000';

	-- Propagar excepciones lanzadas por nosotros
	DECLARE EXIT HANDLER FOR paramInvalido
	BEGIN
		RESIGNAL;
	END;

	-- Hacer un rollback de cualquier sentencia DML y propagar el resto
	-- de excepciones
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		ROLLBACK;
		RESIGNAL;
	END;

	-- Lanzar una excepción si algún parámetro es nulo
	IF ISNULL(numero) OR ISNULL(colorHex) THEN
		SIGNAL paramInvalido SET MESSAGE_TEXT = 'Algún atributo de la prioridad es nulo.';
	END IF;

	-- Comprobar que la representación del color es correcta
	IF colorHex NOT REGEXP '^[0-9A-Fa-f]{6}$' THEN
		SIGNAL paramInvalido SET MESSAGE_TEXT = 'El color especificado no está en formato hexadecimal, o contiene datos de transparencia.';
	END IF;

	-- Realizar sentencia DML para actualizar la Prioridad, convirtiendo el color a una
	-- representación canónica
	START TRANSACTION;
	UPDATE `PRIORI` SET `num` = nuevoNumero, `color` = CONV(colorHex, 16, 10) WHERE `num` = numero;
	COMMIT;
END/;

-- ---------------------------------------- --
-- Sentencias de definición de disparadores --
-- ---------------------------------------- --

-- Disparador que valida el valor del atributo contrasena al insertar un Usuario
CREATE TRIGGER `JustDo`.`ValInsUsuario` BEFORE INSERT
ON `JustDo`.`USUARIO` FOR EACH ROW
BEGIN
	-- Comprobar validez de contraseña
	IF NEW.contrasena NOT REGEXP '^[0-9a-fA-F]{32}$' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contraseña no sigue el formato establecido.';
	END IF;
END/;

-- Disparador que valida el valor del atributo contrasena al modificar un Usuario
CREATE TRIGGER `JustDo`.`ValUpdUsuario` BEFORE UPDATE
ON `JustDo`.`USUARIO` FOR EACH ROW
BEGIN
	-- Comprobar validez de contraseña
	IF NEW.contrasena NOT REGEXP '^[0-9a-fA-F]{32}$' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La contraseña no sigue el formato establecido.';
	END IF;
END/;

-- Disparador que valida el valor de los atributos telf y email al insertar un Contacto
CREATE TRIGGER `JustDo`.`ValInsContacto` BEFORE INSERT
ON `JustDo`.`CONTACTO` FOR EACH ROW
BEGIN
	-- Comprobar validez de teléfono y email
	IF NEW.telf NOT REGEXP '^6[0-9]{8}|7[1-9][0-9]{7}|8[1-9][0-9]{7}|9[1-9][0-9]{7}$' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El teléfono introducido no sigue el formato establecido.';
	ELSEIF NEW.email NOT REGEXP "^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$" THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo electrónico introducido no sigue el formato establecido.';
	END IF;
END/;

-- Disparador que valida el valor de los atributos telf y email al modificar un Contacto
CREATE TRIGGER `JustDo`.`ValUpdContacto` BEFORE UPDATE
ON `JustDo`.`CONTACTO` FOR EACH ROW
BEGIN
	-- Comprobar validez de teléfono y email
	IF NEW.telf NOT REGEXP '^6[0-9]{8}|7[1-9][0-9]{7}|8[1-9][0-9]{7}|9[1-9][0-9]{7}$' THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El teléfono introducido no sigue el formato establecido.';
	ELSEIF NEW.email NOT REGEXP "^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$" THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo electrónico introducido no sigue el formato establecido.';
	END IF;
END/;

-- Disparador que valida el valor de los archivos asociados a una Fase o Tarea al asociarlos
CREATE TRIGGER `JustDo`.`ValInsArchivos` BEFORE INSERT
ON `JustDo`.`ARCHIVOS` FOR EACH ROW
BEGIN
	-- Mensaje de error que se mostrará si el parámetro es incorrecto
	DECLARE msgError VARCHAR(350);

	-- Si el fichero no existe, considerar atributo como inválido
	IF ISNULL(LOAD_FILE(CONCAT('/var/www/html', NEW.archivo))) THEN
		SET msgError = CONCAT(CONCAT('La ruta de fichero especificada no existe (ruta interpretada: /var/www/html', NEW.archivo), ').');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msgError;
	END IF;
END/;

-- Disparador que valida el valor de los archivos asociados a una Fase o Tarea al modificarlos
CREATE TRIGGER `JustDo`.`ValUpdArchivos` BEFORE UPDATE
ON `JustDo`.`ARCHIVOS` FOR EACH ROW
BEGIN
	-- Mensaje de error que se mostrará si el parámetro es incorrecto
	DECLARE msgError VARCHAR(350);

	-- Si el fichero no existe, considerar atributo como inválido
	IF ISNULL(LOAD_FILE(CONCAT('/var/www/html', NEW.archivo))) THEN
		SET msgError = CONCAT(CONCAT('La ruta de fichero especificada no existe (ruta interpretada: /var/www/html', NEW.archivo), ').');
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msgError;
	END IF;
END/;

-- Restaurar el delimitador de sentencias predeterminado
DELIMITER ;

-- -------------------------------- --
-- Concesión de permisos a usuarios --
-- -------------------------------- --

-- Dar permisos al usuario para ver solamente las tablas, vistas y procedimientos necesarios.
-- También debe de poder ejecutar disparadores
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`USUARIO` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`ARCHIVOS` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`CONTACTO` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`CATEGORIA` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`PRIORIDAD` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`TAREA_Y_ARCHIVOS` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`CONTACTOS_TAREA` TO 'JustDo'@'localhost';
GRANT SELECT, UPDATE, INSERT, DELETE, TRIGGER ON TABLE `JustDo`.`FASE_Y_ARCHIVOS` TO 'JustDo'@'localhost';

GRANT EXECUTE ON PROCEDURE `JustDo`.`CrearTarea` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`EliminarTarea` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`VincularContactoTarea` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`VincularContactoTarea` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`DesvincularContactoTarea` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`ModificarTarea` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`CrearFase` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`EliminarFase` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`ModificarFase` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`CrearPrioridad` TO 'JustDo'@'localhost';
GRANT EXECUTE ON PROCEDURE `JustDo`.`ModificarPrioridad` TO 'JustDo'@'localhost';

-- Terminar la transacción aplicando de manera persistente sus cambios, pues si llegamos aquí todo fue bien.
-- Restauramos el valor de la variable de sesión autocommit al predeterminado
COMMIT;
SET @@SESSION.autocommit = @@GLOBAL.autocommit;