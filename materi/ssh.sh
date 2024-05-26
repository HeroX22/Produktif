echo "apakah kamu sudah mendownload openssh-server ?(y/n)"
read user_input
if [ "$user_input" == "n" ]; then
    sudo apt install openssh-server
else
    echo "bagus!
    "
fi

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
#restart service
service ssh restart