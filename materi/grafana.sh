echo "ketik `install` untuk menginstsall, ketik `delete` untuk uninstall atau menghapusnya"
read user_input
if ["$user_input" = "install"]; then
    sudo apt-get install -y apt-transport-https software-properties-common wget
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
    sudo apt-get update
    sudo apt-get install grafana
elif ["$user_input" = "delete"]; then
    sudo systemctl stop grafana-server
    sudo service grafana-server stop
    sudo apt-get remove grafana
    sudo rm -i /etc/apt/sources.list.d/grafana.list
else
    echo "input tidak valid"
fi
