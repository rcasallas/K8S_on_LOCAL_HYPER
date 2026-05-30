#!/bin/bash
# Script to start a new Load Balancer VM
# Parses variables directly from CONFIG.mk
# DEVELOPER: RICHARD CASALLAS
# DATE: 2026-04-23
set -e

# Ruta al archivo de configuración
CONFIG_FILE="CONFIG.mk"

# ------------------------------------------------------------------
# Función para cargar el archivo de configuración de forma segura
# ------------------------------------------------------------------
load_config() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: El archivo de configuración '$file' no existe." >&2
        exit 1
    fi

    echo "Cargando configuraciones desde: $file..."
    
    # Lee el archivo línea por línea
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 1. Ignorar líneas vacías
        [[ -z "$line" ]] && continue
        # 2. Ignorar líneas que comienzan con # (comentarios)
        [[ "$line" =~ ^# ]] && continue
        
        # 3. Validar que la línea tenga el formato CLAVE=VALOR o CLAVE := VALOR
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:?=[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            val="${BASH_REMATCH[2]}"
            # Remover comillas dobles si existen alrededor del valor
            val="${val%\"}"
            val="${val#\"}"
            export "$key=$val"
        else
            echo "Advertencia: Línea ignorada por formato inválido -> $line" >&2
        fi
    done < "$file"
}

# Ejecutar la función de carga
load_config "$CONFIG_FILE"

usage() {
    echo "startLB.sh --nameVM lb-haproxy-01 --role primary --IPAddressVM 192.168.56.100 --maskVM 24 --gatewayVM 192.168.56.1 --dnsVM 8.8.8.8 --dnsRelay 8.8.8.8;4.4.4.4 --keepalivedPriority 10"
    echo "Usage: startLB.sh [options]"
    echo ""
    echo "Options:"
    echo "  -n, --nameVM                   Name of the VM"
    echo "  -r, --role                     Role (e.g., primary, secondary)"
    echo "  -i, --IPAddressVM               VM IP Address"
    echo "  -m, --maskVM                   Subnet Mask"
    echo "  -g, --gatewayVM                Gateway IP"
    echo "  -d, --dnsVM                    DNS Server"
    echo "  -D, --dnsRelay                 DNS Relay"
    echo "  -P, --keepalivedPriority       Keepalived Priority"
    echo "  -h, --help                     Show this help"
    echo ""
    echo "Note: Global configuration (OVA path, ports, VIPs, etc.) is automatically loaded from CONFIG.mk"
    echo ""
}



function ayuda(){
	echo "${USO}"
	if [[ ${1} ]]
	then
		echo ${1}
	fi
}

function createLB(){

    # 1. Definición de variables mapeadas desde globals de getopt
    nameVM=$NAME_VM
    role=$ROLE
    prefixButaneIgnitionName=${PREFIX_IGNITION:-"preconfig"}
    IPAddressVM=$IP_VM
    maskVM=$MASK_VM
    gatewayVM=$GW_VM
    dnsVM=$DNS_VM
    dnsRelay=$DNS_RELAY
    prefixLB=${PREFIX_LB:-"k8s.local"}
    keepalivedPriority=$KEEPALIVED_PRIO
    keepalivedNic=${KEEPALIVED_NIC:-"enp0s8"}
    httpProtocolIgnition=$HTTP_PROTO_IGNITION
    IPAddressHttpIgnition=$HTTP_IP_IGNITION
    httpPortIgnition=$HTTP_PORT_IGNITION
    OVA_FILE=$OVA_FILE
    vip_lb=$ENDPOINT_IP
    KEEPALIVED_PASS=$HTTP_PASSWORD_IGNITION
    configK8S=$CONFIG_K8S
    AUTHORIZATION_USER=$HTTP_USER_IGNITION
    AUTHORIZATION_PASSWORD=$HTTP_PASSWORD_IGNITION
    HTTP_PROTO_CA=$HTTP_PROTO_CA
    HTTP_PORT_CA=$HTTP_PORT_CA

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: $CONFIG_FILE not found en el directorio actual."
        exit 1
    fi

    echo "Leyendo variables desde $CONFIG_FILE..."
    HOSTNAME_LB="$nameVM"
    LB_IP="$IPAddressVM"
    MASK_LB="$maskVM"
    # Default a gateway si es necesario:
    GATEWAY_LB="$gatewayVM"
    HTTP_IP_IGNITION="$IPAddressHttpIgnition"
    HTTP_PORT_IGNITION="$httpPortIgnition"
    HTTP_PROTO_IGNITION="$httpProtocolIgnition"

    if [ -z "$HOSTNAME_LB" ] || [ -z "$LB_IP" ] || [ -z "$MASK_LB" ]; then
        echo "Error crítico: HOSTNAME_LB, LB_IP o MASK_LB no están definidos correctamente en $CONFIG_FILE."
        exit 1
    fi

    ENDPOINT_IP=$(grep -E '^ENDPOINT_IP' "$CONFIG_FILE" | awk -F'"' '{print $2}')
    export ENDPOINT_IP

    # Parsing the dynamically configured MASTER nodes for HA-Proxy backend (from CONFIG.mk)
    MASTER_IP_RAW=$(grep -E '^MASTER_IP' "$CONFIG_FILE" | awk -F'"' '{print $2}')
    HOSTNAME_MASTER_RAW=$(grep -E '^HOSTNAME_MASTER' "$CONFIG_FILE" | awk -F'"' '{print $2}')
    read -ra MASTER_IPS <<< "$MASTER_IP_RAW"
    read -ra HOSTNAME_MASTERS <<< "$HOSTNAME_MASTER_RAW"

    HAPROXY_BACKEND_SERVERS=""
    DNS_MASTER_RECORDS=""
    for i in "${!MASTER_IPS[@]}"; do
        HAPROXY_BACKEND_SERVERS+="              server ${HOSTNAME_MASTERS[$i]} ${MASTER_IPS[$i]}:6443 check"$'\n'
        DNS_MASTER_RECORDS+="          ${HOSTNAME_MASTERS[$i]} IN A ${MASTER_IPS[$i]}"$'\n'
    done
    export HAPROXY_BACKEND_SERVERS="${HAPROXY_BACKEND_SERVERS%$'\n'}"
    export DNS_MASTER_RECORDS="${DNS_MASTER_RECORDS%$'\n'}"

    # Parsing the dynamically configured WORKER nodes (from CONFIG.mk)
    WORKER_IP_RAW=$(grep -E '^WORKER_IP' "$CONFIG_FILE" | awk -F'"' '{print $2}')
    HOSTNAME_WORKER_RAW=$(grep -E '^HOSTNAME_WORKER' "$CONFIG_FILE" | awk -F'"' '{print $2}')
    read -ra WORKER_IPS <<< "$WORKER_IP_RAW"
    read -ra HOSTNAME_WORKERS <<< "$HOSTNAME_WORKER_RAW"

    DNS_WORKER_RECORDS=""
    for i in "${!WORKER_IPS[@]}"; do
        DNS_WORKER_RECORDS+="          ${HOSTNAME_WORKERS[$i]} IN A ${WORKER_IPS[$i]}"$'\n'
    done
    export DNS_WORKER_RECORDS="${DNS_WORKER_RECORDS%$'\n'}"

    nameVM="$HOSTNAME_LB"
    #OVA_FILE="noble-server-cloudimg-amd64.ova"
    OVA_PATH=$(realpath ../../OVA)
    LOG_FILE="LOGS_LB.log"
    ERROR_FILE="ERRORS_LB.log"

    echo "======================================"
    echo "Iniciando despliegue de Load Balancer"
    echo "VM Name: $nameVM"
    echo "IP: $LB_IP/$MASK_LB"
    echo "OVA: $OVA_FILE"
    echo "======================================"

    # === 2. IMPORT THE VM ===
    echo "Importing VM... $nameVM"
    if vboxmanage list vms | grep -iq "\"$nameVM\""; then
        echo "La VM '$nameVM' ya existe. Intente eliminarla primero con VBoxManage."
        exit 4
    fi

    if ! VBoxManage import "$OVA_PATH/$OVA_FILE" --vsys 0 --vmname "$nameVM" 2>> "$ERROR_FILE" >> "$LOG_FILE"; then
        echo "Error crítico: Revisa los logs $ERROR_FILE -> IMPORTING_VM"
        exit 1
    else
        echo "VM importada correctamente"
    fi

    # === 2.5 CONFIGURE SERIAL CONSOLE LOGGING ===
    echo "Configurando logging de consola serial..."
    mkdir -p LOGS
    VM_LOG_FILE="$(pwd)/LOGS/${nameVM}_console.log"
    VBoxManage modifyvm "$nameVM" --uart1 0x3F8 4 2>> "$ERROR_FILE"
    sleep 2
    VBoxManage modifyvm "$nameVM" --uartmode1 file "$VM_LOG_FILE" 2>> "$ERROR_FILE"
    sleep 2

    # === 3. CONFIGURE NETWORK ===
    echo "Configuring Network Interfaces..."
    # NIC1: Red Externa (Bridged o la red que utilices por defecto)
    if ! VBoxManage modifyvm "$nameVM" --nic1 bridged --bridgeadapter1 eno1 2>> "$ERROR_FILE"; then
        echo "Error crítico: Falló configuración NIC1"
        exit 1
    fi
    sleep 2

    # NIC2: Red Interna host-only (para comunicarse con los workers/masters)
    if ! VBoxManage modifyvm "$nameVM" --nic2 hostonly --hostonlyadapter2 vboxnet0 2>> "$ERROR_FILE"; then
        echo "Error crítico: Falló configuración NIC2"
        exit 1
    fi
    echo "Redes configuradas correctamente"
    sleep 2

    # === 4. GENERATE IGNITION FILES ===
    provisioningPath=$(realpath ../../provisioning)
    dynamicPath=$(realpath ../../dynamic)
    rootPath=$(realpath ../../)

    INIT_TEMPLATE_FILE="$provisioningPath/InitVM.bu.template"
    CONFIG_TEMPLATE_FILE="$provisioningPath/ConfigFile_LB.FCOS.bu.template"

    INIT_BUTANE_FILE_FULL="$dynamicPath/INIT_${nameVM}.bu"
    INIT_IGNITION_FILE_FULL="$dynamicPath/INIT_${nameVM}.ign"

    CONFIG_BUTANE_FILE_FULL="$dynamicPath/preconfig_${nameVM}.bu"
    CONFIG_IGNITION_FILE_FULL="$dynamicPath/preconfig_${nameVM}.ign"

    # Set environment variables for InitVM.bu.template 
    export IP_ADDRESS_HTTP_IGNITION=$HTTP_IP_IGNITION
    export PORT_HTTP_IGNITION=$HTTP_PORT_IGNITION
    export PROTO_HTTP_IGNITION=$HTTP_PROTO_IGNITION
    export CONFIG_IGNITION_FILENAME="preconfig_${nameVM}.ign"
    export AUTHORIZATION_TOKEN="Basic $(echo -n "${AUTHORIZATION_USER}:${AUTHORIZATION_PASSWORD}" | base64 -w 0)"
    export HTTP_PROTO_CA=$HTTP_PROTO_CA
    export HTTP_PORT_CA=$HTTP_PORT_CA
    
    # NUEVO: Leer CA y calcular su hash para el archivo YAML
    export CA_CERT_HASH="sha512-$(sha512sum /home/rcasallas/Documents/devops/webserverConfig/mtls_portal/certs/ca.crt | awk '{print $1}')"


    echo "Generando archivo INIT Ignition..."
    envsubst < "$INIT_TEMPLATE_FILE" > "$INIT_BUTANE_FILE_FULL"
    if ! butane --pretty  < "$INIT_BUTANE_FILE_FULL" -d "$rootPath" > "$INIT_IGNITION_FILE_FULL"; then
        echo "Error crítico: Falló compilación de INIT Butane -> Ignition"
        exit 1
    fi
    # upload INIT FILES to mtls_portal_app server
    echo "Uploading INIT Ignition file to mtls_portal_app server..."
    echo "Authorization User: ${AUTHORIZATION_USER}"
    echo "Authorization Password: ${AUTHORIZATION_PASSWORD}"
    echo "HTTP IP Ignition: ${HTTP_IP_IGNITION}"
    echo "HTTP Port Ignition: ${HTTP_PORT_IGNITION}"
    echo "HTTP Protocol Ignition: ${HTTP_PROTO_IGNITION}"
    echo "CONFIG_IGNITION_FILENAME: ${CONFIG_IGNITION_FILENAME}"
    echo "AUTHORIZATION_TOKEN: ${AUTHORIZATION_TOKEN}"
    HTTP_STATUS=$(curl --silent --show-error --write-out "%{http_code}" --max-time 10 -k -u "${AUTHORIZATION_USER}:${AUTHORIZATION_PASSWORD}" -X PUT "https://${HTTP_IP_IGNITION}:${HTTP_PORT_IGNITION}/api/ignition/config/INIT_${nameVM}.ign" -H "Content-Type: application/json" -d @"$INIT_IGNITION_FILE_FULL" -o /tmp/upload_ignition_response_${nameVM}.txt)
    if [[ "$HTTP_STATUS" -lt 200 || "$HTTP_STATUS" -ge 300 ]]; then
        echo "Error crítico: Falló la subida del archivo INIT Ignition. Código HTTP: $HTTP_STATUS"
        echo "Respuesta del servidor:"
        cat /tmp/upload_ignition_response_${nameVM}.txt
        rm -f /tmp/upload_ignition_response_${nameVM}.txt
        exit 1
    fi
    echo "Archivo INIT Ignition subido correctamente al servidor. (HTTP $HTTP_STATUS)"
    rm -f /tmp/upload_ignition_response_${nameVM}.txt
    export HOSTNAME_LB=$nameVM
    export IPAddressVM=$IPAddressVM
    export maskVM=$maskVM
    export gatewayVM=$gatewayVM
    export dnsVM=$dnsVM
    export dnsRelay=$dnsRelay
    export prefixLB=$prefixLB
    export keepalivedPriority=$keepalivedPriority
    export keepalivedNic=$keepalivedNic
    export httpProtocolIgnition=$httpProtocolIgnition
    export IPAddressHttpIgnition=$IPAddressHttpIgnition
    export httpPortIgnition=$httpPortIgnition
    export OVA_FILE=$OVA_FILE
    export vip_lb=$vip_lb
    export KEEPALIVED_PASS=$KEEPALIVED_PASS
    export configK8S=$configK8S
    export DOLLAR="$"


    
    echo "Generando archivo CONFIG Ignition principal..."
    envsubst < "$CONFIG_TEMPLATE_FILE" > "$CONFIG_BUTANE_FILE_FULL"
    if ! butane --pretty  < "$CONFIG_BUTANE_FILE_FULL" -d "$rootPath" > "$CONFIG_IGNITION_FILE_FULL"; then
        echo "Error crítico: Falló compilación de CONFIG Butane -> Ignition"
        exit 1
    fi

    echo "Uploading CONFIG Ignition file to mtls_portal_app server..."
    HTTP_STATUS_CONFIG=$(curl --silent --show-error --write-out "%{http_code}" --max-time 10 -k -u "${AUTHORIZATION_USER}:${AUTHORIZATION_PASSWORD}" -X PUT "https://${HTTP_IP_IGNITION}:${HTTP_PORT_IGNITION}/api/ignition/config/${CONFIG_IGNITION_FILENAME}" -H "Content-Type: application/json" -d @"$CONFIG_IGNITION_FILE_FULL" -o /tmp/upload_config_ignition_response_${nameVM}.txt)
    if [[ "$HTTP_STATUS_CONFIG" -lt 200 || "$HTTP_STATUS_CONFIG" -ge 300 ]]; then
        echo "Error crítico: Falló la subida del archivo CONFIG Ignition. Código HTTP: $HTTP_STATUS_CONFIG"
        echo "Respuesta del servidor:"
        cat /tmp/upload_config_ignition_response_${nameVM}.txt
        rm -f /tmp/upload_config_ignition_response_${nameVM}.txt
        exit 1
    fi
    echo "Archivo CONFIG Ignition subido correctamente al servidor. (HTTP $HTTP_STATUS_CONFIG)"
    rm -f /tmp/upload_config_ignition_response_${nameVM}.txt

    echo "Minifying INIT Ignition file..."
    if ! IGN_MINIFIED=$(jq -c . "$INIT_IGNITION_FILE_FULL" 2>> "$ERROR_FILE"); then
        echo "Error crítico: jq falló al minificar el JSON"
        exit 1
    fi

    # === 5. CONFIGURE VM STORAGE CONTROLLER AND IGNITION GUEST PROPERTY ===
    # Note: Ubuntu will NOT read this property natively to self-configure config unless
    # it is bundled with Ignition. Set it anyway matching FCOS structure as requested.
    echo "Inyectando INIT Ignition Payload..."
    if ! VBoxManage guestproperty set "$nameVM" /Ignition/Config "$IGN_MINIFIED" 2>> "$ERROR_FILE"; then
        echo "Error crítico: Falló inyección Ignition vía GuestProperties"
        exit 1
    fi
    sleep 2

    # === 6. START VM ===
    echo "Arrancando VM de Load Balancer..."
    if ! VBoxManage startvm "$nameVM" --type headless 2>> "$ERROR_FILE" >> "$LOG_FILE"; then
        echo "Error crítico: La VM falló al iniciar"
        exit 1
    else
        echo "VM '$nameVM' iniciada exitosamente."
    fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--nameVM)                  NAME_VM="$2"; shift 2 ;;
    -r|--role)                    ROLE="$2"; shift 2 ;;
    -i|--IPAddressVM)              IP_VM="$2"; shift 2 ;;
    -m|--maskVM)                  MASK_VM="$2"; shift 2 ;;
    -g|--gatewayVM)               GW_VM="$2"; shift 2 ;;
    -d|--dnsVM)                   DNS_VM="$2"; shift 2 ;;
    -D|--dnsRelay)                DNS_RELAY="$2"; shift 2 ;;
    -P|--keepalivedPriority)      KEEPALIVED_PRIO="$2"; shift 2 ;;
    -h|--help)                    usage; ayuda; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;       
  esac
done

if [ -z "$NAME_VM" ]; then
    echo "Error: --nameVM is required"
    usage
    exit 1
fi

createLB
