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
libcap2-bin
dnsutils
gnupg2
maxscale
nullmailer
debsums
apt-listbugs
libpam-tmpdir
xinetd
"

CHECKMK_SHASUM_URL=$(jq -r '.monitoring.sha256' /etc/ansible/facts.d/general_facts.fact)
CHECKMK_SSLCERTIFICATES_SHASUM_URL=$(jq -r '.monitoring.monitoring.sslcertificates_sha256' /etc/ansible/facts.d/general_facts.fact)
MYDUMPER_SHASUM_URL=$(jq -r '.db.mydumper_sha256' /etc/ansible/facts.d/general_facts.fact)

DOCKER_IMAGES="
harbor.teamwire.eu/teamwire/backend:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/notification-server:${BACKEND_RELEASE}
$(jq -r '.go.container' /etc/ansible/facts.d/general_facts.fact)
harbor.teamwire.eu/teamwire/web2:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/prosody:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jicofo:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jvb:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/turn:${BACKEND_RELEASE}
$(jq -r '.docker_registry.container' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.hashiui.container' /etc/ansible/facts.d/general_facts.fact)
harbor.teamwire.eu/teamwire/dashboard:${DASHBOARD_RELEASE}
harbor.teamwire.eu/teamwire/webclient:${WEBCLIENT_RELEASE}
$(jq -r '.monitoring.container' /etc/ansible/facts.d/general_facts.fact)
"

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
$(jq -r '.consul.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.consul.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.consul_template.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.consul_template.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.nomad.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.nomad.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.vault.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.vault.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.monitoring.sslcertificates_url' /etc/ansible/facts.d/general_facts.fact);$(curl -Ls "${CHECKMK_SSLCERTIFICATES_SHASUM_URL}" | jq -r '.items[].assets[].checksum.sha256')
$(jq -r '.db.mydumper_url' /etc/ansible/facts.d/general_facts.fact);$(curl -Ls "${MYDUMPER_SHASUM_URL}" | jq -r '.items[].assets[].checksum.sha256')
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
DOCKER_REPOSITORY_KEY_DESTINATION=$(jq -r '.docker.repository_key_destination' /etc/ansible/facts.d/general_facts.fact)
if [ ! -f "${DOCKER_REPOSITORY_KEY_DESTINATION}" ]; then
  DOCKER_REPOSITORY_KEY_URL=$(jq -r '.docker.repository_key_url' /etc/ansible/facts.d/general_facts.fact)
  sudo wget -q -O "${DOCKER_REPOSITORY_KEY_DESTINATION}" "${DOCKER_REPOSITORY_KEY_URL}"
fi

# Configure Maxscale Repository Key
if [ ! -f /etc/apt/trusted.gpg.d/mariadb-maxscale.gpg ]; then
  MAXSCALE_REPOSITORY_KEY_URL=$(jq -r '.db.maxscale_repository_key_url' /etc/ansible/facts.d/general_facts.fact)
  MAXSCALE_REPOSITORY_STRING=$(jq -r '.db.maxscale_apt_repository_string' /etc/ansible/facts.d/general_facts.fact)

  sudo curl -Ls "${MAXSCALE_REPOSITORY_KEY_URL}" -o /etc/apt/trusted.gpg.d/mariadb-maxscale.asc
  echo "${MAXSCALE_REPOSITORY_STRING}" | sudo tee /etc/apt/sources.list.d/mariadb-maxscale.list
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


echo "Step 6: Creating Release file"
echo "================================="
sudo mkdir /usr/local/share/twctl
echo "BACKEND_VERSION=${BACKEND_RELEASE}" | sudo tee /usr/local/share/twctl/teamwire-release
echo "DASHBOARD_VERSION=${DASHBOARD_RELEASE}" | sudo tee -a /usr/local/share/twctl/teamwire-release
echo "WEBCLIENT_VERSION=${WEBCLIENT_RELEASE}" | sudo tee -a /usr/local/share/twctl/teamwire-release

echo "Step 7: Creating version facts"
echo "================================="
echo '{"tag": "'"${BACKEND_RELEASE}"'"}' | sudo tee /etc/ansible/facts.d/backend_version.fact
echo '{"tag": "'"${DASHBOARD_RELEASE}"'"}' | sudo tee /etc/ansible/facts.d/dashboard_version.fact
echo '{"tag": "'"${WEBCLIENT_RELEASE}"'"}' | sudo tee /etc/ansible/facts.d/webclient_version.fact
