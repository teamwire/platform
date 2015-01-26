Building a VMWare image with packer
===================================

Change to this directory and run

```sh
packer build -var "http_directory=$PWD" -only teamwire-server-vmware teamwire-server.json
```

or to build a Vagrant box for the VMWare provider

```sh
packer build -var "http_directory=$PWD" -only teamwire-server-vmware-vagrant teamwire-server.json
```

Building a KVM image with packer
================================
Change to this directory and run

```sh
packer build -var "http_directory=$PWD" -only teamwire-server-kvm teamwire-server.json
```

or to build a Vagrant box for the Libvirt provider

```sh
packer build -var "http_directory=$PWD" -only teamwire-server-kvm-vagrant teamwire-server.json
```
