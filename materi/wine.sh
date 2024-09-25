#!/bin/bash

arsitektur=$(dpkg --print-architecture)

if [ "$arsitektur" = "amd64" ] || [ "$arsitektur" = "arm64" ]; then
    echo "Sistem 64-bit terdeteksi. Menjalankan perintah untuk menambahkan arsitektur i386."
    sudo dpkg --add-architecture i386
else
    echo "Sistem bukan 64-bit. Tidak ada tindakan yang diambil."
fi

sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

# Mendapatkan VERSION_ID dari os-release
version_id=$(grep "VERSION_ID" /etc/os-release | cut -d '"' -f 2)

# Memeriksa apakah VERSION_ID dimulai dengan 24 atau 22
if [[ $version_id == 24.04 ]] || [[ $version_id == 22.* ]]; then
    echo "Versi sistem terdeteksi: $version_id. Menjalankan perintah wget."
    sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources
elif [[ $version_id == 22.04 ]] || [[ $version_id == 21.* ]]; then
    echo "Versi sistem terdeteksi: $version_id. Menjalankan perintah wget."
    sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
elif [[ $version_id == 20.04 ]] || [[ $version_id == 20.* ]]; then
    echo "Versi sistem terdeteksi: $version_id. Menjalankan perintah wget."
    sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/focal/winehq-focal.sources
else
    echo "Versi sistem tidak cocok. Tidak ada tindakan yang diambil."
fi

sudo apt update
sudo apt install --install-recommends winehq-stable

echo "cara pakenya tinggal tulis "wine <nama file yang mau di install>"
