#!/bin/bash
clear -x
cat << 'FEOF'
###############################################################################
             _____                 __        ___
            |_   _|__  __ _ _ __ __\ \      / (_)_ __ ___
              | |/ _ \/ _` | '_ ` _ \ \ /\ / /| | '__/ _ \
              | |  __/ (_| | | | | | \ V  V / | | | |  __/
              |_|\___|\__,_|_| |_| |_|\_/\_/  |_|_|  \___|

FEOF
cat << EOF
-------------------------------------------------------------------------------
Platform version: $(< /etc/platform_version)
-------------------------------------------------------------------------------
Hotline: +49 89 1222199 23
Email: support@teamwire.eu

===============================================================================
Run \`twctl --help\` to display all available commands
===============================================================================
Last 5 logins:
$(last -n 5)

###############################################################################
EOF
files=""

for name in "vault-credentials" "nomad-token"; do
  found="$(find /home -name "${name}" 2>/dev/null | grep -E '.*')"
  if [ -n "${found}" ]; then
    files="${files}\n${found}"
  fi
done

if [ -n "${files}" ]; then
  echo -e "\033[91;5m!!!ATTENTION!!!\033[0m"
  echo "Please store the following file(s) offline and then remove it from this server:"
  echo -e "\033[91;5m${files}\033[0m\n"
fi

