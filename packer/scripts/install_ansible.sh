#!/bin/bash -e

echo "Installing Ansible"

. /etc/os-release

case "$ID" in
    "ubuntu")
        if [ "$VERSION_ID" != "14.04" ] ; then
            echo "Unsupported Ubuntu release"
            exit 1
        fi
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy software-properties-common
        sudo apt-add-repository -y ppa:ansible/ansible
        ;;
    "debian")
        if [ "$VERSION_ID" != "8" ] ; then
            echo "Unsupported Debian release"
            exit 1
        fi
        # Ansible 2.0 is included in jessie-backports, which is configured by
        # the preseed configuration. The backport must be requested explicitly.
        OPTION="-t jessie-backports"
        ;;
esac

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get $OPTION install -y ansible
