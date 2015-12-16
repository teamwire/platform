#!/bin/bash -e

if [[ $PACKER_BUILDER_TYPE =~ virtualbox ]]; then
	echo "Installing VirtualBox Guest Additions"

	sudo apt-get install -y --no-install-recommends virtualbox-guest-dkms virtualbox-guest-utils
fi
