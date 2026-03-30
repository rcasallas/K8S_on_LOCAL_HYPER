Vagrant.configure("2") do |config|
  # Usar la caja de Fedora CoreOS
  config.vm.box = "fedora/coreos"

  # Definir 3 VMs
  (1..3).each do |i|
    config.vm.define "vm#{i}" do |vm|
      # Configurar el hostname para cada VM
      vm.vm.hostname = "vm#{i}"

      # Configurar el proveedor VirtualBox
      vm.vm.provider "virtualbox" do |vb|
        # Asignar 4 GB de RAM
        vb.memory = 4096
        # Asignar 2 VCPUs
        vb.cpus = 2
        # Nombre de la VM en VirtualBox
        vb.name = "Fedora-CoreOS-VM#{i}"
      end
    end
  end
end