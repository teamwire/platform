#!/bin/bash -e

WORKDIR=${0%/*}
PASSWORD="$1"

if [ -z "$PASSWORD" ] ; then
	echo "Please supply the password for the teamwire user on the command line."
	exit 1
fi

if [ -f ../ansible/group_vars/all ] ; then
	echo "Please remove the Ansible config before building!"
	exit 1
fi

echo directory part: "$WORKDIR"

# Run packer to create the VM
pushd "$WORKDIR" > /dev/null
packer build \
	-var "http_directory=." \
	-var "ssh_password=$PASSWORD" \
    -only teamwire-server-vmware \
	"teamwire-server.json"
popd > /dev/null

# Convert the VM and create a compressed archive of the result
pushd "$WORKDIR"/output-teamwire-server-vmware > /dev/null
ovftool teamwire-server.vmx teamwire-server.ovf
rm disk-s0* disk.vmdk teamwire-server.vmx
# The order of files is significant, see the OVF spec: http://www.dmtf.org/sites/default/files/standards/documents/DSP0243_1.0.0.pdf
tar cfv ../teamwire-server.ova teamwire-server.ovf teamwire-server.mf teamwire-server-disk1.vmdk teamwire-server.nvram teamwire-server.vmsd teamwire-server.vmxf
popd > /dev/null

# Remove build artefacts
rm -rf "$WORKDIR"/output-teamwire-server-vmware
