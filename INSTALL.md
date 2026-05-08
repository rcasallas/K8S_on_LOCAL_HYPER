# 1. Create the private and public Key.

generate the private/public key for the access 
ssh-keygen -f ./keys/myKeys -t ed25519 -C "devopsadmin@lla.com" -N ""

# 2. Download de OVA FILES.

Download the virtualbox OVA File.

curl -LO $(curl -s https://builds.coreos.fedoraproject.org/streams/stable.json | jq -r '.architectures.x86_64.artifacts.virtualbox.formats.ova.disk.location')
curl -LO $(curl -s https://builds.coreos.fedoraproject.org/streams/stable.json | jq -r '.architectures.x86_64.artifacts.vmware.formats.ova.disk.location')

wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.ova

or

python3 getOVA_FCOS.py

# 3. Convert butane File to Ignition File.
this convert the butane file to ignition File.

butane --pretty --strict butanefileInitMaster.yaml -d . > butanefileInitMaster.ign
butane --pretty --strict butanefileMaster1.yaml -d . > butanefileMaster1.ign

# 2. Importar la OVA oficial de FCOS
VBoxManage import fedora-coreos-43.20260316.3.1-virtualbox.x86_64.ova --vsys 0 --vmname "fcos-master-01"
VBoxManage modifyvm "fcos-master-01" --nic1 bridged --bridgeadapter1 eno1

VBoxManage createmedium disk --filename "/home/rcasallas/VirtualBox\ VMs/fcos-master-01/K8S_DATA.vdi" --size 51250 --format VDI
VBoxManage storagectl "fcos-master-01" --name "SATA_Controller" --add sata --controller IntelAhci

VBoxManage storageattach "fcos-master-01" --storagectl "SATA_Controller" --port 1 --device 0 --type hdd --medium "/home/rcasallas/VirtualBox\ VMs/fcos-master-01/K8S_DATA.vdi"

VBoxManage showvminfo "fcos-master-01" | grep "SATA_Controller"

# 3. Inyectar el archivo Ignition (El paso clave)
# Esto evita tener que montar ISOs de configuración o servidores HTTP
VBoxManage guestproperty set "fcos-master-01" /Ignition/Config "$(cat butanefileInitMaster.ign)"

# 4. Iniciar la máquina
VBoxManage startvm "fcos-master-01" 
VBoxManage controlvm "fcos-master-01" poweroff
vboxmanage list vms
vboxmanage unregistervm "fcos-master-01" --delete
VBoxManage closemedium disk "/home/rcasallas/VirtualBox\ VMs/fcos-master-01/K8S_DATA.vdi" --delete
VBoxManage closemedium disk "/home/rcasallas/VirtualBox\ VMs/fcos-master-01/disk.vdi" --delete