#!/bin/bash
set -euo pipefail

# Configure Vault environment if needed
export VAULT_ADDR=https://127.0.0.1:8200
export VAULT_TOKEN=$(cat /etc/ansible/job-read.token)

# Renew the token
vault token renew -increment=72h
