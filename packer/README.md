Building a VMWare image with packer
===================================

Change to this directory and run

```sh
packer build -var "http_directory=$PWD" -only vmware-teamwire-server teamwire-server.json
```

Building a KVM image with packer
================================
Change to this directory and run

```sh
packer build -var "http_directory=$PWD" -only kvm-teamwire-server teamwire-server.json
```
