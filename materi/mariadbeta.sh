#!/bin/bash

# Setting variabel
MYSQL_USER="root"
MYSQL_PASSWORD="password"
MYSQL_DATABASE=""

# Fungsi untuk melihat database
function show_databases(){
    echo "Menampilkan database..."
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

# Fungsi untuk mengubah database aktif
function change_database() {
    get_database_name
    local mysql_database=$MYSQL_DATABASE

    echo "Mengubah database aktif ke $MYSQL_DATABASE..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -e "USE $MYSQL_DATABASE;"
}

# Fungsi untuk menghapus tabel
function show_tables() {
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "SHOW TABLES;"
}

# Fungsi untuk menghapus tabel
function describe_table() {
    echo "Masukkan nama tabel yang ingin dilihat:"
    read table_name

    echo "detail tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "DESCRIBE $table_name;"
}

# Fungsi untuk membuat tabel
function create_table() {
    echo "Masukkan nama tabel:"
    read table_name
    
    echo "Berapa kolom yang ingin dibuat?"
    read col_count
    
    local columns=""
    for ((i=1; i<=col_count; i++))
    do
        echo "Masukkan nama kolom ke-$i:"
        read col_name
        
        echo "Pilih tipe kolom (contoh: INT, VARCHAR(100), dll.):"
        read col_type
        
        echo "Pilih opsi untuk kolom ini (contoh: 1 2 untuk PRIMARY KEY dan NOT NULL):"
        echo "1. PRIMARY KEY"
        echo "2. NOT NULL"
        echo "3. AUTO_INCREMENT"
        echo "4. Tidak ada"
        read -a col_options
        
        col_def="$col_name $col_type"
        
        for option in "${col_options[@]}"
        do
            case $option in
                1) col_def+=" PRIMARY KEY" ;;
                2) col_def+=" NOT NULL" ;;
                3) col_def+=" AUTO_INCREMENT" ;;
                4) ;;
                *) echo "Opsi tidak valid!"; i=$((i-1)); continue 2 ;;
            esac
        done
        
        if [ $i -ne $col_count ]; then
            columns+="$col_def, "
        else
            columns+="$col_def"
        fi
    done
    
    local sql_create_table="CREATE TABLE $table_name ($columns);"
    
    echo "Membuat tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "$sql_create_table"
}

# Fungsi untuk menghapus tabel
function delete_table() {
    echo "Masukkan nama tabel yang ingin dihapus:"
    read table_name

    echo "Menghapus tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "DROP TABLE $table_name;"
}

# Fungsi untuk membaca data tabel
function read_table_data() {
    echo "Masukkan nama tabel yang ingin dibaca datanya:"
    read table_name

    echo "Membaca data tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "SELECT * FROM $table_name;"
}

# Fungsi untuk memasukkan data ke tabel
function insert_data() {
    echo "Masukkan nama tabel untuk insert data:"
    read table_name
    
    local columns=""
    local values=""
    
    while true; do
        echo "Masukkan nama kolom (atau ketik 'selesai' untuk mengakhiri):"
        read col_name
        if [ "$col_name" == "selesai" ]; then
            break
        fi
        
        echo "Masukkan nilai untuk kolom $col_name:"
        read col_value
        
        if [ -z "$columns" ]; then
            columns="$col_name"
            values="'$col_value'"
        else
            columns+=", $col_name"
            values+=", '$col_value'"
        fi
    done
    
    local sql_insert="INSERT INTO $table_name ($columns) VALUES ($values);"
    
    echo "Memasukkan data ke tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "$sql_insert"
}

# Fungsi untuk mengupdate data tabel
function update_data() {
    echo "Masukkan nama tabel untuk update data:"
    read table_name
    
    echo "Masukkan kondisi (contoh: id=1):"
    read condition
    
    echo "Masukkan nama kolom yang ingin diupdate:"
    read col_name
    
    echo "Masukkan nilai baru untuk kolom $col_name:"
    read col_value
    
    local sql_update="UPDATE $table_name SET $col_name='$col_value' WHERE $condition;"
    
    echo "Mengupdate data tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "$sql_update"
}

# Fungsi untuk menghapus data dari tabel
function delete_data() {
    echo "Masukkan nama tabel untuk delete data:"
    read table_name
    
    echo "Masukkan kondisi (contoh: id=1):"
    read condition
    
    local sql_delete="DELETE FROM $table_name WHERE $condition;"
    
    echo "Menghapus data dari tabel $table_name..."
    mysql -u $MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE -e "$sql_delete"
}

# Fungsi untuk menampilkan menu database
function show_database_menu() {
    echo "**Menu Database MariaDB**"
    echo "1. Baca database"
    echo "2. Buat database"
    echo "3. Hapus database"
    echo "4. Ubah database aktif"
    echo "0. Keluar"
}

# Fungsi untuk menampilkan menu tabel
function show_table_menu() {
    echo "**Menu Tabel MariaDB**"
    echo "1. lihat tabel"
    echo "2. tentang tabel"
    echo "3. Buat tabel"
    echo "4. Hapus tabel"
    echo "5. Baca data tabel"
    echo "6. Insert data ke tabel"
    echo "7. Update data tabel"
    echo "8. Delete data dari tabel"
    echo "0. Kembali ke menu database"
}

# Fungsi untuk menampilkan menu data
function show_data_menu() {
    echo "**Menu Data Tabel MariaDB**"
    echo "1. Baca data tabel"
    echo "2. Insert data ke tabel"
    echo "3. Update data tabel"
    echo "4. Delete data dari tabel"
    echo "0. Kembali ke menu database"
}

# Menampilkan menu database
clear
show_database_menu

while true; do
    read -p "Pilih opsi: " option

    case $option in
        1)
            clear
            show_databases
            echo ""
            show_database_menu
            ;;
        2)
            clear
            create_database
            echo ""
            show_database_menu
            ;;
        3)
            clear
            show_databases
            delete_database
            echo ""
            show_database_menu
            ;;
        4)
            clear
            show_databases
            change_database
            echo ""
            while true; do
                show_table_menu
                read -p "Pilih opsi tabel: " table_data_option

                case $table_data_option in
                    1)
                        clear
                        show_tables
                        echo ""
                        ;;
                    2)
                        clear
                        show_tables
                        describe_table
                        echo ""
                        ;;

                    3)
                        clear
                        create_table
                        echo ""
                        ;;
                    4)
                        clear
                        show_tables
                        delete_table
                        echo ""
                        ;;
                    5)
                        clear
                        read_table_data
                        echo ""
                        ;;
                    6)
                        clear
                        insert_data
                        echo ""
                        ;;
                    7)
                        clear
                        update_data
                        echo ""
                        ;;
                    8)
                        clear
                        delete_data
                        echo ""
                        ;;
                    0)
                        clear
                        show_database_menu
                        break
                        ;;

                    *)
                        clear
                        echo "Opsi tidak valid!"
                        ;;
                esac
            done
            ;;
        0)
            echo "Keluar dari skrip..."
            break
            ;;
        *)
            clear
            echo "Opsi tidak valid!"
            show_database_menu
            ;;
    esac
done

exit 0
