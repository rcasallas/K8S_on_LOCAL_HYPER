#!/bin/bash

set -euo pipefail

# Ejecutar configuración común
/vagrant/scripts/common.sh

echo "### Ejecutando script de configuración del master (master.sh)... ###"

# IP del nodo master
NODE_IP="192.168.56.11"

# Inicializar el clúster de Kubernetes
echo "[MASTER] Inicializando el clúster con kubeadm"
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=${NODE_IP}

# Configurar kubectl para el usuario 'core'
echo "[MASTER] Configurando kubectl para el usuario 'core'"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar el CNI (Container Network Interface) Cilium
echo "[MASTER] Instalando Cilium CLI"
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

echo "[MASTER] Instalando Cilium CNI"
cilium install

# Generar y guardar el comando para unir nodos worker
echo "[MASTER] Generando y guardando el comando de unión"
sudo kubeadm token create --print-join-command > /vagrant/join.sh
chmod +x /vagrant/join.sh

echo "### Script de configuración del master finalizado. ###"
echo "### El clúster está listo. Ya se pueden unir los nodos worker. ###"