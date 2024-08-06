wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-2+debian12_all.deb
dpkg -i zabbix-release_7.0-2+debian12_all.deb
apt update
apt install apache2 mariadb-server php libapache2-mod-php
apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
