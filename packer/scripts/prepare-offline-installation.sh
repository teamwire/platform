#!/bin/bash -e

# Preparations for offline installations:
#
# * Download debian packages into the local package cache
# * Pull required docker images
# * Download 3rd party files
# * Build Python modules
#

REGULAR_PACKAGES="
git
dnsmasq
mydumper
mariadb-server
mariadb-client
python-mysqldb
keepalived
python-redis
redis-tools
redis-server
redis-sentinel
nfs-kernel-server
rpcbind
glusterfs-server
glusterfs-client
nfs-common
galera
haproxy
hatop
libconfig-inifiles-perl
libterm-readkey-perl
percona-xtrabackup-24
socat
patch
python-backports.ssl-match-hostname
python-docker
mlock
libcap2-bin
curl
icinga2
icinga2-ido-mysql
icingacli
icingaweb2
icingaweb2-module-monitoring
monitoring-plugins
nagios-plugins-contrib
libredis-perl
libmonitoring-plugin-perl
liblwp-useragent-determined-perl
libdbd-mysql-perl
dnsutils
apache2
libapache2-mod-php
php${PHP_VERSION}
php${PHP_VERSION}-mysql
php${PHP_VERSION}-curl
php${PHP_VERSION}-imagick
php${PHP_VERSION}-intl
php${PHP_VERSION}-gd
php${PHP_VERSION}-xml
jq
gnupg1
dnsutils
"

DOCKER_IMAGES="
teamwire/backend:${BACKEND_RELEASE}
teamwire/web-screenshot-server:${BACKEND_RELEASE}
teamwire/notification-server:${BACKEND_RELEASE}
$(awk '{ gsub("\"",""); print $2; }' ~teamwire/platform/ansible/roles/docker/vars/main.yml)
"

CONSUL_VERSION=$(awk '/^consul_version:/ { print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
CONSUL_TEMPLATE_VERSION=$(awk '/^consul_template_version:/ { print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
NOMAD_VERSION=$(awk '/^nomad_version:/ { print $2 }' ~teamwire/platform/ansible/roles/nomad/vars/main.yml)
VAULT_VERSION=$(awk '/^vault_version:/ { print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)
PHP_VERSION=$(awk '/^php_version:/ { print $2 }' ~teamwire/platform/ansible/roles/monitoring/vars/main.yml)

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip;$(awk '/^consul_checksum:/ { print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip;$(awk '/^consul_template_checksum:/ { print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip;$(awk '/^nomad_checksum:/ { print $2 }' ~teamwire/platform/ansible/roles/nomad/vars/main.yml)
https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip;$(awk '/^vault_checksum:/ { print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)
"

# Add additional repo signing keys
# Always perform this step, even if not preparing for offline installation - this spares us some firewall rules
echo "Step 1: Import additional repo signing keys"
echo "==========================================="
sudo apt-key adv --no-tty --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 # Docker
sudo apt-key adv --no-tty --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 9334A25F8507EFA5 # Percona

if [ -z "$OFFLINE_INSTALLATION" ] ; then
	echo "Not preparing for offline installation."
	exit
fi

echo "Preparing for offline installation."

# This file will be checked by the Ansible scripts; if it exists,
# the apt cache will not be updated.
sudo touch /etc/offline_installation

echo "Step 2: Caching packages"
echo "========================"

# Add Percona repo
echo 'deb http://repo.percona.com/apt buster main' | sudo tee -a /etc/apt/sources.list > /dev/null
sudo apt-get update -q
sudo apt-get install -qyd $REGULAR_PACKAGES

echo "Step 3: Getting Docker containers"
echo "================================="
# We need to use sudo as the teamwire user is apparently not yet updated
sudo docker login -u "$DOCKERHUB_USERNAME" -p "$DOCKERHUB_PASSWORD"
for IMAGE in $DOCKER_IMAGES ; do
	sudo docker pull "${IMAGE}"
done
sudo rm -rf /root/.docker

cd ~/platform/ansible/group_vars
cp all.example all
sed -i -e 's/^\(version: \).*$/\1'"$BACKEND_RELEASE"'/' all

echo "Step 4: Downloading 3rd party software"
echo "======================================"
if [ ! -d /var/cache/downloads ] ; then
	sudo mkdir /var/cache/downloads
fi
for DOWNLOAD in $DOWNLOADS ; do
	# split line into URL and SHA256 checksum
	UC=(${DOWNLOAD//;/ })
	echo "Getting ${UC[0]}"
	wget -q "${UC[0]}"
	FILENAME="${UC[0]##*/}"
	if [ "${UC[1]}" != "$(sha256sum "${FILENAME}" | cut -d' ' -f1)" ] ; then
		echo "${FILENAME}: Checksum failure"
		exit 1
	fi
	sudo mv "$FILENAME" /var/cache/downloads
done
