#!/bin/bash

# Mencetak "made by HeroX" sepuluh kali
for i in {1..10}; do
    echo "made by HeroX"
done

clear

MYSQL_USER="root"

# Memperbarui dan menginstal paket
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt install apache2 -y
sudo systemctl enable apache2 && sudo systemctl start apache2
sudo apt install mariadb-server libapache2-mod-php unzip wget curl -y
sudo apt install php php-cli php-common php-gd php-xmlrpc php-fpm php-curl php-intl php-imagick php-mysql php-zip php-xml php-mbstring -y
sudo systemctl start mariadb && sudo systemctl enable mariadb

# Mengatur database MySQL
mysql -u $MYSQL_USER -e "CREATE USER 'wordpress'@'localhost' IDENTIFIED BY '';"
mysql -u $MYSQL_USER -e "CREATE DATABASE wordpress CHARACTER SET utf8 COLLATE utf8_bin;"
mysql -u $MYSQL_USER -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost';"
mysql -u $MYSQL_USER -e "FLUSH PRIVILEGES;"

# Mengunduh dan mengekstrak WordPress
wget https://wordpress.org/latest.zip
unzip latest.zip
rm latest.zip
cd wordpress/
mv * /var/www/html/
cd /var/www/html
sudo chown -R www-data:www-data *
find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;

# Menyalin dan mengonfigurasi wp-config.php
mv wp-config-sample.php wp-config.php

sed -i -e "s/'database_name_here'/'wordpress'/g" \
       -e "s/'username_here'/'wordpress'/g" \
       -e "s/'password_here'/''/g" \
       "wp-config.php"

# Memulai ulang Apache
sudo service apache2 restart

# Mendapatkan IP lokal
local_ip=$(hostname -I | awk '{print $1}')

# Mendapatkan IP publik
public_ip=$(curl -s ip.me)

# Menampilkan pesan
echo "Jika kamu hanya latihan silahkan buka IP lokal: $local_ip"
echo "Jika kamu menggunakan ID Cloudhost, silahkan buka IP publik: $public_ip"
