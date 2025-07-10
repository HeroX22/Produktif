#!/bin/bash

# WordPress Auto Installer Script
# Improved version with better error handling and security
# Compatible with Ubuntu/Debian systems
# Modified to allow custom password input and database restore

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
MYSQL_ROOT_PASS=""
WP_DIR="/var/www/html"
APACHE_USER="www-data"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/wordpress-install.log"
DB_RESTORE_PATH=""
RESTORE_MODE=false
WP_DOMAIN=""

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

# Function to validate database backup file
validate_backup_file() {
    local backup_path="$1"
    
    if [[ ! -f "$backup_path" ]]; then
        print_error "File backup tidak ditemukan: $backup_path"
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$backup_path" ]]; then
        print_error "File backup tidak dapat dibaca: $backup_path"
        return 1
    fi
    
    # Check file extension
    local file_ext="${backup_path##*.}"
    if [[ "$file_ext" != "sql" && "$file_ext" != "gz" ]]; then
        print_warning "File backup tidak memiliki ekstensi .sql atau .gz"
        echo -e "${YELLOW}Apakah Anda yakin ini adalah file backup database? (y/n)${NC}"
        read -r confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            return 1
        fi
    fi
    
    # Check if it's a compressed file
    if [[ "$file_ext" == "gz" ]]; then
        if ! gzip -t "$backup_path" 2>/dev/null; then
            print_error "File backup .gz corrupt atau tidak valid"
            return 1
        fi
    else
        # Basic check for SQL file
        if ! head -n 10 "$backup_path" | grep -q -i "create\|insert\|database\|table" 2>/dev/null; then
            print_warning "File backup tidak terlihat seperti file SQL database"
            echo -e "${YELLOW}Apakah Anda yakin ini adalah file backup database? (y/n)${NC}"
            read -r confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                return 1
            fi
        fi
    fi
    
    return 0
}

