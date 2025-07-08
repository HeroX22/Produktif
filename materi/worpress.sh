#!/bin/bash

# WordPress Auto Installer Script
# Improved version with better error handling and security
# Compatible with Ubuntu/Debian systems

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
MYSQL_USER="root"
WP_DB_NAME="wordpress"
WP_DB_USER="wordpress"
WP_DB_PASS=""
WP_DIR="/var/www/html"
APACHE_USER="www-data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/wordpress-install.log"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan sebagai root (gunakan sudo)"
        exit 1
    fi
}

# Function to check OS compatibility
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Tidak dapat mendeteksi OS. Script ini hanya mendukung Ubuntu/Debian."
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        print_error "OS tidak didukung: $ID. Script ini hanya mendukung Ubuntu/Debian."
        exit 1
    fi
    
    print_status "OS terdeteksi: $PRETTY_NAME"
}

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

# Function to backup existing files
backup_existing() {
    if [[ -d "$WP_DIR" && "$(ls -A $WP_DIR)" ]]; then
        BACKUP_DIR="/tmp/wordpress_backup_$(date +%Y%m%d_%H%M%S)"
        print_warning "Direktori $WP_DIR tidak kosong. Membuat backup di $BACKUP_DIR"
        cp -r "$WP_DIR" "$BACKUP_DIR"
        print_status "Backup berhasil dibuat di $BACKUP_DIR"
    fi
}

# Function to install required packages
install_packages() {
    print_header "MENGINSTAL PAKET YANG DIPERLUKAN"
    
    # Update package lists
    print_status "Memperbarui daftar paket..."
    apt-get update -y >> "$LOG_FILE" 2>&1
    
    # Upgrade existing packages
    print_status "Mengupgrade paket yang sudah ada..."
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    
    # Install essential packages
    print_status "Menginstal Apache2..."
    apt-get install -y apache2 >> "$LOG_FILE" 2>&1
    
    print_status "Menginstal MariaDB..."
    apt-get install -y mariadb-server >> "$LOG_FILE" 2>&1
    
    print_status "Menginstal PHP dan ekstensi..."
    apt-get install -y \
        php \
        php-cli \
        php-common \
        php-gd \
        php-xmlrpc \
        php-fpm \
        php-curl \
        php-intl \
        php-imagick \
        php-mysql \
        php-zip \
        php-xml \
        php-mbstring \
        libapache2-mod-php \
        unzip \
        wget \
        curl \
        openssl >> "$LOG_FILE" 2>&1
    
    print_status "Mengaktifkan dan memulai layanan..."
    systemctl enable apache2 mariadb >> "$LOG_FILE" 2>&1
    systemctl start apache2 mariadb >> "$LOG_FILE" 2>&1
    
    # Enable required Apache modules
    a2enmod rewrite >> "$LOG_FILE" 2>&1
    a2enmod ssl >> "$LOG_FILE" 2>&1
}

# Function to secure MariaDB installation
secure_mariadb() {
    print_header "MENGAMANKAN INSTALASI MARIADB"
    
    # Generate secure root password if not set
    if [[ -z "$MYSQL_ROOT_PASS" ]]; then
        MYSQL_ROOT_PASS=$(generate_password)
        print_status "Password root MySQL yang dibuat: $MYSQL_ROOT_PASS"
    fi
    
    # Check MariaDB version and use appropriate syntax
    MARIADB_VERSION=$(mysql --version | grep -oP 'Distrib \K[0-9]+\.[0-9]+')
    print_status "MariaDB version detected: $MARIADB_VERSION"
    
    # Secure MariaDB installation using modern syntax
    mysql -u root << EOF
-- Set root password using ALTER USER (MariaDB 10.4+)
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove root login from remote hosts
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Reload privilege tables
FLUSH PRIVILEGES;
EOF
    
    if [[ $? -eq 0 ]]; then
        print_status "MariaDB berhasil diamankan"
    else
        print_warning "Gagal mengamankan MariaDB dengan ALTER USER, mencoba metode lama..."
        # Fallback untuk versi lama
        mysql -u root << EOF
UPDATE mysql.user SET authentication_string=PASSWORD('$MYSQL_ROOT_PASS') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF
    fi
    
    # Update MySQL_USER variable for subsequent operations
    MYSQL_USER="root"
}

# Function to setup WordPress database
setup_database() {
    print_header "MENYIAPKAN DATABASE WORDPRESS"
    
    # Generate secure password for WordPress database user
    if [[ -z "$WP_DB_PASS" ]]; then
        WP_DB_PASS=$(generate_password)
        print_status "Password database WordPress yang dibuat: $WP_DB_PASS"
    fi
    
    # Create database and user
    if [[ -n "$MYSQL_ROOT_PASS" ]]; then
        # If root password is set, use it
        mysql -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASS" << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    else
        # If no root password (fresh installation), connect without password
        mysql -u "$MYSQL_USER" << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    fi
    
    if [[ $? -eq 0 ]]; then
        print_status "Database dan user WordPress berhasil dibuat"
    else
        print_error "Gagal membuat database WordPress"
        exit 1
    fi
}

