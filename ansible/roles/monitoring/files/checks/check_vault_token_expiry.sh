#!/bin/bash

# Define necessary variables
export VAULT_ADDR=https://127.0.0.1:8200
LOOKUP_VAULT_TOKEN=$(cat /etc/ansible/job-read.token)

# 36 hours in seconds
CRIT_IN_SECONDS="129600"
# 48 hours in seconds
WARN_IN_SECONDS="172800"

# Lookup the vault token used by the containers
VAULT_TOKEN_INFO=$(vault token lookup -format=json "${LOOKUP_VAULT_TOKEN}")
VAULT_TOKEN_INFO_EXIT_CODE=$?

if [[ "${VAULT_TOKEN_INFO_EXIT_CODE}" != 0 ]]; then
  echo "CRITICAL - Something went wrong while executing the vault token lookup. Please check if the vault is unsealed"
  exit 2
fi

# Extract exact informations from the vault token lookup
VAULT_TOKEN_EXPIRE_TIME=$(echo "${VAULT_TOKEN_INFO}" | jq -r .data.expire_time )
VAULT_TOKEN_TTL=$(echo "${VAULT_TOKEN_INFO}" | jq -r .data.ttl)

# Format dates for the output of the checks
FORMATED_VAULT_TOKEN_EXPIRE_TIME=$(date -d "${VAULT_TOKEN_EXPIRE_TIME}" '+%Y-%m-%d %H:%M:%S %Z')

if [[ "${VAULT_TOKEN_TTL}" -gt "${WARN_IN_SECONDS}" ]]; then
  echo "OK - Vault Token is expiring at ${FORMATED_VAULT_TOKEN_EXPIRE_TIME}"
  exit 0
elif [[ "${VAULT_TOKEN_TTL}" -le "${WARN_IN_SECONDS}" ]] && [[ "${VAULT_TOKEN_TTL}" -gt "${CRIT_IN_SECONDS}" ]]; then
  echo "WARNING - The vault token for the docker container is expiring within the next 48 hours. Check the renewal Service and timer!"
  echo ""
  echo "Vault Token Expiry Date: ${FORMATED_VAULT_TOKEN_EXPIRE_TIME}"
  exit 1
elif [[ "${VAULT_TOKEN_TTL}" -le "${CRIT_IN_SECONDS}" ]]; then
  echo "CRITICAL - The vault token for the docker container is expiring within the next 36 hours. Check the renewal Service and timer ASAP!"
  echo ""
  echo "Vault Token Expiry Date: ${FORMATED_VAULT_TOKEN_EXPIRE_TIME}"
  exit 2
else
  echo "UNKNOWN - Something went wrong while evaluating the vault token ttl"
  exit 3
fi
