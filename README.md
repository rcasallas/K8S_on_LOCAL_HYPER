# Proyecto DevOps: Vagrant con Fedora CoreOS

Este proyecto configura 3 máquinas virtuales (VMs) usando Vagrant y VirtualBox, cada una ejecutando Fedora CoreOS.

## Requisitos

- [Butane](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/#_installing_via_distribution_packages) instalado via distribution Package 
- [VirtualBox](https://www.virtualbox.org/) instalado desde la URL de ORACLE.
- Conexión a internet para descargar la caja de Fedora CoreOS

## Configuración de las VMs

Cada VM tiene las siguientes especificaciones:
- Sistema operativo: Fedora CoreOS
- RAM: 4 GB
- CPUs: 2 VCPUs
- Nombres de las VMs: vm1, vm2, vm3

## Uso

1. Clona o descarga este proyecto en tu máquina local.

2. Abre una terminal en el directorio del proyecto (donde está el Vagrantfile).

3. Ejecuta el siguiente comando para iniciar las VMs:
   ```
   vagrant up
   ```
   Esto descargará la caja de Fedora CoreOS (si no está presente) y creará las 3 VMs.

4. Para conectarte a una VM específica, usa:
   ```
   vagrant ssh vm1
   ```
   Reemplaza `vm1` con `vm2` o `vm3` según sea necesario.

5. Para detener las VMs:
   ```
   vagrant halt
   ```

6. Para destruir las VMs y liberar recursos:
   ```
   vagrant destroy
   ```

## Notas

- La primera ejecución puede tomar tiempo debido a la descarga de la caja.
- Asegúrate de que VirtualBox esté configurado correctamente en tu sistema.
- Fedora CoreOS es un sistema operativo minimalista diseñado para contenedores, por lo que algunas herramientas tradicionales pueden no estar disponibles por defecto.
- Este proyecto no incluye un archivo Butane/Ignition; la configuración se aplica mediante los scripts en `scripts/`.
- Los scripts se montan en las VMs en `/vagrant/scripts`.

## Troubleshooting

- Si encuentras errores de red o conectividad, verifica tu configuración de VirtualBox y firewall.
- Para más información sobre Vagrant, consulta la [documentación oficial](https://www.vagrantup.com/docs).
- Si hay problemas con la caja de Fedora CoreOS, verifica la disponibilidad en [Vagrant Cloud](https://app.vagrantup.com/fedora/boxes/coreos).