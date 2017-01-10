#!/bin/sh -e

if [ -z "$OFFLINE_INSTALLATION" ] ; then
	echo "Deleting apt cache"
	sudo apt-get clean
	sudo rm -rf /var/lib/apt/lists/*
fi

sudo rm -rf /tmp/* /var/tmp/*

echo "Shrinking disk image"
sudo dd if=/dev/zero of=/zeroes bs=1M || true
sudo rm -f /zeroes
