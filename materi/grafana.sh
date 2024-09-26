echo 'ketik "install" untuk menginstal, ketik "delete" untuk uninstall atau menghapusnya'
read user_input

if [ "$user_input" = "install" ]; then
    sudo apt-get install -y apt-transport-https software-properties-common wget
    sudo mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
    sudo apt-get update
    sudo apt-get install grafana -y

    echo "configurasi bisa menggunakan systemd/systemctl(1) atau init.d/services(2), silahkan pilih nomernya (direkomendasikan untuk menggunakan 2)"
    read user_input_config
    
    if [ "$user_input_config" = "1" ]; then
        sudo systemctl daemon-reload
        sudo systemctl start grafana-server
        sudo systemctl enable grafana-server.service
        sudo systemctl enable grafana-server
        sudo mkdir -p /etc/systemd/system/grafana-server.service.d/
        sudo touch /etc/systemd/system/grafana-server.service.d/override.conf
        
        sudo tee /etc/systemd/system/grafana-server.service.d/override.conf > /dev/null <<EOL
[Service]
# Give the CAP_NET_BIND_SERVICE capability
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

# A private user cannot have process capabilities on the host's user
# namespace and thus CAP_NET_BIND_SERVICE has no effect.
PrivateUsers=false
EOL

        echo 'installasi selesai, buka dengan cara IP:3000'
        
    elif [ "$user_input_config" = "2" ]; then
        sudo service grafana-server start
        sudo update-rc.d grafana-server defaults
        sudo service grafana-server restart
        # The next line is likely unnecessary since you already started the service.
        # ./bin/grafana server
        echo 'installasi selesai, buka dengan cara IP:3000'
    else
        echo "input tidak valid, silahkan konfigurasi sendiri"
        exit 1
    fi

elif [ "$user_input" = "delete" ]; then
    sudo systemctl stop grafana-server
    sudo service grafana-server stop
    sudo apt-get remove grafana -y
    sudo rm -i /etc/apt/sources.list.d/grafana.list
else
    echo "input tidak valid"
    exit 1
fi
