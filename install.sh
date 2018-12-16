#!/bin/bash
# Función: script de configuración inicial de la aplicación web JustDo
# Autor: Alejandro González García
# Fecha de creación: 15/12/2018

##############
# Parámetros #
##############

# Nombre del script SQL. Debe de estar en el directorio de trabajo
readonly SCRIPT_SQL='JustDo.sql'

# Nombre del usuario con el que conectarse a MySQL/MariaDB
readonly USUARIO_MYSQL='root'

##########
# Código #
##########

# Esta función muestra un mensaje de error y sale del script, devolviendo como valor de salida
# al SO el valor de salida del último comando ejecutado
function salirConError {
	echo $1
	echo '! Instalación y configuración de la aplicación abortada.'
	exit $?
}

echo '********************************'
echo '* INSTALADOR APLICACIÓN JUSTDO *'
echo '********************************'
echo

# Comprobar que estamos siendo ejecutados como root
if [ `id -u` != 0 ]; then
	echo '! Se necesitan privilegios de superusuario para ejecutar este script. Por favor, vuélvelo a abrir como root.'
fi

# Establecer parámetros del demonio de MariaDB necesarios para evitar la posibilidad de que trunquen datos
# en algunas vistas
echo '> Estableciendo parámetros de configuración del demonio de MySQL/MariaDB...'
echo -e '[mysqld]\ngroup_concat_max_len=4294967295' > /etc/mysql/conf.d/justdo.cnf

# No continuar si hubo un error
if [ $? != 0 ]; then
	salirConError '! Ha ocurrido un error de E/S al establecer los parámetros.'
else
	chmod 644 /etc/mysql/conf.d/justdo.cnf
	echo '- Parámetros establecidos.'
fi

# Reiniciar demonio para cargar los parámetros
echo '> Reiniciando demonio de MySQL/MariaDB para aplicar los parámetros...'
service mysqld restart

# No continuar si hubo un error
if [ $? != 0 -o `service mysqld status | grep -c 'active (running)'` != 1 ]; then
	salirConError '! Ha ocurrido un error al reiniciar el demonio.'
else
	echo "- Demonio reiniciado. La consulta SHOW VARIABLES LIKE 'group_concat_max_len' debería de devolver el valor 4294967295."
fi

# Ejecutar el script SQL de configuración, si existe
if [ -f "$SCRIPT_SQL" -a -r "$SCRIPT_SQL" ]; then
	echo '> Ejecutando script SQL de configuración inicial de BD...'
	echo "Conectándose a servidor localhost como usuario $USUARIO_MYSQL"

	# Pasar argumento de verbosidad de ejecución del script SQL a mysql, si el que tenemos es válido
	if [ "$1" = '-v' -o "$1" = '--verbose' ]; then
		opcVerboso='--verbose'
	fi
	
	# Ejecutar el script SQL usando el cliente MySQL/MariaDB
	/usr/bin/mysql $opcVerboso --default-character-set='utf8mb4' --user "$USUARIO_MYSQL" --host='localhost' --password --execute="`cat $SCRIPT_SQL`"
	
	# No continuar si hubo un error
	if [ $? != 0 ]; then
		salirConError '! Ha ocurrido un error durante la ejecución del script SQL. La BD creada podría estar en un estado inconsistente. Por favor, si estás desarrollando esta aplicación, investiga la causa y corrígela.'
	else
		echo '- La BD de la aplicación ha sido inicializada correctamente. Se ha creado (o recreado) un usuario con las siguientes credenciales:'
		echo
		echo -e '	Nombre de usuario	Contraseña'
		echo -e '	JustDo			JustDo'
	fi
else
	salirConError '! No se ha encontrado el script que configura la base de datos inicialmente. Colócalo en el directorio de trabajo y vuelve a ejecutar este script.'
fi

echo

# TODO: crear ficheros, carpetas y asignar permisos