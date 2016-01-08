#!/bin/bash -e

if [[ $PACKER_BUILDER_TYPE =~ vmware ]]; then
	echo "Installing VMware Tools"
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends open-vm-tools
elif [[ $PACKER_BUILDER_TYPE =~ virtualbox ]]; then
	echo "Installing VirtualBox Guest Additions"
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends virtualbox-guest-dkms virtualbox-guest-utils
fi
