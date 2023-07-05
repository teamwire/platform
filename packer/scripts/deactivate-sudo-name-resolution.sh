#!/bin/sh -e

# Inserts the !fqdn config after the last Defaults config snippet in
echo 'Defaults !fqdn' | sudo tee /etc/sudoers.d/deactivate-name-resolution