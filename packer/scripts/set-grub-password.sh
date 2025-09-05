#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Setting GRUB password ---"

# Define the GRUB username and the pre-generated PBKDF2 hash.
GRUB_USER="root"
GRUB_HASH="grub.pbkdf2.sha512.10000.A68A66B86E6965C496A6DC61FAFB83C8ED14009193AB1AA73A9A7425537992B6DE971F21F54FBFBC7574C4A335F545D5F3864482B366204BA37DABE113A2E12B.245BDB45B246AAB5373752D9FA55151F78DCB8872CD0A0BB8E1B026C086C50763C3598F7A5342138459DC4C142F1A5D2A63742BAE319BBD61BE78910E8D4D13D"
CONFIG_FILE="/etc/grub.d/01_users"

# Create the script that will be executed by update-grub.
sudo tee "${CONFIG_FILE}" >/dev/null <<EOF
#!/bin/sh
# This script prints the superuser configuration for GRUB.
cat << GRUB_CONFIG_EOF
set superusers="${GRUB_USER}"
password_pbkdf2 ${GRUB_USER} ${GRUB_HASH}
GRUB_CONFIG_EOF
EOF

# Make the new configuration script executable.
sudo chmod +x "${CONFIG_FILE}"

# Mark standard boot entries as unrestricted to allow passwordless booting.
echo "--- Marking standard boot entries as unrestricted ---"
sudo sed -i "s/CLASS=\"--class gnu-linux --class gnu --class os\"/CLASS=\"--class gnu-linux --class gnu --class os --unrestricted\"/" /etc/grub.d/10_linux

# Update the main GRUB configuration to apply all changes.
echo "--- Updating GRUB configuration ---"
sudo update-grub

echo "--- GRUB password successfully set to protect edit functions only ---"
