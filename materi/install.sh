echo "apakah kamu tau cara menggunakan aplikasi ini ? (y/n)"
read user_input
if [ "$user_input" == "n" ]; then
    echo "begini caranya, kamu hanya perlu memasukkan nama aplikasi yang mau kamu install dan berikan spasi
    contoh : apache2 mariadb-server openssh-server
    "
else
    echo "mantappp
    "
fi

echo "sebutkan aplikasi yang mau kamu install"
read jawaban
sudo apt install $jawaban -y