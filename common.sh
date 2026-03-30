#!/bin/bash

set -euo pipefail

echo "### Ejecutando script de configuración común (common.sh)... ###"

# Deshabilitar servicios que pueden interferir
echo "[COMMON] Deshabilitando firewall y Zincati (servicio de auto-actualización)"
sudo systemctl disable --now firewalld zincati.service

# Configurar módulos del kernel y sysctl para Kubernetes
echo "[COMMON] Configurando módulos del kernel y sysctl"
sudo tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# Configurar CRI-O (Container Runtime Interface)
echo "[COMMON] Configurando CRI-O"
sudo mkdir -p /etc/crio/crio.conf.d/
sudo tee /etc/crio/crio.conf.d/01-k8s.conf > /dev/null <<EOF
[crio.runtime]
conmon_cgroup = "pod"
cgroup_manager = "cgroupfs"
[crio.network]
network_dir = "/etc/cni/net.d/"
plugin_dirs = [
  "/opt/cni/bin/",
]
EOF
sudo systemctl restart crio

# Instalar binarios de K8s
K8S_VERSION="1.29.3"
DOWNLOAD_DIR="/opt/k8s-downloads"
BIN_DIR="/usr/local/bin"

echo "[COMMON] Instalando CNI plugins, crictl, kubelet, kubeadm, kubectl"
sudo mkdir -p /opt/cni/bin "${DOWNLOAD_DIR}" "${BIN_DIR}" /etc/systemd/system/kubelet.service.d

# CNI Plugins
CNI_PLUGINS_VERSION="v1.4.0"
sudo curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C /opt/cni/bin -xz

# crictl
CRICTL_VERSION="v1.29.0"
sudo curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-amd64.tar.gz" | sudo tar -C "${BIN_DIR}" -xz

# kubeadm, kubelet, kubectl
cd "${DOWNLOAD_DIR}"
sudo curl -L --remote-name-all https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
sudo chmod +x kubeadm kubelet kubectl
sudo mv kubeadm kubelet kubectl "${BIN_DIR}/"
cd /

# Configurar el servicio kubelet
sudo curl -L "https://raw.githubusercontent.com/kubernetes/release/master/cmd/kubenode/kubelet-service.sh" | sudo bash -s -- --version "v${K8S_VERSION}"
sudo tee /etc/systemd/system/kubelet.service.d/20-crio.conf > /dev/null <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///var/run/crio/crio.sock"
EOF

echo "[COMMON] Habilitando y arrancando crio y kubelet"
sudo systemctl daemon-reload
sudo systemctl enable --now crio kubelet

echo "### Script de configuración común finalizado. ###"