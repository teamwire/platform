#!/bin/bash -e

echo "Installing Vagrant 'insecure' public key"
mkdir -pm 700 /home/vagrant/.ssh
wget -q --no-check-certificate https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
