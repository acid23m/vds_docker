#!/usr/bin/env bash


# --------------------------------------------------------
# THIS SCRIPT AUTOMATICALLY CONFIGURES DOCKER ORIENTED VDS
# --------------------------------------------------------


# variables
# --------------------------------------
VDS_USER_DEFAULT="wuser"
ID_RSA_PUB="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFdthYXKQHWMpoKjKNkKx0Ks04BYynW+HXOLihd/cY7OCFiKisRwDM5yc4nfrnDOjBsElf5doC+syrsG69//CjBFzsyVL5rW3IYFefQDCol2rhlBWsKSlWqv1OlJq71cImG+AM2H7TbwToxEJQA7Yj65tZ7D3SLgdQ8STwx0qfo+LkUoepXOOyD1AK9gIzj3mFt6ehwY+2kGpbZnSlw7HdjHBI5WpAfNKWJghd49Pxmsf1xVqZErBGKsT2NCr7M2y9JRPn6aiP3OkpLq/VrqKaHU38aka7dT7ZRjQfGz/nlwuKS3DXYj2L1j6Jm93vcCfnuuo6DHnDZhQEiBgQ7L4f acid23m@Xenomorph"
# --------------------------------------



if [[ $(id -u) != 0 ]]; then
    echo "Run script with superuser privileges!"
    exit 1
fi


read -p "Is VDS remote? [y/n] " VDS_IS_REMOTE
if [[ "$VDS_IS_REMOTE" = "y" ]]; then
    HOST_IP=`curl -s https://api.ipify.org`
else
    read -p "Enter ip address of the local server: ($(hostname -I)) " HOST_IP
fi



# update system
echo -e "\n *** Update system ***"
echo -e "-------------------------------------------\n"

apt update
apt dist-upgrade -y
apt upgrade -y
apt install -ym git openssl software-properties-common wget curl cron mc
apt autoremove -y
apt autoclean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



# create main user
echo -e "\n *** Create main User ***"
echo -e "-------------------------------------------\n"

read -p "Enter VDS user name. [${VDS_USER_DEFAULT}]: " VDS_USER
if [[ "$VDS_USER" = "" ]]; then
    VDS_USER=$VDS_USER_DEFAULT
fi
adduser ${VDS_USER}
usermod -a -G sudo,www-data ${VDS_USER}



# ssh
echo -e "\n *** Configure SSH ***"
echo -e "-------------------------------------------\n"

apt install -ym openssh-client openssh-server
if [[ -f "/etc/ssh/sshd_config" ]]; then
    cp -av /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -e "s/PermitRootLogin prohibit-password/PermitRootLogin no/g; s/PermitRootLogin yes/PermitRootLogin no/g" /etc/ssh/sshd_config.bak > /etc/ssh/sshd_config
fi

mkdir -v -m 700 "/home/$VDS_USER/.ssh"
touch "/home/$VDS_USER/.ssh/authorized_keys"
chmod 600 "/home/$VDS_USER/.ssh/authorized_keys"
chown -R "$VDS_USER:$VDS_USER /home/$VDS_USER/.ssh"
echo -e "\n$ID_RSA_PUB" > /home/$VDS_USER/.ssh/authorized_keys
service ssh restart



# fail2ban
echo -e "\n *** Configure Fail2ban ***"
echo -e "-------------------------------------------\n"

apt-get install -ym fail2ban
if [[ -f "/etc/fail2ban/jail.d/defaults-debian.conf" ]]; then
    echo -e "\n[sshd-ddos]\nenabled = true\n" >> /etc/fail2ban/jail.d/defaults-debian.conf
fi
systemctl enable fail2ban



# firewall
echo -e "\n *** Configure Firewall ***"
echo -e "-------------------------------------------\n"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
ufw status



# docker
echo -e "\n *** Install Docker ***"
echo -e "-------------------------------------------\n"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
#add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
touch /etc/apt/sources.list.d/docker.list
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> /etc/apt/sources.list.d/docker.list
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) edge" >> /etc/apt/sources.list.d/docker.list
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) nightly" >> /etc/apt/sources.list.d/docker.list
apt update
apt install -ym docker-ce
curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
groupadd docker
usermod -a -G docker $VDS_USER
usermod -a -G docker root
systemctl enable docker



# self-signed certificates
echo -e "\n *** Create self-signed Certificate ***"
echo -e "-------------------------------------------\n"

mkdir -v /etc/certs
openssl dhparam -out /etc/certs/dhparam.pem 2048
openssl req -x509 -nodes -newkey rsa:2048 -days 36500 -keyout /etc/certs/self-signed.key -out /etc/certs/self-signed.crt -subj /C=AA/ST=AA/L=Internet/O=MailInABox/CN=$(hostname -s)



# nginx proxy
echo -e "\n *** Install Web Server ***"
echo -e "-------------------------------------------\n"

add-apt-repository ppa:ondrej/nginx-mainline
apt update
apt install -y nginx
if [[ -f "$PWD/nginx.conf" ]]; then
    mv -v /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    cp -v "$PWD/nginx.conf" /etc/nginx/nginx.conf
    chown root:root /etc/nginx/nginx.conf
    chmod 644 /etc/nginx/nginx.conf
    nginx -s reload
else
    echo "Custom nginx.conf not found. Keep default."
fi

mkdir -v -m 775 /var/www
chown -R www-data:www-data /var/www



# let's encrypt
if [[ "$VDS_IS_REMOTE" = "y" ]]; then
    apt install -ym letsencrypt
fi



# portainer
echo -e "\n *** Install Docker manager ***"
echo -e "-------------------------------------------\n"

read -p "Enter domain name for Docker manager (portainer): " PORTAINER_DOMAIN

#docker run -d -e VIRTUAL_PORT=9000 -e VIRTUAL_HOST=${PORTAINER_DOMAIN} -e HSTS=off --net webproxy --restart always -v /var/run/docker.sock:/var/run/docker.sock -v /opt/portainer:/data --name portainer portainer/portainer
docker run -d -p 9000:9000 -v /etc/certs:/certs -v /var/run/docker.sock:/var/run/docker.sock -v /opt/portainer:/data --restart always --name portainer portainer/portainer --ssl --sslcert /certs/self-signed.crt --sslkey /certs/self-signed.key
#cp -v /etc/certs/self-signed.crt /opt/nginx-proxy/data/certs/${PORTAINER_DOMAIN}.crt
#cp -v /etc/certs/self-signed.key /opt/nginx-proxy/data/certs/${PORTAINER_DOMAIN}.key



# result
echo -e "\n *** All Done! ***"
echo "-------------------------------------------"
echo "Connect to VDS: ssh ${VDS_USER}@${HOST_IP}"
echo "Docker manager: https://${PORTAINER_DOMAIN}"
echo "Nginx Proxy documentation: https://github.com/evertramos/docker-compose-letsencrypt-nginx-proxy-companion"
echo -e "Reboot VDS to complete installation: sudo reboot\n"

systemctl start fail2ban

exit 0
