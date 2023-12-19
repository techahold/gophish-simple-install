# gophish-simple-install
Simple Install Script for [gophish](https://github.com/gophish/gophish), built to work on any 64bit debian based system supporting systemd.<br>

You can use Hetzner to test this with a $20 credit using this referal code https://hetzner.cloud/?ref=p6iUr7jEXmoB

# How to Install the server

Ensure you have an A record setup already

Run the following commands:
```
wget https://raw.githubusercontent.com/techahold/gophish-simple-install/main/install.sh
chmod +x install.sh
./install.sh
```

Remember and save the password shown at the end of the script.

# Tips

If you want to restart the service use the following commands:
```
sudo systemctl restart gophish
```
