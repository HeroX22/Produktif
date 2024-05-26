# Repository link
link_repo="
deb http://kartolo.sby.datautama.net.id/debian/ bullseye main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ bullseye-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ bullseye/updates main contrib non-free
"

##reboot 
echo "mau pake metode 1 atau 2 ? (1/2)"
read user_input

# Memeriksa input dari pengguna
if [ "$user_input" == "1" ]; then
    #change directory
    cd /etc/apt 
    # Menambahkan link repo ke file sources.txt
    sudo echo "$link_repo" >> sources.list
else
    #setting repo (2)
    echo "$link_repo" >> /etc/apt/sources.list
fi

#update dan upgrade
sudo apt update && sudo apt upgrade