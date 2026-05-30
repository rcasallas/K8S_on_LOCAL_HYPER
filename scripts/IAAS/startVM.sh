#!/bin/bash
# Script to start a new FedoraCoreOS VM
# Bash Script: VM Configuration
#devops engineer: Richard Casallas

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
    echo "startVM.sh --nameVM k8s-master-01 --role master --IPAddressVM 192.168.56.30 --maskVM 24 --gatewayVM 192.168.56.1 --dnsVM 192.168.56.100 --kubeadmToken TOKEN --certificateKey KEY --firstMaster k8s-master-01 --numMasters 3"
    echo "Usage: startVM.sh [options]"
    echo ""
    echo "Options:"
    echo "  -n, --nameVM                   Name of the VM"
    echo "  -r, --role                     Role (worker or master)"
    echo "  -i, --IPAddressVM               VM IP Address"
    echo "  -m, --maskVM                   Subnet Mask"
    echo "  -g, --gatewayVM                Gateway IP"
    echo "  -d, --dnsVM                    DNS Server"
    echo "  --kubeadmToken                 Kubeadm bootstrap token (Dynamic from makefile)"
    echo "  --certificateKey               Kubeadm certificate key (Dynamic from makefile)"
    echo "  --firstMaster                  Hostname of the first master node"
    echo "  --numMasters                   Total number of master nodes"
    echo "  -h, --help                     Show this help"
    echo ""
    echo "Note: Global configuration (OVA path, ports, endpoints, etc.) is automatically loaded from CONFIG.mk"
    echo ""
}




function ayuda(){
	echo "${USO}"
	if [[ ${1} ]]
	then
		echo ${1}
	fi
}

function pause(){
	read -s -n 1 -p "$*"
	echo ""
}


