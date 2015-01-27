Building a VM image or Vagrant box with packer
==============================================

Packer can create images and Vagrant boxes for various Hypervisors.
The table below shows the names of the various configuration.

Hypervisor   | Vagrant Box                        | packed image
-------------|------------------------------------|---------------------------------
VMWare       | teamwire-server-vmware-vagrant     | teamwire-server-vmware
qemu/libvirt | teamwire-server-kvm-vagrant        | teamwire-server-kvm
VirtualBox   | teamwire-server-virtualbox-vagrant |

Change to this directory, choose the desired CONFIGURATION and run

```sh
packer build -var "http_directory=$PWD" -only <CONFIGURATION> teamwire-server.json
```

to build the desired virtual machine.
