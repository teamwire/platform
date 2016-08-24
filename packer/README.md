Building a VM image or Vagrant box with packer
==============================================

Packer can create images and Vagrant boxes for various hypervisors.
The table below shows the names of the various configurations.

Hypervisor   | Vagrant Box                        | packed image
-------------|------------------------------------|---------------------------------
VMWare       | teamwire-server-vmware-vagrant     | teamwire-server-vmware
qemu/libvirt | teamwire-server-kvm-vagrant        | teamwire-server-kvm
VirtualBox   | teamwire-server-virtualbox-vagrant |

You'll need the password for the "teamwire" user.
Change to this directory, choose the desired CONFIGURATION and run

```sh
packer build \
	-var "http_directory=$PWD" \
	-var "ssh_password=PASSWORD" \
	-only <CONFIGURATION> \
	teamwire-server-debian.json
```

to build the desired virtual machine.

When building an image for offline installation, add the following parameters:

```
	-var "offline_installation=true" \
	-var "backend_release=<version tag>" \
	-var "dockerhub_password=<Docker Hub password>" \
	-var "dockerhub_username=<Docker Hub user name>" \
```


To build the VMWare packed image target, use the supplied script
`build-vmware.sh` - it converts the generated image to the OVF format
required for ESX Server.

Using the Vagrant Box
=====================

Copy the private key of the Teamwire administraive user to
`~/.ssh/teamwire-server-vm-admin` before starting the VM.

Use the following commands to make the .box file available for Vagrant and
create and start the virtual machine:

```sh
vagrant box add --name teamwire/server teamwire-server-vmware-vagrant.box
vagrant init teamwire/server
vagrant up
```

Connect to the Box with ```vagrant ssh```. Once ```vagrant box add```is
completed, you can delete the .box file.
