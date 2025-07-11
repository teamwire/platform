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

CHECKMK_SHASUM_URL=$(jq -r '.monitoring.sha256' /etc/ansible/facts.d/general_facts.fact)
CHECKMK_SSLCERTIFICATES_SHASUM_URL=$(jq -r '.monitoring.monitoring.sslcertificates_sha256' /etc/ansible/facts.d/general_facts.fact)
MYDUMPER_SHASUM_URL=$(jq -r '.db.mydumper_sha256' /etc/ansible/facts.d/general_facts.fact)

DOCKER_IMAGES="
harbor.teamwire.eu/teamwire/backend:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/notification-server:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/go-buildenv:latest
harbor.teamwire.eu/teamwire/web2:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/prosody:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jicofo:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/jvb:${BACKEND_RELEASE}
harbor.teamwire.eu/teamwire/turn:${BACKEND_RELEASE}
$(jq -r '.docker_registry.container' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.hashiui.container' /etc/ansible/facts.d/general_facts.fact)
harbor.teamwire.eu/teamwire/dashboard:${DASHBOARD_RELEASE}
harbor.teamwire.eu/teamwire/webclient:${WEBCLIENT_RELEASE}
"

# File URL and SHA256 checksum separated by a semicolon
DOWNLOADS="
$(jq -r '.consul.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.consul.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.consul_template.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.consul_template.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.nomad.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.nomad.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.vault.url' /etc/ansible/facts.d/general_facts.fact);$(jq -r '.vault.sha256' /etc/ansible/facts.d/general_facts.fact)
$(jq -r '.monitoring.url' /etc/ansible/facts.d/general_facts.fact);$(curl -Ls "${CHECKMK_SHASUM_URL}" | jq -r '.items[].assets[].checksum.sha256')
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
