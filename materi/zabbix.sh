# Setting variabel
MYSQL_USER="root"
MYSQL_PASSWORD=""

wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb
dpkg -i zabbix-release_7.0-2+debian12_all.deb
apt update
apt install apache2 mariadb-server php libapache2-mod-php
apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "create database zabbix character set utf8mb4 collate utf8mb4_bin;"
mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "create user zabbix@localhost identified by '';"
mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "grant all privileges on zabbix.* to zabbix@localhost;"
mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "set global log_bin_trust_function_creators = 1;"

zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u zabbix -p zabbix

mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "set global log_bin_trust_function_creators = 0;"