# Function to get user input for passwords and restore option
get_user_input() {
    print_header "KONFIGURASI INSTALASI"
    
    # Ask about database restore
    echo -e "${BLUE}Apakah Anda ingin restore database dari backup?${NC}"
    echo -e "${YELLOW}Tips: Kosongkan jika ingin instalasi baru (default)${NC}"
    read -p "Masukkan path file backup database (tekan Enter untuk instalasi baru): " DB_RESTORE_PATH
    
    if [[ -n "$DB_RESTORE_PATH" ]]; then
        # Expand tilde to home directory
        DB_RESTORE_PATH="${DB_RESTORE_PATH/#\~/$HOME}"
        
        # Validate backup file
        if validate_backup_file "$DB_RESTORE_PATH"; then
            RESTORE_MODE=true
            print_status "Mode: Restore database dari $DB_RESTORE_PATH"
        else
            print_error "Validasi file backup gagal"
            exit 1
        fi
    else
        print_status "Mode: Instalasi baru (tanpa restore)"
    fi
    
    print_header "KONFIGURASI PASSWORD"
    
    # Get MySQL root password
    echo -e "${BLUE}Password untuk MySQL root:${NC}"
    echo -e "${YELLOW}Tips: Kosongkan jika ingin tanpa password (tidak disarankan untuk production)${NC}"
    read -p "Masukkan password MySQL root (tekan Enter untuk kosong): " MYSQL_ROOT_PASS
    
    if [[ -z "$MYSQL_ROOT_PASS" ]]; then
        print_warning "MySQL root akan tanpa password"
    else
        print_status "MySQL root password telah diset"
    fi
    
    # Get WordPress database password
    echo -e "${BLUE}Password untuk database WordPress:${NC}"
    echo -e "${YELLOW}Tips: Kosongkan jika ingin tanpa password (tidak disarankan untuk production)${NC}"
    read -p "Masukkan password database WordPress (tekan Enter untuk kosong): " WP_DB_PASS
    
    if [[ -z "$WP_DB_PASS" ]]; then
        print_warning "Database WordPress akan tanpa password"
    else
        print_status "Database WordPress password telah diset"
    fi
    
    # Optional: Set custom database name and username
    echo -e "${BLUE}Konfigurasi database (opsional):${NC}"
    read -p "Nama database WordPress [default: wordpress]: " INPUT_DB_NAME
    if [[ -n "$INPUT_DB_NAME" ]]; then
        WP_DB_NAME="$INPUT_DB_NAME"
    fi
    
    read -p "Username database WordPress [default: wordpress]: " INPUT_DB_USER
    if [[ -n "$INPUT_DB_USER" ]]; then
        WP_DB_USER="$INPUT_DB_USER"
    fi
    
    print_status "Konfigurasi: Database=$WP_DB_NAME, User=$WP_DB_USER"
    
    # Domain configuration
    print_header "KONFIGURASI DOMAIN"
    echo -e "${BLUE}Masukkan domain untuk WordPress (opsional):${NC}"
    echo -e "${YELLOW}Kosongkan jika ingin menggunakan IP server${NC}"
    read -p "Domain (misal: example.com): " WP_DOMAIN
    if [[ -n "$WP_DOMAIN" ]]; then
        print_status "Domain akan digunakan: $WP_DOMAIN"
    else
        print_status "Tidak ada domain, instalasi hanya via IP"
    fi

    if [[ "$RESTORE_MODE" == true ]]; then
        print_status "File backup: $DB_RESTORE_PATH"
    fi
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
        openssl \
        gzip >> "$LOG_FILE" 2>&1
    
    print_status "Mengaktifkan dan memulai layanan..."
    systemctl enable apache2 mariadb >> "$LOG_FILE" 2>&1
    systemctl start apache2 mariadb >> "$LOG_FILE" 2>&1
    
    # Enable required Apache modules
    a2enmod rewrite >> "$LOG_FILE" 2>&1

    # Hapus baris berikut:
    # a2enmod ssl >> "$LOG_FILE" 2>&1

    # Tambahkan instalasi certbot dan plugin apache
    print_status "Menginstal Certbot untuk SSL Let's Encrypt..."
    apt-get install -y certbot python3-certbot-apache >> "$LOG_FILE" 2>&1
}

# Function to secure MariaDB installation
secure_mariadb() {
    print_header "MENGKONFIGURASI MARIADB"
    
    # Check MariaDB version
    MARIADB_VERSION=$(mysql --version | grep -oP 'Distrib \K[0-9]+\.[0-9]+')
    print_status "MariaDB version detected: $MARIADB_VERSION"
    
    if [[ -n "$MYSQL_ROOT_PASS" ]]; then
        print_status "Mengset password root MySQL..."
        
        # Set root password using modern syntax
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
            print_status "MariaDB berhasil dikonfigurasi dengan password"
        else
            print_warning "Gagal mengset password dengan ALTER USER, mencoba metode lama..."
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
    else
        print_status "Mengkonfigurasi MariaDB tanpa password root..."
        
        # Basic security without password
        mysql -u root << EOF
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
        
        print_status "MariaDB dikonfigurasi tanpa password root"
    fi
}

# Function to restore database from backup
restore_database() {
    print_header "RESTORE DATABASE DARI BACKUP"
    
    local backup_file="$1"
    
    print_status "Memulai restore database dari: $backup_file"
    
    # Check if file is compressed
    if [[ "$backup_file" == *.gz ]]; then
        print_status "File backup terkompresi, melakukan decompress..."
        
        if [[ -n "$MYSQL_ROOT_PASS" ]]; then
            if gunzip -c "$backup_file" | mysql -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASS" "$WP_DB_NAME"; then
                print_status "Database berhasil di-restore dari file terkompresi"
            else
                print_error "Gagal restore database dari file terkompresi"
                return 1
            fi
        else
            if gunzip -c "$backup_file" | mysql -u "$MYSQL_USER" "$WP_DB_NAME"; then
                print_status "Database berhasil di-restore dari file terkompresi"
            else
                print_error "Gagal restore database dari file terkompresi"
                return 1
            fi
        fi
    else
        print_status "File backup tidak terkompresi, melakukan restore langsung..."
        
        if [[ -n "$MYSQL_ROOT_PASS" ]]; then
            if mysql -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASS" "$WP_DB_NAME" < "$backup_file"; then
                print_status "Database berhasil di-restore"
            else
                print_error "Gagal restore database"
                return 1
            fi
        else
            if mysql -u "$MYSQL_USER" "$WP_DB_NAME" < "$backup_file"; then
                print_status "Database berhasil di-restore"
            else
                print_error "Gagal restore database"
                return 1
            fi
        fi
    fi
    
    print_status "Restore database selesai"
    return 0
}

