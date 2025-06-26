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
acl
python3-rpm
apache2
apache2-bin
apache2-data
apache2-utils
libapache2-mod-php8.2
bc
binutils
binutils-common
binutils-x86-64-linux-gnu
debugedit
dialog
fontconfig
fontconfig-config
fonts-dejavu-core
graphviz
libabsl20220623
libann0
libaom3
libapr1
libaprutil1
libaprutil1-dbd-sqlite3
libaprutil1-ldap
libarchive13
libavahi-client3
libavahi-common-data
libavahi-common3
libavif15
libbinutils
libcairo2
libcdt5
libcgraph6
libctf-nobfd0
libctf0
libdatrie1
libdav1d6
libde265-0
libdeflate0
libdw1
libfontconfig1
libfreeradius3
libfribidi0
libfsverity0
libgav1-1
libgd3
libgomp1
libgprofng0
libgraphite2-3
libgsf-1-114
libgsf-1-common
libgts-0.7-5
libgvc6
libgvpr2
libharfbuzz0b
libheif1
libice6
libjbig0
libjpeg62-turbo
liblab-gamut1
liblcms2-2
libldb2
liblerc4
libltdl7
liblua5.3-0
libnspr4
libnss3
libnuma1
libopenjp2-7
libpango-1.0-0
libpango1.0-0
libpangocairo-1.0-0
libpangoft2-1.0-0
libpangoxft-1.0-0
libpathplan4
libpcap0.8
libpcre3
libpixman-1-0
libpoppler126
libpq5
librav1e0
librpm9
librpmbuild9
librpmio9
librpmsign9
libsm6
libsmbclient
libsvtav1enc1
libtalloc2
libtdb1
libtevent0
libthai-data
libthai0
libtiff6
libwbclient0
libwebp7
libx265-199
libxaw7
libxcb-render0
libxcb-shm0
libxft2
libxmu6
libxpm4
libxrender1
libxt6
libyuv0
php
php-cgi
php-common
php-gd
php-pear
php-sqlite3
php-xml
php8.2
php8.2-cgi
php8.2-cli
php8.2-common
php8.2-gd
php8.2-opcache
php8.2-readline
php8.2-sqlite3
php8.2-xml
poppler-utils
psmisc
rpcbind
rpm
rpm-common
rpm2cpio
samba-common
samba-libs
smbclient
time
x11-common
"

REMOTE_URL=$(jq -r '.general.url' /etc/ansible/facts.d/general_facts.fact)

CONSUL_VERSION=$(awk '/^consul_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
CONSUL_TEMPLATE_VERSION=$(awk '/^consul_template_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
VAULT_VERSION=$(awk '/^vault_version:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)
CHECKMK_VERSION=$(jq -r '.monitoring.version' /etc/ansible/facts.d/general_facts.fact)
CHECKMK_REMOTE_PATH=$(jq -r '.monitoring.path' /etc/ansible/facts.d/general_facts.fact)
CHECKMK_SSLCERTIFICATE_VERSION=$(jq -r '.monitoring.sslcertificate_version' /etc/ansible/facts.d/general_facts.fact)
CHECKMK_SSLCERTIFICATE_REMOTE_PATH=$(jq -r '.monitoring.sslcertificate_path' /etc/ansible/facts.d/general_facts.fact)

# Include Variables for OS Version
# shellcheck disable=SC1091
source /etc/os-release

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
harbor.teamwire.eu/teamwire/dashboard:${DASHBOARD_RELEASE}
harbor.teamwire.eu/teamwire/webclient:${WEBCLIENT_RELEASE}
"

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip;$(awk '/^consul_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/consul/vars/main.yml)
https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip;$(awk '/^consul_template_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/frontend/vars/main.yml)
$(jq -r '.nomad.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.nomad.sha256' /etc/ansible/facts.d/general_facts.fact)
https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip;$(awk '/^vault_checksum:/ { gsub("\"",""); print $2 }' ~teamwire/platform/ansible/roles/vault/vars/main.yml)
${REMOTE_URL}/external${CHECKMK_REMOTE_PATH}/check-mk-raw-${CHECKMK_VERSION}.${VERSION_CODENAME}_amd64.deb;$(curl -Ls "${REMOTE_URL}/service/rest/v1/search?repository=external&name=${CHECKMK_REMOTE_PATH}/check-mk-raw-${CHECKMK_VERSION}.${VERSION_CODENAME}_amd64.deb" | jq -r '.items[].assets[].checksum.sha256')
${REMOTE_URL}/repository/external${CHECKMK_SSLCERTIFICATE_REMOTE_PATH}/sslcertificates-${CHECKMK_SSLCERTIFICATE_VERSION}.mkp;$(curl -Ls "${REMOTE_URL}/service/rest/v1/search?repository=external&name=${CHECKMK_SSLCERTIFICATE_REMOTE_PATH}/sslcertificates-${CHECKMK_SSLCERTIFICATE_VERSION}.mkp" | jq -r '.items[].assets[].checksum.sha256')
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

# Configure Maxscale Repository Key
if [ ! -f /etc/apt/trusted.gpg.d/mariadb-maxscale.gpg ]; then
  MAXSCALE_GPG_KEY_ID=$(grep "maxscale_gpg_key_id" ~teamwire/platform/ansible/roles/db/defaults/main.yml | sed -e 's/"//g' | cut -d ':' -f2 | sed -e 's/^0x//')

  sudo gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "${MAXSCALE_GPG_KEY_ID}"
  sudo gpg --export "${MAXSCALE_GPG_KEY_ID}" | sudo tee /etc/apt/trusted.gpg.d/mariadb-maxscale.gpg
  echo "deb [arch=amd64,arm64] https://dlm.mariadb.com/repo/maxscale/latest/apt ${VERSION_CODENAME} main" | sudo tee /etc/apt/sources.list.d/mariadb-maxscale.list
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
