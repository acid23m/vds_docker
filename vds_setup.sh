#!/usr/bin/env bash


# --------------------------------------------------------
# THIS SCRIPT AUTOMATICALLY CONFIGURES DOCKER ORIENTED VDS
# --------------------------------------------------------


set -ae
. ./.env
set +a



if [[ $(id -u) != 0 ]]; then
    echo "Run script with superuser privileges!"
    exit 1
fi


if [[ "$VDS_IS_REMOTE" = "y" ]] && [[ -z "$HOST_IP" ]]; then
    HOST_IP=$(curl -s https://api.ipify.org)
fi



# update system
echo -e "\n *** Update system ***"
echo -e "-------------------------------------------\n"

apt update
apt dist-upgrade -y
apt full-upgrade -y
apt install -ym git openssl software-properties-common bc wget curl cron python3 mc tree
apt autoremove -y
apt autoclean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



# create main user
echo -e "\n *** Create main User ***"
echo -e "-------------------------------------------\n"

echo "Creating user $VDS_USER"
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

mkdir -vp -m 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh
echo -e "\n${ID_RSA_PUB}" >> /root/.ssh/authorized_keys

mkdir -vp -m 700 "/home/${VDS_USER}/.ssh"
touch "/home/${VDS_USER}/.ssh/authorized_keys"
chmod 600 "/home/${VDS_USER}/.ssh/authorized_keys"
echo -e "\n${ID_RSA_PUB}" >> "/home/${VDS_USER}/.ssh/authorized_keys"
ssh-keygen -t rsa -P "" -f "/home/${VDS_USER}/.ssh/id_rsa"
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
chown -R "${VDS_USER}:${VDS_USER}" "/home/${VDS_USER}/.ssh"
service ssh restart



# fail2ban
echo -e "\n *** Configure Fail2ban ***"
echo -e "-------------------------------------------\n"

add-apt-repository -y universe
apt update
apt install -ym fail2ban
if [[ -f "/etc/fail2ban/jail.d/defaults-debian.conf" ]]; then
    echo -e "\n[sshd-ddos]\nenabled = true\n" >> /etc/fail2ban/jail.d/defaults-debian.conf
fi
service fail2ban start



# firewall
echo -e "\n *** Configure Firewall ***"
echo -e "-------------------------------------------\n"

ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
# docker ports
ufw allow 2377/tcp
ufw allow 7946
ufw allow 4789/udp
ufw enable
ufw status



# docker
echo -e "\n *** Install Docker ***"
echo -e "-------------------------------------------\n"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
touch /etc/apt/sources.list.d/docker.list
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> /etc/apt/sources.list.d/docker.list
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) edge" >> /etc/apt/sources.list.d/docker.list
#echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) nightly" >> /etc/apt/sources.list.d/docker.list
apt update
apt install -ym docker-ce
curl -L https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
groupadd -f docker
usermod -a -G docker $VDS_USER
usermod -a -G docker root
systemctl enable docker



# self-signed certificates
echo -e "\n *** Create self-signed Certificate ***"
echo -e "-------------------------------------------\n"

mkdir -pv /etc/certs/self-signed
openssl dhparam -out /etc/certs/dhparam.pem -dsaparam 4096
openssl req -x509 -nodes -newkey rsa:4096 -days 36500 -keyout /etc/certs/self-signed/cert.key -out /etc/certs/self-signed/cert.crt -subj "/C=RU/ST=RU/L=Internet/O=$(hostname -s)/CN=${HOST_IP}"



# nginx proxy
echo -e "\n *** Install Web Server ***"
echo -e "-------------------------------------------\n"

add-apt-repository -y ppa:ondrej/nginx-mainline
apt update
apt install -y nginx
if [[ -f "$PWD/nginx/nginx.conf" ]]; then
    mv -v /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    cp -v "$PWD/nginx/nginx.conf" /etc/nginx/nginx.conf
    chown root:root /etc/nginx/nginx.conf
    chmod 644 /etc/nginx/nginx.conf
    mkdir -pv /tmp/nginx-proxy-cache
    nginx -s reload
else
    echo "Custom nginx.conf not found. Keep default."
fi

mkdir -pv -m 775 /var/www
chown -R "${VDS_USER}:www-data" /var/www



# let's encrypt
if [[ "$VDS_IS_REMOTE" = "y" ]]; then
    git clone https://github.com/Neilpang/acme.sh.git
    apt install -ym socat
    cd "$PWD/acme.sh"
    /bin/bash acme.sh --install --accountemail  "${ADMIN_EMAIL}"
    cd "$PWD/.."
    rm -r "$PWD/acme.sh"
    source /root/.bashrc
fi



# portainer
echo -e "\n *** Install Docker manager ***"
echo -e "-------------------------------------------\n"

docker run -d -p 9000:9000 -v /etc/certs/self-signed:/certs -v /var/run/docker.sock:/var/run/docker.sock -v /opt/portainer:/data --restart always --name portainer portainer/portainer --ssl --sslcert /certs/cert.crt --sslkey /certs/cert.key
sed "s/portainer/${PORTAINER_DOMAIN}/g" "$PWD/nginx/portainer.conf" > /etc/nginx/conf.d/portainer.conf
chmod 644 /etc/nginx/conf.d/portainer.conf
nginx -s reload


# result
echo -e "\n *** All Done! ***"
echo "-------------------------------------------"
echo "Connect to VDS: ssh ${VDS_USER}@${HOST_IP}"
echo "Docker manager: https://${PORTAINER_DOMAIN}"
if [[ "$VDS_IS_REMOTE" = "y" ]]; then
    echo "An ACME Shell script: https://github.com/Neilpang/acme.sh"
else
    echo "Don't forget to add '${HOST_IP} ${PORTAINER_DOMAIN}' to /etc/hosts"
fi
echo -e "Reboot VDS to complete installation: sudo reboot\n"

exit 0
