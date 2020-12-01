#!/bin/bash
# -----------------------------------------------------------------------------
# Declare variables
# -----------------------------------------------------------------------------
DEFAULT_HOME_DIR="/data/archiving/gpg"
HOME_DIR="${1:-$DEFAULT_HOME_DIR}"
_warn_homeDir="No commandline args provided! Assuming that default gpg home dir.
If you want to change the default path, please run the script like this:
'${0} /full/path/archiving/dir'

Using default home dir ${DEFAULT_HOME_DIR}

Press any key to continue or '[CMD] + c' to cancel the script\n"

# -----------------------------------------------------------------------------
# Running the migrations procedure itself.
# -----------------------------------------------------------------------------
migrate-pubring-from-classic-gpg ${DEFAULT_HOME_DIR}
chown -R daemon:daemon /data/archiving/gpg
chmod -R go= /data/archiving/gpg
chown -R root:daemon /data/archiving/archiving.conf
chmod 0640 /data/archiving/archiving.conf
echo 1 > /etc/gpg2Migration
