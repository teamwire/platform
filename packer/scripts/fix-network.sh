#!/bin/sh -e

# Disabling predictive networking
sudo ln -s /dev/null /etc/udev/rules.d/70-persistent-net.rules
sudo rm -f /lib/udev/rules.d/75-persistent-net-generator.rules
sudo rm -rf /dev/.udev/ /var/lib/dhcp/*

sudo update-grub
sudo update-initramfs -u

cat << EOL | sudo tee /etc/network/interfaces
source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet dhcp
pre-up sleep 2
EOL
