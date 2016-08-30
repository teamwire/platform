#!/bin/sh

# Remove Docker key to ensure each VM gets an unique ID
sudo rm -f /etc/docker/key.json

# Remove SSH host keys
sudo rm -f /etc/ssh/ssh_host_*

# Ensure SSH host keys are regenerated during startup
sudo sed -i '/^exit 0/idpkg-reconfigure openssh-server\n' /etc/rc.local
