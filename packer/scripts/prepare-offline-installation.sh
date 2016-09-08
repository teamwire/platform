#!/bin/bash

# Preparations for offline installations:
#
# * Download debian packages into the local package cache
# * Pull required docker images
# * Download 3rd party files
#

REGULAR_PACKAGES="
git
dnsmasq
mariadb-server
mariadb-client
python-mysqldb
keepalived
nginx-light
python-redis
redis-tools
redis-server
nfs-kernel-server
rpcbind
glusterfs-server
glusterfs-client
nfs-common
"

BACKPORTS_PACKAGES="
python-docker
"

DOCKER_IMAGES="
teamwire/backend:${BACKEND_RELEASE}
teamwire/web-screenshot-server:${BACKEND_RELEASE}
teamwire/notification-server:${BACKEND_RELEASE}
redis:3.2.3-alpine
swarm:1.2.5
registry:2.5.0
gliderlabs/registrator:v7
"

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_linux_amd64.zip;abdf0e1856292468e2c9971420d73b805e93888e006c76324ae39416edcf0627
https://releases.hashicorp.com/consul/0.6.4/consul_0.6.4_web_ui.zip;5f8841b51e0e3e2eb1f1dc66a47310ae42b0448e77df14c83bb49e0e0d5fa4b7
https://releases.hashicorp.com/consul-template/0.15.0/consul-template_0.15.0_linux_amd64.zip;b7561158d2074c3c68ff62ae6fc1eafe8db250894043382fb31f0c78150c513a
"

if [ -z "$OFFLINE_INSTALLATION" ] ; then
	echo "Not preparing for offline installation."
	exit
fi

echo "Preparing for offline installation."

# This file will be checked by the Ansible scripts; if it exists,
# the apt cache will not be updated.
sudo touch /etc/offline_installation

echo "Step 1: Caching packages"
echo "========================"

sudo apt-get install -qyd $REGULAR_PACKAGES
sudo apt-get install -t jessie-backports -qyd $BACKPORTS_PACKAGES

echo "Step 2: Getting Docker containers"
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

echo "Step 3: Downloading 3rd party software"
echo "======================================"
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
	sudo mv "$FILENAME" /root
done
