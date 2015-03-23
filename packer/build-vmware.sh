#!/bin/bash -e

WORKDIR=${0%/*}
SSHKEYFILE="$1"

if [ -z "$SSHKEYFILE" -o ! -f "$SSHKEYFILE" ] ; then
	echo "Please supply the path to the required SSH private key file on the command line."
	exit 1
fi

echo directory part: "$WORKDIR"
echo SSH key file: "$SSHKEYFILE"

# Run packer to create the VM
pushd "$WORKDIR" > /dev/null
packer build \
	-var "http_directory=." \
	-var "ssh_key_path=$SSHKEYFILE" \
    -only teamwire-server-vmware \
	"teamwire-server.json"
popd > /dev/null

# Convert the VM and create a compressed archive of the result
pushd "$WORKDIR"/output-teamwire-server-vmware > /dev/null
ovftool teamwire-server.vmx teamwire-server.ovf
rm disk-s0* disk.vmdk teamwire-server.vmx
tar cfjv ../teamwire-server-vmware.tar.bz2  *
popd > /dev/null

# Remove build artefacts
rm -rf "$WORKDIR"/output-teamwire-server-vmware
