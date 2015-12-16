# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "teamwire/server"

  # The ssh user name used to connect to the created VM with "vagrant ssh"
  config.ssh.username = "teamwire"

  # Path to the ssh key for that user
  config.ssh.private_key_path = File.expand_path("~/.ssh/teamwire-server-vm-admin")

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  config.vm.box_check_update = false

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network. Set the MAC address to get the same IP address from DHCP.
  config.vm.network "public_network", :mac => "000c29594f39"

  # Disable the default shared folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider :vmware_fusion do |v|
    # Enable nested virtualisation
    v.vmx["vhv.enable"] = "TRUE"
    v.vmx["memsize"] = "1024"
  end

  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
  end

  # Enable provisioning with Ansible.
  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/site.yml"
    ansible.sudo = true
    # ansible.verbose = 'vvv'
  end
end
