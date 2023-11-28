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
icinga2=2.14.0-1*
icinga2-bin=2.14.0-1*
icinga2-common=2.14.0-1*
icinga2-doc=2.14.0-1*
icinga2-ido-mysql=2.14.0-1*
icingaweb2-common=2.12.0-1*
icingacli=2.12.0-1*
php-icinga=2.12.0-1*
icinga-php-library=0.13.1-1*
icinga-php-thirdparty=0.12.0-1*
icingaweb2=2.12.0-1*
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
JITSI_VERSION=$(awk '/^VOIP_JITSI_VERSION:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/voip/defaults/main.yml)
CHECK_NTP_TIME_VERSION=$(awk '/^check_ntp_time_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/monitoring/vars/main.yml)

DOCKER_IMAGES="
harbor.teamwire.eu/teamwire/backend:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/notification-server:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/go-buildenv:latest
harbor.teamwire.eu/teamwire/web2:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/prosody:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jicofo:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jvb:${BACKEND_RELEASE}
$(awk '{ gsub("\"",""); print $2 } NR==2 {exit}' ~teamwire/platform/ansible/roles/docker/vars/main.yml)
"

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip;$(awk '/^consul_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip;$(awk '/^consul_template_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip;$(awk '/^nomad_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/nomad/vars/main.yml)
https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip;$(awk '/^vault_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)
https://repo.teamwire.eu/bin/icinga/check_ntp_time-${CHECK_NTP_TIME_VERSION};$(awk '/^check_ntp_time_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/monitoring/vars/main.yml)
"

if [ -z "${OFFLINE_INSTALLATION}" ] ; then
	echo "Not preparing for offline installation."
	exit
fi

echo "Preparing for offline installation."

# This file will be checked by the Ansible scripts; if it exists,
# the apt cache will not be updated.
sudo touch /etc/offline_installation

echo "Step 1: Install APT third-party prerequisites"
echo "============================================="
sudo apt-get update -q
sudo apt-get install -qy ${APT_3RD_PARTY_PREREQUISITES}

# Add additional repo signing keys
echo "Step 2: Import additional repo signing keys / repositories"
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
  sudo cp roles/monitoring/files/tw_monitoring_pinning /etc/apt/preferences.d/tw_monitoring_pinning
fi

# For whatever reason, APT downloads slightly different package dependencies when downloading all regular packages at once,
# e.g. php-cli is required when solely installing icingaweb2, but not when installing all regular packages at once.
# Thus, installing them one by one to get dependencies "properly" resolved
echo "Step 3: Caching packages"
echo "========================"
sudo apt-get update -q
for pkg in ${REGULAR_PACKAGES}; do
	sudo apt-get install -qyd $pkg
done

echo "Step 4: Getting Docker containers"
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

echo "Step 5: Downloading 3rd party software"
echo "======================================"
if [ ! -d /var/cache/downloads ] ; then
	sudo mkdir /var/cache/downloads
fi
for DOWNLOAD in ${DOWNLOADS} ; do
	# split line into URL and SHA256 checksum
	UC=(${DOWNLOAD//;/ })
	echo "Getting ${UC[0]}"
	wget -q "${UC[0]}"
	FILENAME="${UC[0]##*/}"
	if [ "${UC[1]}" != "$(sha256sum "${FILENAME}" | cut -d' ' -f1)" ] ; then
		echo "${FILENAME}: Checksum failure"
		exit 1
	fi
	sudo mv "${FILENAME}" /var/cache/downloads
done
