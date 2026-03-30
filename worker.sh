#!/bin/bash

set -euo pipefail

# Ejecutar configuración común
/vagrant/scripts/common.sh

echo "### Ejecutando script de configuración del worker (worker.sh)... ###"

# Unirse al clúster
echo "[WORKER] Uniéndose al clúster de Kubernetes"
# Esperar a que el script de unión esté disponible
while [ ! -f /vagrant/join.sh ]; do
  echo "[WORKER] Esperando a que el master cree el script de unión..."
  sleep 5
done

sudo bash /vagrant/join.sh

echo "### Script de configuración del worker finalizado. ###"