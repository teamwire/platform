Building a VM image or Vagrant box with packer
==============================================

Packer can create images and Vagrant boxes for various hypervisors.
The table below shows the names of the various configurations.

Hypervisor   | Vagrant Box                        | packed image
-------------|------------------------------------|---------------------------------
VMWare       | teamwire-server-vmware-vagrant     | teamwire-server-vmware
qemu/libvirt | teamwire-server-kvm-vagrant        | teamwire-server-kvm
VirtualBox   | teamwire-server-virtualbox-vagrant |

You'll need the private and public key for the "teamwire" user.
Change to this directory, choose the desired CONFIGURATION and run

```sh
packer build -var "http_directory=$PWD" -var "ssh_key_path=/path/to/private/key" \
    -only <CONFIGURATION> teamwire-server.json
```

to build the desired virtual machine.
