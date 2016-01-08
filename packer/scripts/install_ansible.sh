#!/bin/bash -e

echo "Installing Ansible"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qqy ansible
