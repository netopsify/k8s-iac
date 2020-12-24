IMAGE_NAME = "bento/ubuntu-20.04"
N = 2

Vagrant.configure("2") do |config|
    config.ssh.insert_key = false

    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
        v.cpus = 2
    end

    config.vm.define "testvm" do |testvm|
        testvm.vm.box = "generic/alpine312"
        testvm.vm.network "private_network", ip: "192.168.150.253", virtualbox__intnet: "intnet-3"
        testvm.vm.hostname = "testvm"
        testvm.vm.provision "shell", inline: $test_vm_build_script
    end

    config.vm.define "master" do |master|
        master.vm.box = IMAGE_NAME
        master.vm.network "private_network", ip: "192.168.50.10"
        master.vm.hostname = "master"
        master.vm.provision "ansible" do |ansible|
            ansible.playbook = "setup/master-playbook.yml"
            ansible.extra_vars = {
                node_ip: "192.168.50.10",
            }
        end
    end

    (1..N).each do |i|
        config.vm.define "worker#{i}" do |node|
            node.vm.box = IMAGE_NAME
            node.vm.network "private_network", ip: "192.168.50.#{i + 10}"
            node.vm.hostname = "worker#{i}"
            # Only execute once the Ansible provisioner,
            # when all the machines are up and ready.
            # if i == N
            node.vm.provision "ansible" do |ansible|
                # ansible.limit = "all"
                ansible.playbook = "setup/node-playbook.yml"
                ansible.extra_vars = {
                    node_ip: "192.168.50.#{i + 10}",
                }
                # end
            end
        end
    end
    ##### DEFINE VM for tor #####
    config.vm.define "tor" do |tor|
        tor.vm.box = "CumulusCommunity/cumulus-vx"
        # Internal network for swp* interfaces.
        tor.vm.network "private_network", ip: "192.168.50.250", auto_config: false
        tor.vm.network "private_network", virtualbox__intnet: "intnet-3", auto_config: false
        tor.vm.network "private_network", ip: "192.168.50.251", auto_config: false
        # tor.vm.network "private_network", virtualbox__intnet: "intnet-4", auto_config: false
        tor.vm.provision "shell", inline: $script
        tor.vm.provider "virtualbox" do |vbox|
            # vbox.customize ['modifyvm', :id, '--nicpromisc2', 'allow-vms']
            vbox.customize ['modifyvm', :id, '--nicpromisc3', 'allow-vms']
            vbox.customize ['modifyvm', :id, '--nicpromisc4', 'allow-vms']
        end    
    end
end

$script = <<-'SCRIPT'
sudo usermod -a -G netedit vagrant
net add hostname tor
net add interface swp1 ip address 192.168.50.250/24
net add interface swp2 ip address 192.168.150.254/24
net add interface swp3 ip address 192.168.50.251/24
# Configure bgp
net add bgp autonomous-system 65101
net add bgp router-id 192.168.50.250
net add bgp neighbor 192.168.50.10 remote-as 64512
net add bgp neighbor 192.168.50.11 remote-as 64512
net add bgp neighbor 192.168.50.12 remote-as 64512
net add bgp ipv4 unicast network 192.168.150.0/24

net add vrf metallb
net add bgp vrf metallb autonomous-system 65102
net add bgp vrf metallb router-id 192.168.50.251
net add bgp vrf metallb neighbor 192.168.50.10 remote-as 65000
net add bgp vrf metallb neighbor 192.168.50.11 remote-as 65000
net add bgp vrf metallb neighbor 192.168.50.12 remote-as 65000
net add bgp ipv4 unicast import vrf metallb
net add interface swp2 vrf metallb
net add interface swp3 vrf metallb
net pending
net commit
sudo ifdown swp1
sudo ifup swp1
sudo ifdown swp2
sudo ifup swp2
sudo ifdown swp3
sudo ifup swp3
SCRIPT

$test_vm_build_script = <<-'SCRIPT'
sudo apk update
sudo apk add --no-cache unzip bc jq arping curl wget
SCRIPT