# Function to setup WordPress database
setup_database() {
    print_header "MENYIAPKAN DATABASE WORDPRESS"
    
    # Create database and user
    if [[ -n "$MYSQL_ROOT_PASS" ]]; then
        # If root password is set, use it
        if [[ -n "$WP_DB_PASS" ]]; then
            # With WordPress database password
            mysql -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASS" << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        else
            # Without WordPress database password
            mysql -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASS" << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        fi
    else
        # If no root password
        if [[ -n "$WP_DB_PASS" ]]; then
            # With WordPress database password
            mysql -u "$MYSQL_USER" << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        else
            # Without WordPress database password
            mysql -u "$MYSQL_USER" << EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        fi
    fi
    
    if [[ $? -eq 0 ]]; then
        print_status "Database dan user WordPress berhasil dibuat"
    else
        print_error "Gagal membuat database WordPress"
        exit 1
    fi
    
    # If restore mode is enabled, restore the database
    if [[ "$RESTORE_MODE" == true ]]; then
        if restore_database "$DB_RESTORE_PATH"; then
            print_status "Database berhasil di-restore dari backup"
        else
            print_error "Gagal restore database dari backup"
            exit 1
        fi
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
    
    # Generate WordPress security keys using PHP
    print_status "Menghasilkan kunci keamanan WordPress..."
    
    # Create temporary PHP script to generate salt
    cat > /tmp/generate_salt.php << 'EOF'
<?php
function generateSalt($length = 64) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{};:,.<>?';
    $salt = '';
    for ($i = 0; $i < $length; $i++) {
        $salt .= $chars[random_int(0, strlen($chars) - 1)];
    }
    return $salt;
}

$keys = array(
    'AUTH_KEY',
    'SECURE_AUTH_KEY',
    'LOGGED_IN_KEY',
    'NONCE_KEY',
    'AUTH_SALT',
    'SECURE_AUTH_SALT',
    'LOGGED_IN_SALT',
    'NONCE_SALT'
);

foreach ($keys as $key) {
    echo "define('{$key}', '" . generateSalt() . "');\n";
}
?>
EOF
    
    # Generate salt and save to temporary file
    php /tmp/generate_salt.php > /tmp/wp_salt.txt
    
    # Configure database settings
    sed -i "s/database_name_here/$WP_DB_NAME/g" wp-config.php
    sed -i "s/username_here/$WP_DB_USER/g" wp-config.php
    sed -i "s/password_here/$WP_DB_PASS/g" wp-config.php
    
    # Remove the default salt lines and add our generated ones
    sed -i '/put your unique phrase here/d' wp-config.php
    
    # Find the line with AUTH_KEY and replace the entire salt section
    sed -i '/AUTH_KEY/,/NONCE_SALT/c\
/* WordPress Security Keys - Generated by installer */
' wp-config.php
    
    # Add the generated salt
    sed -i '/WordPress Security Keys - Generated by installer/r /tmp/wp_salt.txt' wp-config.php
    
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
    
    # Cleanup temporary files
    rm -f /tmp/generate_salt.php /tmp/wp_salt.txt
    
    # Set proper permissions for wp-config.php
    chmod 600 wp-config.php
    chown "$APACHE_USER":"$APACHE_USER" wp-config.php
    
    print_status "WordPress berhasil dikonfigurasi"
}

