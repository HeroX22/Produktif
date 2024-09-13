sudo apt install apache2 php php-gd php-imagick php-intl php-curl php-xml php-mbstring php-zip php-mysql git libapache2-mod-php mariadb-server -y
cd /var/www/html
git clone https://github.com/laksa19/mikhmonv3
sudo cp -R mikhmonv3/* /var/www/html/
sudo rm -R mikhmonv3/
sudo chown www-data:www-data -R *
service apache2 restart

INTERFACE="eth0"
IP_ADDRESS=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
firefox http://$IP_ADDRESS &
