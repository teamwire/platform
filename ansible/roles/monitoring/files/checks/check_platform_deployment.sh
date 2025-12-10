#!/bin/bash
# Ensure platform deployment is not incomplete

PLATFORM_VERSION_FILE_CONTENT=$(cat /etc/platform_version)
ACTIVE_PLAYBOOK_RUN=$(ps aux | grep -c 'ansible-playbook')

if [[ "${PLATFORM_VERSION_FILE_CONTENT}" =~ ^.*incomplete.*$ ]] && ! [ "${ACTIVE_PLAYBOOK_RUN}" -gt 1 ]; then
  echo "WARNING - Platform Deployment is incomplete. Please check"
  exit 1
else
  echo "OK - Platform Deployment state is ok"
  exit 0
fi