# Function to configure Apache
configure_apache() {
    print_header "MENGKONFIGURASI APACHE"
    
    # Pilih ServerName dan ServerAlias jika domain diisi
    if [[ -n "$WP_DOMAIN" ]]; then
        SERVER_NAME="$WP_DOMAIN"
        SERVER_ALIAS="ServerAlias www.$WP_DOMAIN"
    else
        SERVER_NAME="localhost"
        SERVER_ALIAS=""
    fi

    # Create Apache virtual host configuration
    cat > /etc/apache2/sites-available/wordpress.conf << EOF
<VirtualHost *:80>
    ServerName $SERVER_NAME
    $SERVER_ALIAS
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
Mode Instalasi: $(if [[ "$RESTORE_MODE" == true ]]; then echo "Restore dari backup"; else echo "Instalasi baru"; fi)
$(if [[ "$RESTORE_MODE" == true ]]; then echo "File Backup: $DB_RESTORE_PATH"; fi)

Domain: $(if [[ -n "$WP_DOMAIN" ]]; then echo "$WP_DOMAIN"; else echo "TIDAK ADA (hanya via IP)"; fi)

Database:
- Nama Database: $WP_DB_NAME
- Username Database: $WP_DB_USER
- Password Database: $(if [[ -n "$WP_DB_PASS" ]]; then echo "$WP_DB_PASS"; else echo "TANPA PASSWORD"; fi)
- MySQL Root Password: $(if [[ -n "$MYSQL_ROOT_PASS" ]]; then echo "$MYSQL_ROOT_PASS"; else echo "TANPA PASSWORD"; fi)

Akses Website:
$(if [[ -n "$WP_DOMAIN" ]]; then echo "- Domain: http://$WP_DOMAIN"; fi)
- IP Lokal: http://$LOCAL_IP
- IP Publik: http://$PUBLIC_IP

File Penting:
- WordPress Directory: $WP_DIR
- Apache Config: /etc/apache2/sites-available/wordpress.conf
- Log File: $LOG_FILE
- Info File: $INFO_FILE

Langkah Selanjutnya:
$(if [[ "$RESTORE_MODE" == true ]]; then
echo "1. Buka browser dan akses salah satu URL di atas"
echo "2. Website seharusnya sudah ter-restore dari backup"
echo "3. Login dengan kredensial dari backup database"
echo "4. Verifikasi semua konten dan konfigurasi"
else
echo "1. Buka browser dan akses salah satu URL di atas"
echo "2. Ikuti wizard instalasi WordPress"
echo "3. Buat akun admin WordPress"
echo "4. Mulai menggunakan WordPress!"
fi)

Catatan Keamanan:
- Ganti password default setelah instalasi
- Update WordPress secara berkala
- Install plugin keamanan
- Backup database secara rutin
$(if [[ -z "$MYSQL_ROOT_PASS" || -z "$WP_DB_PASS" ]]; then echo "- SET PASSWORD untuk MySQL dan database WordPress (saat ini tanpa password)"; fi)
$(if [[ "$RESTORE_MODE" == true ]]; then echo "- Verifikasi konfigurasi keamanan setelah restore"; fi)
EOF

    print_status "Informasi instalasi tersimpan di: $INFO_FILE"
    echo
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    INSTALASI BERHASIL!                    ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  Akses WordPress:                                         ║${NC}"
    if [[ -n "$WP_DOMAIN" ]]; then
        echo -e "${GREEN}║  • Domain: http://$WP_DOMAIN${NC}"
    fi
    echo -e "${GREEN}║  • IP Lokal: http://$LOCAL_IP${NC}"
    echo -e "${GREEN}║  • IP Publik: http://$PUBLIC_IP${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    if [[ "$RESTORE_MODE" == true ]]; then
        echo -e "${GREEN}║  Database berhasil di-restore dari backup                ║${NC}"
        echo -e "${GREEN}║                                                           ║${NC}"
    fi
    echo -e "${GREEN}║  Info lengkap tersimpan di: $INFO_FILE${NC}"

    if [[ -z "$MYSQL_ROOT_PASS" || -z "$WP_DB_PASS" ]]; then
        echo -e "${YELLOW}║                                                           ║${NC}"
        echo -e "${YELLOW}║  PERINGATAN: Ada password yang kosong!                   ║${NC}"
        echo -e "${YELLOW}║  Disarankan untuk mengset password setelah instalasi     ║${NC}"
    fi

    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Terjadi error dalam instalasi. Melakukan cleanup..."
    # Cleanup temporary files
    rm -f /tmp/generate_salt.php /tmp/wp_salt.txt
    exit 1
}

