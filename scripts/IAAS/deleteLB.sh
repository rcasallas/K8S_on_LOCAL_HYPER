#!/bin/bash
# Script to delete the LB
#devops engineer: Richard Casallas

# 1. Definición de variables
NAMELB=$1
LOG_FILE="ERRORS_LB.log"

# 2. Buscar si la LB está corriendo
# Usamos -v para pasar la variable de Bash a awk de forma limpia
VMNAME1=$(VBoxManage list runningvms | awk -v name="$NAMELB" -F '"' '$0 ~ name {print $2}')
VMNAME2=$(VBoxManage list vms | awk -v name="$NAMELB" -F '"' '$0 ~ name {print $2}')


if [[ "$VMNAME1" == "$NAMELB" ]]; then
    echo "EL LB '$NAMELB' está actualmente en ejecución."
    # 3. Intentar apagado controlado
    VBoxManage controlvm "$NAMELB" poweroff 2>> "$LOG_FILE"
    sleep 3 # Esperar a que VirtualBox libere el bloqueo de la VM
    if [[ $? -ne 0 ]]; then
        echo "Error crítico: No fue posible apagar la LB utilizando VBoxManage. Revisa los logs $LOG_FILE -> SHUTINGDOWN_VM"
        
        # 4. Búsqueda del proceso (PID) si falla el comando anterior
        # Filtramos por el nombre de la LB dinámicamente
        PID=$(ps aux | grep -i "/usr/lib/virtualbox/VirtualBoxVM --comment $NAMELB" | grep -v grep | awk '{print $2}')
        
        if [ -n "$PID" ]; then
            echo "Intentando matar el proceso de la LB (PID: $PID)..."
            if kill -9 "$PID" 2>> "$LOG_FILE"; then
                echo "Proceso de la LB matado correctamente."
                vboxmanage unregistervm "$NAMELB" --delete 2>> "$LOG_FILE"
            else
                echo "Error crítico: Revisa los logs $LOG_FILE -> KILLING_VM_PROCESS"
            fi
        else
            echo "No se encontró el proceso de la LB, podría ya estar apagada."
        fi
    else
        echo "LB apagada correctamente."
        vboxmanage unregistervm "$NAMELB" --delete 2>> "$LOG_FILE"
    fi
elif [[ "$VMNAME2" == "$NAMELB" ]]; then  
    echo "La LB '$NAMELB' existe pero no está en ejecución."
    vboxmanage unregistervm "$NAMELB" --delete 2>> "$LOG_FILE"
else
    echo "La LB '$NAMELB' no se encontró."
fi
#for hdd in $(VBoxManage list hdds | grep -B2 'inaccessible' | grep '^UUID:' | awk '{print $2}'); do VBoxManage closemedium disk "$hdd" --delete; done

# Limpiar disco y VMs inaccesibles si quedaron colgadas de errores anteriores
for vm in $(VBoxManage list vms | grep '<inaccessible>' | awk '{print $2}' | tr -d '{}'); do VBoxManage unregistervm "$vm" 2>/dev/null; done
for hdd in $(VBoxManage list hdds | grep -B2 'inaccessible' | grep '^UUID:' | awk '{print $2}'); do VBoxManage closemedium disk "$hdd" --delete 2>/dev/null; done

rm -Rf "/home/rcasallas/VirtualBox VMs/$NAMELB"
echo "archivos asociados a la LB '$NAMELB' eliminada correctamente."