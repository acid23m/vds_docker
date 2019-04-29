# Dockerized VDS

Auto configurable scripts bundle.

## Scripts

- **vds_setup.sh**: install and configure soft on just-created VDS.
- **app_setup.sh**: install and configure [dockerized application](https://github.com/acid23m/base-docker.git).

## Usage

Connect to newly installed Ubuntu VDS via ssh.

```bash
ssh root@123.456.789.000

```

Clone bundle.

```bash
apt update
apt install git -y
git clone git@github.com:acid23m/vds_docker.git
# or
#git clone https://github.com/acid23m/vds_docker.git
cd vds_docker
```

Edit settings.

```bash
cp -av .env.example .env
nano .env
```

### VDS

Run **vds_setup.sh**.

```bash
./vds_setup.sh
```
It will:

- upgrade system
- install required soft (eg. openssl, curl ..) and helpfull soft (eg. mc)
- create user defined in *.env*
- configure *ssh server*
- install and configure *fail2ban*
- configure *firewall*
- install *docker* and *docker-compose*
- create *self-signed certificates*
- install and configure *nginx*
- install [ACME shell script](https://github.com/Neilpang/acme.sh)
- install dockerized *portainer*

Reboot VDS.

```bash
reboot
```

### Applications

Application must be compatible with [base-docker](https://github.com/acid23m/base-docker).
Application always use SSL.

Run **app_setup.sh** with parameters.

```bash
./app_setup.sh git@bitbucket.org:acid23m/base-docker-app.git base base-app.com 8000
```

Done!
