#!/bin/bash
# Script to delete the VM
#devops engineer: Richard Casallas

# 1. Definición de variables
NAMEVM=$1
LOG_FILE="ERRORS_VM.log"

# 2. Buscar si la VM está corriendo
# Usamos -v para pasar la variable de Bash a awk de forma limpia
VMNAME1=$(VBoxManage list runningvms | awk -v name="$NAMEVM" -F '"' '$0 ~ name {print $2}')
VMNAME2=$(VBoxManage list vms | awk -v name="$NAMEVM" -F '"' '$0 ~ name {print $2}')


if [[ "$VMNAME1" == "$NAMEVM" ]]; then
    echo "La VM '$NAMEVM' está actualmente en ejecución."
    # 3. Intentar apagado controlado
    VBoxManage controlvm "$NAMEVM" poweroff 2>> "$LOG_FILE"
    sleep 3 # Esperar a que VirtualBox libere el bloqueo de la VM
    if [[ $? -ne 0 ]]; then
        echo "Error crítico: No fue posible apagar la VM utilizando VBoxManage. Revisa los logs $LOG_FILE -> SHUTINGDOWN_VM"
        
        # 4. Búsqueda del proceso (PID) si falla el comando anterior
        # Filtramos por el nombre de la VM dinámicamente
        PID=$(ps aux | grep -i "/usr/lib/virtualbox/VirtualBoxVM --comment $NAMEVM" | grep -v grep | awk '{print $2}')
        
        if [ -n "$PID" ]; then
            echo "Intentando matar el proceso de la VM (PID: $PID)..."
            if kill -9 "$PID" 2>> "$LOG_FILE"; then
                echo "Proceso de la VM matado correctamente."
                vboxmanage unregistervm "$NAMEVM" --delete 2>> "$LOG_FILE"
            else
                echo "Error crítico: Revisa los logs $LOG_FILE -> KILLING_VM_PROCESS"
            fi
        else
            echo "No se encontró el proceso de la VM, podría ya estar apagada."
        fi
    else
        echo "VM apagada correctamente."
        vboxmanage unregistervm "$NAMEVM" --delete 2>> "$LOG_FILE"
    fi
elif [[ "$VMNAME2" == "$NAMEVM" ]]; then  
    echo "La VM '$NAMEVM' existe pero no está en ejecución."
    vboxmanage unregistervm "$NAMEVM" --delete 2>> "$LOG_FILE"
else
    echo "La VM '$NAMEVM' no se encontró."
fi

# Limpiar disco y VMs inaccesibles si quedaron colgadas de errores anteriores
for vm in $(VBoxManage list vms | grep '<inaccessible>' | awk '{print $2}' | tr -d '{}'); do VBoxManage unregistervm "$vm" 2>/dev/null; done
for hdd in $(VBoxManage list hdds | grep -B2 'inaccessible' | grep '^UUID:' | awk '{print $2}'); do VBoxManage closemedium disk "$hdd" --delete 2>/dev/null; done

rm -Rf "/home/rcasallas/VirtualBox VMs/$NAMEVM"
echo "archivos asociados a la VM '$NAMEVM' eliminada correctamente."