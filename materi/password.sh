echo "apakah kamu mau merubah password ?(y/n)"
read user_input
if ["$user_input" = "y"]; then
    echo "masukan username yang mau kamu ubah :"
    read username
    echo "masukan password baru :"
    read password
    echo "$username:$password" | sudo chpasswd
    echo "Password untuk $username telah diubah."
else
    echo "oke bye
    "
fi