Vagrant.configure("2") do |config|
  # Usar la caja de Fedora CoreOS
  config.vm.box = "mihailutasu/fedora-coreos-next"

  # IP de red privada base
  PRIVATE_NETWORK_IP_BASE = "192.168.56."

  # Definir 3 VMs
  (1..3).each do |i|
    config.vm.define "vm#{i}" do |vm|
      # Configurar el hostname para cada VM
      vm.vm.hostname = "vm#{i}"

      # Configurar red privada para comunivirtcación entre nodos
      vm.vm.network "private_network", ip: "#{PRIVATE_NETWORK_IP_BASE}1#{i}"

      # Configurar el proveedor VirtualBox
      vm.vm.provider "virtualbox" do |vb|
        # Asignar 4 GB de RAM
        vb.memory = 4096
        # Asignar 2 VCPUs
        vb.cpus = 2
        # Nombre de la VM en VirtualBox
        vb.name = "Fedora-CoreOS-VM#{i}"
      end

      # Sincronizar la carpeta de scripts para que las VMs puedan ejecutarlos
      vm.vm.synced_folder "scripts/", "/vagrant/scripts"

      # Aprovisionamiento para instalar Kubernetes
      if i == 1
        # vm1 es el Master Node
        vm.vm.provision "shell", path: "scripts/master.sh"
      else
        # vm2 y vm3 son Worker Nodes
        vm.vm.provision "shell", path: "scripts/worker.sh"
      end
    end
  end
end