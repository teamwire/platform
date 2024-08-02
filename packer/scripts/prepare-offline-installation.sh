#!/bin/bash -e
# Preparations for offline installations:
#
# * Download debian packages into the local package cache
# * Pull required docker images
# * Download 3rd party files
# * Build Python modules
#

APT_3RD_PARTY_PREREQUISITES="
ca-certificates
curl
gnupg
lsb-release
"

REGULAR_PACKAGES="
git
dnsmasq
mydumper
mariadb-server
mariadb-client
mariadb-backup
sshpass
python3-mysqldb
keepalived
python3-redis
redis-tools
redis-server
redis-sentinel
nfs-kernel-server
rpcbind
glusterfs-server
glusterfs-client
nfs-common
haproxy
libconfig-inifiles-perl
libterm-readkey-perl
socat
patch
python3-docker
mlock
libcap2-bin
icinga2
icinga2-bin
icinga2-common
icinga2-doc
icinga2-ido-mysql
icingaweb2-common
icingacli
php-icinga
icinga-php-library
icinga-php-thirdparty
icingaweb2
monitoring-plugins
nagios-plugins-contrib
libredis-perl
libmonitoring-plugin-perl
liblwp-useragent-determined-perl
libdbd-mysql-perl
dnsutils
apache2
libapache2-mod-php
php
php-mysql
php-curl
php-imagick
php-intl
php-gd
php-xml
jq
gnupg2
"

CONSUL_VERSION=$(awk '/^consul_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
CONSUL_TEMPLATE_VERSION=$(awk '/^consul_template_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
NOMAD_VERSION=$(awk '/^nomad_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/nomad/vars/main.yml)
VAULT_VERSION=$(awk '/^vault_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)

DOCKER_IMAGES="
harbor.teamwire.eu/teamwire/backend:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/notification-server:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/go-buildenv:latest
harbor.teamwire.eu/teamwire/web2:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/prosody:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jicofo:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jvb:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/turn:${BACKEND_RELEASE}
$(awk '/^registry_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/docker/vars/main.yml)
$(awk '/^hashui_container:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/docker/vars/main.yml)
"

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip;$(awk '/^consul_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip;$(awk '/^consul_template_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip;$(awk '/^nomad_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/nomad/vars/main.yml)
https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip;$(awk '/^vault_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)
https://repo.teamwire.eu/external/ftp/icinga_packages.txt;$(curl -s https://repo.teamwire.eu/external/ftp/checksum_icinga_packages)
https://repo.teamwire.eu/external/ftp/check_ntp_time-latest;$(curl -s https://repo.teamwire.eu/external/ftp/checksum_check_ntp_time-latest)
"

if [ -z "${OFFLINE_INSTALLATION}" ] ; then
  echo "Not preparing for offline installation."
  exit
fi

echo "Preparing for offline installation."

# This file will be checked by the Ansible scripts; if it exists,
# the apt cache will not be updated.
sudo sed -i 's/false/true/' /etc/ansible/facts.d/offline_mode.fact

echo "Step 1: Install APT third-party prerequisites"
echo "============================================="
sudo apt-get update -q
for pkg in ${APT_3RD_PARTY_PREREQUISITES}; do
  sudo apt-get install -qyd "${pkg}"
done

echo "Step 2: Downloading 3rd party software and teamwire package lists"
echo "================================================================="
for DOWNLOAD in ${DOWNLOADS} ; do
  # split line into URL and SHA256 checksum
  IFS=";" read -r -a UC <<< "${DOWNLOAD}"
  echo "Getting ${UC[0]}"
  wget -q "${UC[0]}"
  FILENAME="${UC[0]##*/}"
  if [ "${UC[1]}" != "$(sha256sum "${FILENAME}" | cut -d' ' -f1)" ] ; then
    echo "${FILENAME}: Checksum failure"
    exit 1
  fi
  sudo mv "${FILENAME}" /var/cache/downloads
done

# Add additional repo signing keys
echo "Step 3: Import additional repo signing keys / repositories"
echo "==========================================="
sudo apt-get update -q

# Configure Docker Repository Key
# https://docs.docker.com/engine/install/debian/#install-using-the-repository
if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
  sudo wget -q -O /usr/share/keyrings/docker-archive-keyring.key https://download.docker.com/linux/debian/gpg
  sudo gpg --no-tty --batch --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg /usr/share/keyrings/docker-archive-keyring.key
fi

# Configure Icinga2 Repository and Key
# https://icinga.com/docs/icinga-2/latest/doc/02-installation/01-Debian/#debian-repository
if [ ! -f /usr/share/keyrings/icinga-archive-keyring.key ]; then
  sudo wget -q -O /usr/share/keyrings/icinga-archive-keyring.key https://packages.icinga.com/icinga.key
  sudo gpg --no-tty --batch --dearmor -o /usr/share/keyrings/icinga-archive-keyring.gpg /usr/share/keyrings/icinga-archive-keyring.key
fi

if [ ! -f /etc/apt/sources.list.d/icinga2.list ]; then
  DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release)
  echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.key] https://packages.icinga.com/debian icinga-${DIST} main" | sudo tee /etc/apt/sources.list.d/icinga2.list
fi

if [ ! -f /etc/apt/preferences.d/tw_monitoring_pinning ]; then
  cd ~/platform/ansible
  ansible localhost -i hosts -m template -b -a "src=roles/monitoring/templates/tw_monitoring_pinning.j2 dest=/etc/apt/preferences.d/tw_monitoring_pinning owner=root group=root mode=0644" -e @roles/monitoring/defaults/main.yml
fi

# For whatever reason, APT downloads slightly different package dependencies when downloading all regular packages at once,
# e.g. php-cli is required when solely installing icingaweb2, but not when installing all regular packages at once.
# Thus, installing them one by one to get dependencies "properly" resolved
echo "Step 4: Caching packages"
echo "========================"
sudo apt-get update -q
for pkg in ${REGULAR_PACKAGES}; do
  sudo apt-get install -qyd "${pkg}"
done

echo "Step 5: Getting Docker containers"
echo "================================="
# We need to use sudo as the teamwire user is apparently not yet updated
sudo docker login -u "${DOCKERHUB_USERNAME}" -p "${DOCKERHUB_PASSWORD}" harbor.teamwire.eu
for IMAGE in ${DOCKER_IMAGES} ; do
  sudo docker pull "${IMAGE}"
done
sudo rm -rf /root/.docker

cd ~/platform/ansible/group_vars
cp all.example all
sed -i -e 's/^\(version: \).*$/\1'"${BACKEND_RELEASE}"'/' all
