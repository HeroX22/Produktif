MYSQL_USER="root"

sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt install apache2 -y
sudo systemctl enable apache2 && sudo systemctl start apache2
apt install mariadb-server libapache2-mod-php unzip -y
sudo apt install php php-cli php-common php-gd php-xmlrpc php-fpm php-curl php-intl php-imagick php-mysql php-zip  php-xml php-mbstring php-bemath -y
sudo systemctl start mariadb && sudo systemctl enable mariadb

mysql -u $MYSQL_USER -e "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY '';"
mysql -u $MYSQL_USER -e "CREATE DATABASE wordpress CHARACTER SET utf8 COLLATE utf8_bin;"
mysql -u $MYSQL_USER -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';"
mysql -u $MYSQL_USER -e "FLUSH PRIVILEGES;"

wget https://wordpress.org/latest.zip
unzip latest.zip
rm latest.zip
cd wordpress/
mv * /var/www/html
chown -R www-data:www-data *
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;

mv wp-config-sample.php wp-config.php
nano wp-config.php
