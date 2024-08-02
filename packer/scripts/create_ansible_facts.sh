#!/bin/sh -e

# Create fact.d and if necessary the parent folders
sudo mkdir -p /etc/ansible/facts.d

# Create offline_mode fact
printf '{
    "stat":{
        "exists": false
    }
}
' | sudo tee /etc/ansible/facts.d/offline_mode.fact
