#/bin/bash

if [ ! -f /var/lib/mysql/ibdata1 ]; then

	mysql_install_db

	/usr/bin/mysqld_safe &
	sleep 10s

	echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'changeme' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql

	killall mysqld
	sleep 10s
fi

cat /opt/PGN_db.sql
/usr/bin/mysqld_safe

# initialize database.
#mysql --user=admin --password=changeme < /opt/PGN_db.sql
#echo Exit: $?
