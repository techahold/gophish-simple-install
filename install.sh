#!/bin/bash

# Get username
usern=$(whoami)
admintoken=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c16)

ARCH=$(uname -m)

# Setting up firewall
sudo ufw allow 22/tcp
sudo ufw enable

# Make folder /opt/gophish/
if [ ! -d "/opt/gophish" ]; then
    echo "Creating /opt/gophish"
    sudo mkdir -p /opt/gophish/
fi

sudo chown "${usern}" -R /opt/gophish
cd /opt/gophish/

sudo apt install unzip

# Download latest version of GoPhish
GPLATEST=$(curl https://api.github.com/repos/gophish/gophish/releases/latest -s | grep "tag_name"| awk '{print substr($2, 2, length($2)-3) }')

echo "Installing GoPhish Server"
wget https://github.com/gophish/gophish/releases/download/$GPLATEST/gophish-$GPLATEST-linux-64bit.zip
unzip gophish-$GPLATEST-linux-64bit.zip
mv -rf gophish-$GPLATEST-linux-64bit/* /opt/gophish/

sudo chmod +x /opt/gophish/

# Make folder /var/log/gophish/
if [ ! -d "/var/log/gophish/" ]; then
    echo "Creating /var/log/rustdesk-server"
    sudo mkdir -p /var/log/gophish/
fi
sudo chown "${usern}" -R /var/log/gophish/

# Setup systemd to launch hbbs
gophishservice="$(cat << EOF
[Unit]
Description=Gophish is an open-source phishing toolkit
Documentation=https://getgophish.com/documentation/
[Service]
Type=simple
LimitNOFILE=1000000
ExecStart=/opt/gophish/gophish
WorkingDirectory=/opt/gophish
User=${usern}
Group=${usern}
Restart=always
StandardOutput=append:/var/log/gophish/gophish.log
StandardError=append:/var/log/gophish/gophish.error
# Restart service after 10 seconds if node service crashes
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
)"
echo "${gophishservice}" | sudo tee /etc/systemd/system/gophish.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable gophish.service

echo -ne "Enter your preferred domain/DNS address : "
read gpdomain
# Check gpdomain is valid domain
if ! [[ $gpdomain =~ ^[a-zA-Z0-9]+([a-zA-Z0-9.-]*[a-zA-Z0-9]+)?$ ]]; then
    echo -e "Invalid domain/DNS address"
    exit 1
fi

echo "Installing nginx"
sudo apt -y install certbot jq

sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3333/tcp

sudo ufw enable 
sudo ufw reload

certbot certonly --non-interactive --agree-tos --email example@gmail.com --standalone --preferred-challenges http -d $gpdomain

echo "Configuring New SSL cert for $gpdomain..."

echo "Configuring Gophish"

cat "/opt/gophish/config.json" |     
jq " .admin_server.listen_url |= \"0.0.0.0:3333\" " |
jq " .admin_server.use_tls |= true " |
jq " .admin_server.cert_path |= \"/etc/letsencrypt/live/$gpdomain/fullchain.pem\" " |
jq " .admin_server.key_path |= \"/etc/letsencrypt/live/$gpdomain/privkey.pem\" " |
jq " .phish_server.listen_url |= \"0.0.0.0:443\" " |
jq " .phish_server.use_tls |= true " |
jq " .phish_server.cert_path |= \"/etc/letsencrypt/live/$gpdomain/fullchain.pem\" " |
jq " .phish_server.key_path |= \"/etc/letsencrypt/live/$gpdomain/privkey.pem\" " > /opt/gophish/config2.json
mv /opt/gophish/config.json /opt/gophish/config.bak.json
mv /opt/gophish/config2.json /opt/gophish/config.json
mkdir -p /opt/gophish/static/endpoint
printf "User-agent: *\nDisallow: /" > /opt/gophish/static/endpoint/robots.txt

sudo systemctl start gophish.service


grep 'Please login with the username admin and the password' /var/log/gophish/gophish.error | awk -F 'msg=' '{print $2}'