function CreateNode(){
 
    # 1. Definición de variables mapeadas desde globals de getopt y load_config
    nameVM=$NAME_VM
    role=$ROLE
    prefixButaneIgnitionName=${PREFIX_IGNITION:-"preconfig"}
    IPAddressVM=$IP_VM
    maskVM=$MASK_VM
    gatewayVM=$GW_VM
    dnsVM=$DNS_VM
    httpProtocolIgnition=$HTTP_PROTO_IGNITION
    IPAddressHttpIgnition=$HTTP_IP_IGNITION
    httpPortIgnition=$HTTP_PORT_IGNITION
    httpProtocolCA=$HTTP_PROTO_CA
    httpPortCA=$HTTP_PORT_CA

    AUTHORIZATION_USER=$HTTP_USER_IGNITION
    AUTHORIZATION_PASSWORD=$HTTP_PASSWORD_IGNITION

    # get the home directory of the user running the script
    homeDir=$(getent passwd $USER | cut -d: -f6)

    # get the path of the OVA file
    OVA_PATH=$(realpath ../../OVA/)
    
    #setting the init File names for BUTANE and IGNITION
    INIT_BUTANE_FILENAME="INIT_${prefixButaneIgnitionName}_${nameVM}.bu"
    INIT_IGNITION_FILENAME="INIT_${prefixButaneIgnitionName}_${nameVM}.ign"

    # setting the config FIle names for BUTANE and IGNITION
    CONFIG_BUTANE_FILENAME="${prefixButaneIgnitionName}_${nameVM}.bu"
    CONFIG_IGNITION_FILENAME="${prefixButaneIgnitionName}_${nameVM}.ign"

    # setting the paths for the VM in VirtualBox
    PATH_VM_VIRTUALBOX="${homeDir}/VirtualBox VMs/${nameVM}"

    
    # Setting the paths for the Disk files
    DISK_K8S="${PATH_VM_VIRTUALBOX}/K8S_DATA.vdi"
    DISK_OS="${PATH_VM_VIRTUALBOX}/OS_DATA.vdi"
    
    # setting the log files
    LOG_FILE="LOGS_VM.log"

    # setting the error log file
    ERROR_FILE="ERRORS_VM.log"

    # setting the IP and Port for the HTTP server to serve the ignition file
    IP_ADDRESS_HTTP_IGNITION=$IPAddressHttpIgnition
    PORT_HTTP_IGNITION=$httpPortIgnition
    HTTP_PROTO_IGNITION=$httpProtocolIgnition

    # 1. Import the VM and configure network
    echo "Importing VM...$nameVM"
    vboxmanage list vms | grep -i "$nameVM" 2> /dev/null > /dev/null

    if [[ $? -eq 0 ]]; then
        echo "La VM '$nameVM' ya existe. Intente eliminar utilizando make deleteVM $nameVM."
        exit 4
    else
        if ! VBoxManage import "$OVA_PATH/$OVA_FILE" --vsys 0 --vmname "$nameVM" 2>> "$ERROR_FILE" >> "$LOG_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> IMPORTING_VM"
            exit 1
        else
            echo "VM importada correctamente"
        fi

        if ! vboxmanage modifyvm "$nameVM" --chipset ich9 2>> "$ERROR_FILE" >> "$LOG_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> MODIFYING_VM_CHIPSET"
            exit 1
        else
            echo "VM configurada correctamente (CHIPSET)"
        fi

        if ! VBoxManage modifyvm "$nameVM" --nic1 bridged --bridgeadapter1 eno1 2>> "$ERROR_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> MODIFYING_VM_NIC1"
            exit 1
        else
            echo "VM configurada correctamente (NIC1)"
        fi
        sleep 2
        if ! VBoxManage modifyvm "$nameVM" --nic1 bridged --bridgeadapter1 eno1 2>> "$ERROR_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> MODIFYING_VM_NIC1"
            exit 1
        else
            echo "VM configurada correctamente (NIC1)"
        fi

        if ! VBoxManage modifyvm "$nameVM" --nic2 hostonly --hostonlyadapter2 vboxnet0 2>> "$ERROR_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> MODIFYING_VM_NIC2"
            exit 1
        else
            echo "VM configurada correctamente (NIC2)"
        fi
        sleep 2

        
    fi
     # === 2.5 CONFIGURE SERIAL CONSOLE LOGGING ===
    echo "Configurando logging de consola serial..."
    mkdir -p LOGS
    VM_LOG_FILE="$(pwd)/LOGS/${nameVM}_console.log"
    VBoxManage modifyvm "$nameVM" --uart1 0x3F8 4 2>> "$ERROR_FILE"
    sleep 2
    VBoxManage modifyvm "$nameVM" --uartmode1 file "$VM_LOG_FILE" 2>> "$ERROR_FILE"
    sleep 2


    #setting the root paths
    provisioningPath=$(realpath ../../provisioning)
    rootPath=$(realpath ../../)
    dynamicPath=$(realpath ../../dynamic)


    #################################################################
    # create the INIT Butane FIle:
    INIT_BUTANE_FILE_FULL="$dynamicPath/$INIT_BUTANE_FILENAME"
    INIT_IGNITION_FILE_FULL="$dynamicPath/$INIT_IGNITION_FILENAME"

    CONFIG_BUTANE_FILE_FULL="$dynamicPath/$CONFIG_BUTANE_FILENAME"
    CONFIG_IGNITION_FILE_FULL="$dynamicPath/$CONFIG_IGNITION_FILENAME"

    export IP_ADDRESS_HTTP_IGNITION=$IPAddressHttpIgnition
    export PORT_HTTP_IGNITION=$httpPortIgnition
    export PROTO_HTTP_IGNITION=$httpProtocolIgnition
    export CONFIG_IGNITION_FILENAME="$CONFIG_IGNITION_FILENAME"
    export AUTHORIZATION_TOKEN="Basic $(echo -n "${AUTHORIZATION_USER}:${AUTHORIZATION_PASSWORD}" | base64 -w 0)"
    export HTTP_PROTO_CA=$httpProtocolCA
    export HTTP_PORT_CA=$httpPortCA
    
    # NUEVO: Leer CA y calcular su hash para el archivo YAML
    export CA_CERT_HASH="sha512-$(sha512sum /home/rcasallas/Documents/devops/webserverConfig/mtls_portal/certs/ca.crt | awk '{print $1}')"

    # create the INIT Butane File
    envsubst < "$provisioningPath/InitVM.bu.template" > "$INIT_BUTANE_FILE_FULL"
    
    # create the Ignition Files for the init process.
    butane --pretty --strict < "$INIT_BUTANE_FILE_FULL" -d "$rootPath" > "$INIT_IGNITION_FILE_FULL"

    if [[ $? -ne 0 ]]; then
        echo "Error crítico: Revisa los logs $ERROR_FILE -> CREATING_IGNITION_FILE"
        exit 1
    else
        echo "Archivo de Ignition creado correctamente"
    fi 

    # upload INIT FILES to mtls_portal_app server
    echo "Uploading INIT Ignition file to mtls_portal_app server..."
    echo "Authorization User: ${AUTHORIZATION_USER}"
    echo "Authorization Password: ${AUTHORIZATION_PASSWORD}"
    echo "HTTP IP Ignition: ${IPAddressHttpIgnition}"
    echo "HTTP Port Ignition: ${httpPortIgnition}"
    echo "HTTP Protocol Ignition: ${httpProtocolIgnition}"
    echo "CONFIG_IGNITION_FILENAME: ${CONFIG_IGNITION_FILENAME}"
    echo "AUTHORIZATION_TOKEN: ${AUTHORIZATION_TOKEN}"
    HTTP_STATUS=$(curl --silent --show-error --write-out "%{http_code}" --max-time 10 -k -u "${AUTHORIZATION_USER}:${AUTHORIZATION_PASSWORD}" -X PUT "https://${IPAddressHttpIgnition}:${httpPortIgnition}/api/ignition/config/${INIT_IGNITION_FILENAME}" -H "Content-Type: application/json" -d @"$INIT_IGNITION_FILE_FULL" -o /tmp/upload_ignition_response_${nameVM}.txt)
    if [[ "$HTTP_STATUS" -lt 200 || "$HTTP_STATUS" -ge 300 ]]; then
        echo "Error crítico: Falló la subida del archivo INIT Ignition. Código HTTP: $HTTP_STATUS"
        echo "Respuesta del servidor:"
        cat /tmp/upload_ignition_response_${nameVM}.txt
        rm -f /tmp/upload_ignition_response_${nameVM}.txt
        exit 1
    fi
    echo "Archivo INIT Ignition subido correctamente al servidor. (HTTP $HTTP_STATUS)"
    rm -f /tmp/upload_ignition_response_${nameVM}.txt
    
    #################################################################
    # create the CONFIG Butane FIle:

    export K8S_VERSION="$K8S_VERSION"
    export K8S_HOSTNAME="$nameVM"
    export TYPE_NODE="$role"
    export IP_ADDRESS_VM="$IPAddressVM"
    export MASK_VM="$maskVM"
    export GATEWAY_VM="$gatewayVM"
    export DNS_VM="$dnsVM"
    export IP_ADDRESS_EXT="$IP_EXT"
    export MASK_EXT="$MASK_EXT"
    export GATEWAY_EXT="$GATEWAY_EXT"
    export DNS_EXT="$DNS_EXT"
    
    export ENDPOINT_IP="$ENDPOINT_IP"
    export ENDPOINT_HOST="$ENDPOINT_HOST"
    export ENDPOINT_PORT="$ENDPOINT_PORT"
    export PREFIX_MASTER="$PREFIX_MASTER"
    export SUBNET_POD="$SUBNET_POD"
    export SUBNET_SERVICE="$SUBNET_SERVICE"
    export KUBEADM_TOKEN="$KUBEADM_TOKEN"
    export CERTIFICATE_KEY="$CERTIFICATE_KEY"
    export FIRST_MASTER_HOSTNAME="$FIRST_MASTER_HOSTNAME"
    export CILIUM_VERSION="$CILIUM_VERSION"
    export NUM_MASTERS="$NUM_MASTERS"
    
    export INIT_IGNITION_FILE_FULL="$INIT_IGNITION_FILE_FULL"

    # Create the host File using the makefile in the current directory.
    make generate-hosts

    # create the config Butane File
    envsubst < "$provisioningPath/ConfigFile_Master.bu.template" > "$CONFIG_BUTANE_FILE_FULL"

    butane --pretty --strict < "$CONFIG_BUTANE_FILE_FULL" -d "$rootPath" > "$CONFIG_IGNITION_FILE_FULL"

    if [[ $? -ne 0 ]]; then
        echo "Error crítico: Revisa los logs $ERROR_FILE -> CREATING_IGNITION_FILE"
        exit 1
    else
        echo "Archivo de Ignition creado correctamente"
    fi 

    echo "Uploading CONFIG Ignition file to mtls_portal_app server..."
    HTTP_STATUS_CONFIG=$(curl --silent --show-error --write-out "%{http_code}" --max-time 10 -k -u "${AUTHORIZATION_USER}:${AUTHORIZATION_PASSWORD}" -X PUT "https://${IPAddressHttpIgnition}:${httpPortIgnition}/api/ignition/config/${CONFIG_IGNITION_FILENAME}" -H "Content-Type: application/json" -d @"$CONFIG_IGNITION_FILE_FULL" -o /tmp/upload_config_ignition_response_${nameVM}.txt)
    if [[ "$HTTP_STATUS_CONFIG" -lt 200 || "$HTTP_STATUS_CONFIG" -ge 300 ]]; then
        echo "Error crítico: Falló la subida del archivo CONFIG Ignition. Código HTTP: $HTTP_STATUS_CONFIG"
        echo "Respuesta del servidor:"
        cat /tmp/upload_config_ignition_response_${nameVM}.txt
        rm -f /tmp/upload_config_ignition_response_${nameVM}.txt
        exit 1
    fi
    echo "Archivo CONFIG Ignition subido correctamente al servidor. (HTTP $HTTP_STATUS_CONFIG)"
    rm -f /tmp/upload_config_ignition_response_${nameVM}.txt

    # setting Enviroment

    # 2. Minify the ignition file
    echo "Minifying Ignition file..."

    if ! IGN_MINIFIED=$(jq -c . "$INIT_IGNITION_FILE_FULL" 2>> "$ERROR_FILE"); then
        echo "Error crítico: Revisa los logs $ERROR_FILE -> MINIFYING_IGNITION"
        exit 1
    else
        echo "Ignition minificado correctamente"
    fi


    # 3. Setting the ignition config in the VM
    if ! VBoxManage guestproperty set "$nameVM" /Ignition/Config "$IGN_MINIFIED" 2>> "$ERROR_FILE"; then
        echo "Error crítico: Revisa los logs $ERROR_FILE -> INJECTING_IGNITION_FILE"
        exit 1
    else
        echo "Ignition Inyectado Correctamente"
    fi
    sleep 2

    # 4. Configure storage
    echo "Configuring storage..."
    if ! VBoxManage storagectl "$nameVM" --name "NVMe_Controller" --add pcie --controller NVMe 2>>"$ERROR_FILE"; then
        echo "Error crítico: Revisa los logs $ERROR_FILE -> ADDING_STORAGE_CONTROLLER"
        exit 3
    else
        echo "Controlador de almacenamiento añadido correctamente"
        
        # Mover el disco del OS (OVA) de AHCI al controlador NVMe
        VBoxManage storageattach "$nameVM" --storagectl "AHCI" --port 0 --device 0 --medium none 2>>"$ERROR_FILE" || true
        VBoxManage storageattach "$nameVM" --storagectl "NVMe_Controller" --port 0 --device 0 --type hdd --medium "${PATH_VM_VIRTUALBOX}/disk.vmdk" 2>>"$ERROR_FILE"
        
        # Agregar controlador SATA separado para el disco de datos K8S
        # Esto garantiza que aparezca como /dev/sda (predecible), sin colisionar con NVMe
        if ! VBoxManage storagectl "$nameVM" --name "SATA_K8S_Data" --add sata --controller IntelAhci --portcount 1 2>>"$ERROR_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> ADDING_SATA_CONTROLLER"
            exit 3
        fi
        echo "Controlador SATA de datos añadido correctamente"

        if ! VBoxManage createmedium disk --filename "$DISK_K8S" --size 51250 --format VMDK 2>>"$ERROR_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> CREATING_DISK"
            exit 4
        else
            echo "Disco creado correctamente"
        fi

        if ! VBoxManage storageattach "$nameVM" --storagectl "SATA_K8S_Data" --port 0 --device 0 --type hdd --medium "$DISK_K8S" 2>>"$ERROR_FILE"; then
            echo "Error crítico: Revisa los logs $ERROR_FILE -> ATTACHING_DISK"
            exit 5
        else
            echo "Disco adjuntado correctamente"
            
            VBoxManage startvm "$nameVM" 2>> "$ERROR_FILE" >> "$LOG_FILE"
            if [[ $? -ne 0 ]]; then
                echo "Error crítico: Revisa los logs $ERROR_FILE -> STARTING_VM"
                exit 6
            else
                echo "VM '$NAMEVM' iniciada correctamente"
            fi
        fi
    fi

}