# Uninstaller function
uninstall_wordpress_stack() {
    print_header "UNINSTALL WORDPRESS & STACK"

    # Stop Apache and MariaDB
    print_status "Menghentikan layanan Apache dan MariaDB..."
    systemctl stop apache2 mariadb || true

    # Remove WordPress files
    if [[ -d "$WP_DIR" ]]; then
        print_status "Menghapus direktori WordPress: $WP_DIR"
        rm -rf "$WP_DIR"/*
    fi

    # Remove Apache config
    if [[ -f /etc/apache2/sites-available/wordpress.conf ]]; then
        print_status "Menghapus konfigurasi Apache WordPress"
        a2dissite wordpress.conf || true
        rm -f /etc/apache2/sites-available/wordpress.conf
    fi

    # Reload Apache
    systemctl reload apache2 || true

    # Remove database and user
    print_status "Menghapus database dan user WordPress"
    if [[ -n "$MYSQL_ROOT_PASS" ]]; then
        mysql -u "$MYSQL_USER" -p"$MYSQL_ROOT_PASS" <<EOF
DROP DATABASE IF EXISTS $WP_DB_NAME;
DROP USER IF EXISTS '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    else
        mysql -u "$MYSQL_USER" <<EOF
DROP DATABASE IF EXISTS $WP_DB_NAME;
DROP USER IF EXISTS '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    fi

    # Remove Certbot certificates if domain is set
    if [[ -n "$WP_DOMAIN" ]]; then
        print_status "Menghapus sertifikat SSL Let's Encrypt untuk $WP_DOMAIN"
        certbot delete --cert-name "$WP_DOMAIN" --non-interactive || true
    fi

    # Remove log and info files
    print_status "Menghapus file log dan info"
    rm -f "$LOG_FILE" /root/wordpress_info.txt

    print_status "Menghapus paket terkait (apache2, mariadb-server, php, certbot)..."
    apt-get remove --purge -y apache2 mariadb-server php* certbot python3-certbot-apache unzip wget curl openssl gzip || true
    apt-get autoremove -y || true

    print_status "Uninstall selesai. WordPress dan stack telah dihapus."
    exit 0
}

# Main execution
main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Initialize log file
    touch "$LOG_FILE"
    
    print_header "WORDPRESS AUTO INSTALLER"
    print_status "WordPress Auto Installer dengan Custom Password dan Database Restore"
    print_status "Log file: $LOG_FILE"
    
    # Pre-installation checks
    check_root
    check_os
    
    # Get user input for passwords and restore option
    get_user_input
    
    # Main installation steps
    install_packages
    secure_mariadb
    setup_database
    install_wordpress
    configure_wordpress
    configure_apache
    setup_firewall

    # Tambahkan pemanggilan setup_ssl_certbot setelah apache dan firewall
    setup_ssl_certbot

    # Final steps
    display_final_info
    
    print_status "Instalasi WordPress selesai!"
}

# Run main function or uninstaller
if [[ "$1" == "uninstall" ]]; then
    uninstall_wordpress_stack
else
    main "$@"
fi
