#!/bin/bash

# Zabbix 6.4 Installation Script for Ubuntu 24.04
# Improved version with better error handling and security

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

# Check Ubuntu version
if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
    warn "This script is designed for Ubuntu 24.04. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

# Configuration variables
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(generate_password)}"
ZABBIX_DB_PASSWORD="${ZABBIX_DB_PASSWORD:-$(generate_password)}"
MYSQL_USER="root"
ZABBIX_VERSION="6.4"
UBUNTU_VERSION="24.04"

log "Starting Zabbix ${ZABBIX_VERSION} installation on Ubuntu ${UBUNTU_VERSION}"

# Update system
log "Updating system packages..."
apt update -y
apt upgrade -y

# Install required packages
log "Installing required packages..."
apt install -y \
    wget \
    curl \
    gnupg2 \
    software-properties-common \
    apache2 \
    mysql-server \
    php \
    php-mysql \
    php-gd \
    php-bcmath \
    php-mbstring \
    php-xml \
    php-ldap \
    libapache2-mod-php \
    expect

# Secure MySQL installation
log "Securing MySQL installation..."
systemctl start mysql
systemctl enable mysql

# Set MySQL root password using mysql_secure_installation equivalent
mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Download and install Zabbix repository
log "Adding Zabbix repository..."
cd /tmp
wget -O zabbix-release.deb "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+ubuntu${UBUNTU_VERSION}_all.deb"

if [[ ! -f "zabbix-release.deb" ]]; then
    error "Failed to download Zabbix repository package"
fi

dpkg -i zabbix-release.deb
apt update -y

# Install Zabbix packages
log "Installing Zabbix packages..."
apt install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent

# Create Zabbix database and user
log "Creating Zabbix database and user..."
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" << EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '${ZABBIX_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF

# Import initial schema and data
log "Importing Zabbix database schema..."
if [[ -f "/usr/share/zabbix-sql-scripts/mysql/server.sql.gz" ]]; then
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u zabbix -p"${ZABBIX_DB_PASSWORD}" zabbix
else
    error "Zabbix SQL scripts not found"
fi

# Reset log_bin_trust_function_creators
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Configure Zabbix server
log "Configuring Zabbix server..."
ZABBIX_CONF="/etc/zabbix/zabbix_server.conf"
cp "${ZABBIX_CONF}" "${ZABBIX_CONF}.backup"

# Update database password in configuration
sed -i "s/^# DBPassword=/DBPassword=${ZABBIX_DB_PASSWORD}/" "${ZABBIX_CONF}"

# Configure PHP for Zabbix
log "Configuring PHP settings..."
PHP_INI="/etc/php/8.3/apache2/php.ini"
cp "${PHP_INI}" "${PHP_INI}.backup"

# Update PHP settings for Zabbix
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "${PHP_INI}"
sed -i 's/^memory_limit = .*/memory_limit = 256M/' "${PHP_INI}"
sed -i 's/^post_max_size = .*/post_max_size = 32M/' "${PHP_INI}"
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 16M/' "${PHP_INI}"
sed -i 's/^max_input_time = .*/max_input_time = 300/' "${PHP_INI}"
sed -i 's/^;date.timezone =.*/date.timezone = Asia\/Jakarta/' "${PHP_INI}"

# Configure Apache
log "Configuring Apache..."
a2enmod rewrite
a2enmod ssl

# Start and enable services
log "Starting and enabling services..."
systemctl restart apache2
systemctl enable apache2

systemctl start zabbix-server
systemctl enable zabbix-server

systemctl start zabbix-agent
systemctl enable zabbix-agent

# Configure firewall if ufw is active
if systemctl is-active --quiet ufw; then
    log "Configuring firewall..."
    ufw allow 'Apache Full'
    ufw allow 10050/tcp  # Zabbix agent
    ufw allow 10051/tcp  # Zabbix server
fi

# Create credentials file
CRED_FILE="/root/zabbix_credentials.txt"
cat > "${CRED_FILE}" << EOF
=== ZABBIX INSTALLATION CREDENTIALS ===
Installation Date: $(date)
Server IP: $(hostname -I | awk '{print $1}')
Web Interface: http://$(hostname -I | awk '{print $1}')/zabbix

=== MySQL Credentials ===
MySQL Root Password: ${MYSQL_ROOT_PASSWORD}
Zabbix DB Password: ${ZABBIX_DB_PASSWORD}

=== Zabbix Web Interface ===
Initial Setup Required: Yes
Default Admin User: Admin
Default Admin Password: zabbix
Database Host: localhost
Database Name: zabbix
Database User: zabbix
Database Password: ${ZABBIX_DB_PASSWORD}

=== Important Notes ===
1. Change the default Admin password immediately after first login
2. Keep this file secure and delete it after noting the credentials
3. Backup your database regularly
4. Configure your firewall appropriately
5. Consider enabling HTTPS for production use

=== Service Status ===
Zabbix Server: $(systemctl is-active zabbix-server)
Zabbix Agent: $(systemctl is-active zabbix-agent)
Apache: $(systemctl is-active apache2)
MySQL: $(systemctl is-active mysql)
EOF

chmod 600 "${CRED_FILE}"

# Final status check
log "Performing final status check..."
sleep 10

if systemctl is-active --quiet zabbix-server && systemctl is-active --quiet apache2; then
    log "✅ Zabbix installation completed successfully!"
    echo
    log "🌐 Access your Zabbix web interface at: http://$(hostname -I | awk '{print $1}')/zabbix"
    log "📝 Credentials saved to: ${CRED_FILE}"
    echo
    log "Next steps:"
    echo "1. Open your web browser and go to the Zabbix web interface"
    echo "2. Complete the initial setup wizard"
    echo "3. Log in with username 'Admin' and password 'zabbix'"
    echo "4. Change the default password immediately"
    echo "5. Configure your monitoring requirements"
else
    error "❌ Installation completed but some services are not running properly"
    echo "Check service status with: systemctl status zabbix-server apache2 mysql"
fi

# Cleanup
log "Cleaning up temporary files..."
rm -f /tmp/zabbix-release.deb

log "Installation process completed!"