#pause verificando los argumentos

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--nameVM)                  NAME_VM="$2"; shift 2 ;;
    -r|--role)                    ROLE="$2"; shift 2 ;;
    -i|--IPAddressVM)              IP_VM="$2"; shift 2 ;;
    -m|--maskVM)                  MASK_VM="$2"; shift 2 ;;
    -g|--gatewayVM)               GW_VM="$2"; shift 2 ;;
    -d|--dnsVM)                   DNS_VM="$2"; shift 2 ;;
    -I|--ipExt)                   IP_EXT="$2"; shift 2 ;;
    -M|--maskExt)                 MASK_EXT="$2"; shift 2 ;;
    -G|--gatewayExt)              GATEWAY_EXT="$2"; shift 2 ;;
    -X|--dnsExt)                  DNS_EXT="$2"; shift 2 ;;
    --kubeadmToken)               KUBEADM_TOKEN="$2"; shift 2 ;;
    --certificateKey)             CERTIFICATE_KEY="$2"; shift 2 ;;
    --firstMaster)                FIRST_MASTER_HOSTNAME="$2"; shift 2 ;;
    --numMasters)                 NUM_MASTERS="$2"; shift 2 ;;
    -h|--help)                    usage; ayuda; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;       
  esac
done

case $ROLE in
    "") echo "Error: --nameVM is required"; usage; exit 1 ;;
    "master"|"worker")  CreateNode ;;
    *) echo "Unknown role: $role"; usage; exit 1 ;;
esac