#!/bin/bash

# Setting variabel
MYSQL_USER="root"
MYSQL_PASSWORD="password"

# Fungsi untuk melihat database
function show_databases(){
	echo "Menampilkan database $MYSQL_DATABASE..."
	mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;"
}
# Fungsi untuk meminta input nama database
function get_database_name() {
    read -p "Masukkan nama database: " MYSQL_DATABASE

    if [ -z "$MYSQL_DATABASE" ]; then
        echo "Nama database tidak boleh kosong!"
        get_database_name
    else
        return 0
    fi
}

# Fungsi untuk membuat database
function create_database() {
    get_database_name
    local mysql_database=$MYSQL_DATABASE

    echo "Membuat database $MYSQL_DATABASE..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE $MYSQL_DATABASE;"
}

# Fungsi untuk menghapus database
function delete_database() {
    get_database_name
    local mysql_database=$MYSQL_DATABASE

    echo "Menghapus database $MYSQL_DATABASE..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "DROP DATABASE $MYSQL_DATABASE;"
}

# Fungsi untuk mengubah database
function change_database() {
    get_database_name
    local mysql_database=$MYSQL_DATABASE

    echo "Mengubah database aktif ke $MYSQL_DATABASE..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "USE $MYSQL_DATABASE;"
}

# Fungsi untuk membuat tabel
function create_table() {
    local table_name=$1
    local sql_create_table=$2

    echo "Membuat tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "$sql_create_table"
}

# Fungsi untuk menghapus tabel
function delete_table() {
    local table_name=$1

    echo "Menghapus tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "DROP TABLE $table_name;"
}

# Fungsi untuk membaca data tabel
function read_table_data() {
    local table_name=$1

    echo "Membaca data tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT * FROM $table_name;"
}

# Menampilkan menu
echo "**Menu Skrip Database MariaDB**"
echo "1. Baca database"
echo "2. Buat database"
echo "3. Hapus database"
echo "4. Ubah database aktif"
echo "5. Buat tabel"
echo "6. Hapus tabel"
echo "7. Baca data tabel"
echo "0. Keluar"

read -p "Pilih opsi: " option

case $option in
    1)
        show_databases
        ;;
    2)
        create_database
        ;;
    3)
        delete_database
        ;;
    4)
        change_database
        ;;
    5)
        read -p "Nama tabel: " table_name
        read -p "Perintah SQL untuk membuat tabel: " sql_create_table
        create_table $table_name "$sql_create_table"
        ;;
    6)
        read -p "Nama tabel: " table_name
        delete_table $table_name
        ;;
    7)
        read -p "Nama tabel: " table_name
        read_table_data $table_name
        ;;

    0)
        echo "Keluar dari skrip..."
        exit 0
        ;;
    *)
        echo "Opsi tidak valid!"
        ;;
esac
