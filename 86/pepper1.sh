#!/bin/bash

##Update & donwload package lists
sudo apt update && sudo apt upgrade -y
sudo apt install openssh-server -y
sudo apt install apache2 -y

## setting repo (1)
#change directory
cd /etc/apt 
# Repository link
teks_baru="
deb http://kartolo.sby.datautama.net.id/debian/ bullseye main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ bullseye-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ bullseye/updates main contrib non-free
"
# Menambahkan link repo ke file sources.txt
sudo echo "$teks_baru" >> sources.list

#setting repo (2)
# echo "$teks_baru" >> /etc/apt/sources.list

#update dan upgrade sekali lagi
sudo apt update && sudo apt upgrade

##setting ssh
#ganti dir
cd /etc/ssh
# Nama file yang akan diedit
file="sshd_config"
# Nomor baris yang akan diubah
nomor_baris_port=14
nomor_baris_permit_root=34
# Menghapus karakter '#' pada baris ke-14
sed -i "${nomor_baris_port}s/^#//" $file
# Meminta pengguna untuk memasukkan nomor Port baru
echo "Masukkan nomor Port baru (default port ssh 22) :"
read port_number
# Mengganti nomor Port dengan input pengguna pada baris ke-14
sed -i "${nomor_baris_port}s/22/$port_number/" $file
# Menambahkan konfigurasi "PermitRootLogin yes" pada baris ke-37
sed -i "${nomor_baris_permit_root}i PermitRootLogin yes" $file

##web service
service apache2 start
#service apache2 status

##ubah pw root
sudo passwd root

##reboot 
echo "sebelum mengisi pesan reboot, silahkan di cek apakah apache2 nya nyala atau ngak"
echo "Apakah Anda ingin me-reboot komputer? (y/n)"
read user_input

# Memeriksa input dari pengguna
if [ "$user_input" == "y" ]; then
    echo "rebooting, bop bop"
    sudo reboot
else
    echo "Tidak melakukan reboot."
fi
