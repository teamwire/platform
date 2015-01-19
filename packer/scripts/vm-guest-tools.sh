#!/bin/bash -e

if [[ $PACKER_BUILDER_TYPE =~ vmware ]]; then
	echo "Installing VMware Tools"

	# We need a subdirectory below /mnt as vmware-install tries to create
	# /mnt/hgfs and will not build the filesystem driver (vmhgfs) if that fails.
	sudo mkdir /mnt/cdrom
	sudo mount -o loop /home/vagrant/linux.iso /mnt/cdrom
	tar zxf /mnt/cdrom/VMwareTools-*.tar.gz -C /tmp/

	sudo /tmp/vmware-tools-distrib/vmware-install.pl -d

	sudo umount /mnt/cdrom
	sudo rmdir /mnt/cdrom
	rm /home/vagrant/linux.iso
	rm -rf /tmp/vmware-tools-distrib

	# Enable VMWare kernel module updates after kernel updates
	sudo sed -i -e 's/^\(answer AUTO_KMODS_ENABLED\) no/\1 yes/' /etc/vmware-tools/locations
fi