# Function to download and install WordPress
install_wordpress() {
    print_header "MENGUNDUH DAN MENGINSTAL WORDPRESS"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download WordPress
    print_status "Mengunduh WordPress versi terbaru..."
    wget -q https://wordpress.org/latest.zip
    
    # Verify download
    if [[ ! -f "latest.zip" ]]; then
        print_error "Gagal mengunduh WordPress"
        exit 1
    fi
    
    # Extract WordPress
    print_status "Mengekstrak WordPress..."
    unzip -q latest.zip
    
    # Backup existing files if any
    backup_existing
    
    # Clean destination directory
    rm -rf "$WP_DIR"/*
    
    # Copy WordPress files
    print_status "Menyalin file WordPress ke $WP_DIR..."
    cp -r wordpress/* "$WP_DIR/"
    
    # Set proper permissions
    print_status "Mengatur permission file..."
    chown -R "$APACHE_USER":"$APACHE_USER" "$WP_DIR"
    find "$WP_DIR" -type d -exec chmod 755 {} \;
    find "$WP_DIR" -type f -exec chmod 644 {} \;
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

# Function to configure WordPress
configure_wordpress() {
    print_header "MENGKONFIGURASI WORDPRESS"
    
    cd "$WP_DIR"
    
    # Create wp-config.php from sample
    cp wp-config-sample.php wp-config.php
    
    # Generate WordPress security keys
    print_status "Menghasilkan kunci keamanan WordPress..."
    SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    
    # Configure database settings
    sed -i "s/database_name_here/$WP_DB_NAME/g" wp-config.php
    sed -i "s/username_here/$WP_DB_USER/g" wp-config.php
    sed -i "s/password_here/$WP_DB_PASS/g" wp-config.php
    
    # Add security keys
    sed -i '/put your unique phrase here/d' wp-config.php
    sed -i "/define('AUTH_KEY'/i\\$SALT" wp-config.php
    
    # Add additional security configurations
    cat >> wp-config.php << 'EOF'

// Additional security configurations
define('DISALLOW_FILE_EDIT', true);
define('FORCE_SSL_ADMIN', false);
define('WP_POST_REVISIONS', 3);
define('AUTOSAVE_INTERVAL', 300);

// Enable WordPress debug (disable in production)
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
EOF
    
    # Set proper permissions for wp-config.php
    chmod 600 wp-config.php
    chown "$APACHE_USER":"$APACHE_USER" wp-config.php
}

# Function to configure Apache
configure_apache() {
    print_header "MENGKONFIGURASI APACHE"
    
    # Create Apache virtual host configuration
    cat > /etc/apache2/sites-available/wordpress.conf << EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot $WP_DIR
    
    <Directory $WP_DIR>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF
    
    # Enable the site and disable default
    a2ensite wordpress.conf >> "$LOG_FILE" 2>&1
    a2dissite 000-default.conf >> "$LOG_FILE" 2>&1
    
    # Test Apache configuration
    if apache2ctl configtest >> "$LOG_FILE" 2>&1; then
        print_status "Konfigurasi Apache valid"
    else
        print_error "Konfigurasi Apache tidak valid"
        exit 1
    fi
    
    # Restart Apache
    systemctl restart apache2
    print_status "Apache berhasil dikonfigurasi dan direstart"
}

# Function to setup basic firewall
setup_firewall() {
    print_header "MENYIAPKAN FIREWALL DASAR"
    
    if command -v ufw &> /dev/null; then
        print_status "Mengkonfigurasi UFW..."
        ufw --force enable >> "$LOG_FILE" 2>&1
        ufw allow ssh >> "$LOG_FILE" 2>&1
        ufw allow 'Apache Full' >> "$LOG_FILE" 2>&1
        print_status "Firewall berhasil dikonfigurasi"
    else
        print_warning "UFW tidak terinstal, melewati konfigurasi firewall"
    fi
}

# Function to get IP addresses
get_ip_addresses() {
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me || echo "Tidak dapat mendeteksi")
}

# Function to display final information
display_final_info() {
    print_header "INSTALASI SELESAI"
    
    get_ip_addresses
    
    # Create info file
    INFO_FILE="/root/wordpress_info.txt"
    cat > "$INFO_FILE" << EOF
=== INFORMASI INSTALASI WORDPRESS ===

Tanggal Instalasi: $(date)

Database:
- Nama Database: $WP_DB_NAME
- Username Database: $WP_DB_USER
- Password Database: $WP_DB_PASS
- MySQL Root Password: $MYSQL_ROOT_PASS

Akses Website:
- IP Lokal: http://$LOCAL_IP
- IP Publik: http://$PUBLIC_IP

File Penting:
- WordPress Directory: $WP_DIR
- Apache Config: /etc/apache2/sites-available/wordpress.conf
- Log File: $LOG_FILE
- Info File: $INFO_FILE

Langkah Selanjutnya:
1. Buka browser dan akses salah satu URL di atas
2. Ikuti wizard instalasi WordPress
3. Buat akun admin WordPress
4. Mulai menggunakan WordPress!

Catatan Keamanan:
- Ganti password default setelah instalasi
- Update WordPress secara berkala
- Install plugin keamanan
- Backup database secara rutin
EOF
    
    print_status "Informasi instalasi tersimpan di: $INFO_FILE"
    echo
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    INSTALASI BERHASIL!                    ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Akses WordPress:                                         ║${NC}"
    echo -e "${GREEN}║  • IP Lokal (untuk testing): http://$LOCAL_IP${NC}"
    echo -e "${GREEN}║  • IP Publik (untuk produksi): http://$PUBLIC_IP${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║  Info lengkap tersimpan di: $INFO_FILE${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Terjadi error dalam instalasi. Melakukan cleanup..."
    # Add cleanup commands here if needed
    exit 1
}

# Main execution
main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Initialize log file
    touch "$LOG_FILE"
    
    print_header "WORDPRESS AUTO INSTALLER"
    print_status "Memulai instalasi WordPress..."
    print_status "Log file: $LOG_FILE"
    
    # Pre-installation checks
    check_root
    check_os
    
    # Main installation steps
    install_packages
    secure_mariadb
    setup_database
    install_wordpress
    configure_wordpress
    configure_apache
    setup_firewall
    
    # Final steps
    display_final_info
    
    print_status "Instalasi WordPress selesai!"
}

# Run main function
main "$@"
