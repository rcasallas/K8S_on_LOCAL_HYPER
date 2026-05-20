# Proyecto DevOps: Clúster Kubernetes en Fedora CoreOS (VirtualBox)

Este proyecto automatiza el despliegue de un clúster **Kubernetes** sobre **Fedora CoreOS (FCOS)** utilizando **VirtualBox** como hipervisor. La infraestructura se aprovisiona mediante archivos **Butane/Ignition** y scripts Shell orquestados con **Make**, sin necesidad de Vagrant.

## Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                   Host (Linux)                      │
│                                                     │
│  ┌──────────────┐    Portal mTLS (HTTPS :8443)      │
│  │  mtls_portal │◄──── Sirve archivos .ign          │
│  │  (Django)    │      con autenticación mTLS       │
│  └──────────────┘                                   │
│                                                     │
│  ┌────────────────────────────────────────────┐     │
│  │             Red Host-Only 192.168.56.0/24  │     │
│  │                                            │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │     │
│  │  │LB-01     │  │LB-02     │  │          │  │     │
│  │  │HAProxy   │  │HAProxy   │  │          │  │     │
│  │  │BIND DNS  │  │BIND DNS  │  │          │  │     │
│  │  │.100      │  │.101      │  │          │  │     │
│  │  └──────────┘  └──────────┘  └──────────┘  │     │
│  │                                            │     │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │     │
│  │  │master-01 │  │master-02 │  │master-03 │  │     │
│  │  │K8S CP    │  │K8S CP    │  │K8S CP    │  │     │
│  │  │.30       │  │.31       │  │.32       │  │     │
│  │  └──────────┘  └──────────┘  └──────────┘  │     │
│  │                                            │     │
│  │  ┌──────────┐  ┌──────────┐                │     │
│  │  │worker-01 │  │worker-02 │                │     │
│  │  │.70       │  │.71       │                │     │
│  │  └──────────┘  └──────────┘                │     │
│  └────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
```

### Nodos

| Rol           | Hostnames            | IPs                 | OS                          |
| ------------- | -------------------- | ------------------- | --------------------------- |
| Load Balancer | k8s-lb-haproxy-01/02 | 192.168.56.100/101  | FCOS + HAProxy + BIND       |
| Control Plane | k8s-master-01/02/03  | 192.168.56.30/31/32 | FCOS + containerd + kubeadm |
| Worker        | k8s-worker-01/02     | 192.168.56.70/71    | FCOS + containerd           |

---

## Requisitos

### Software del Host

| Herramienta                                                                 | Versión mínima | Notas                                 |
| --------------------------------------------------------------------------- | -------------- | ------------------------------------- |
| [VirtualBox](https://www.virtualbox.org/)                                   | 7.x            | Hipervisor principal                  |
| [Butane](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/) | última         | Compilador de configs FCOS            |
| `jq`                                                                        | cualquiera     | Para parsear JSON de streams FCOS     |
| `make`                                                                      | 4.x            | Orquestador de despliegue             |
| `envsubst`                                                                  | (gettext)      | Sustitución de variables en templates |
| `curl`                                                                      | cualquiera     | Descarga de OVA y uploads al portal   |
| Python 3 + Django                                                           | 3.x / 4.x      | Servidor mTLS de Ignition files       |

### Archivos necesarios (no incluidos en el repo)

```
keys/myKeys          # Clave SSH privada  → generada con las instrucciones suministradas en INSTALL.md
keys/myKeys.pub      # Clave SSH pública → generada con las instrucciones suministradas en INSTALL.md
OVA/fedora-coreos-*.ova   # Imagen FCOS para VirtualBox → descargar con las instrucciones suministradas en INSTALL.md
scripts/IAAS/CONFIG.mk    # Variables de configuración del entorno (ver CONFIG.template)
scripts/IAAS/LB.mk        # Variables de configuración de los LBs (ver LB.mk.template)
```

---

## Estructura del proyecto

```
.
├── provisioning/
│   ├── ConfigFile_Master.bu.template   # Butane template unificado para nodos master y worker
│   ├── ConfigFile_LB.FCOS.bu.template  # Butane template para load balancers
│   └── InitVM.bu.template              # Butane template de pre-configuración (Init)
│
├── scripts/
│   ├── IAAS/
│   │   ├── makefile          # Orquestador principal (make startVM / make deleteVM)
│   │   ├── startVM.sh        # Despliegue automatizado de nodos master/worker
│   │   ├── startLB.sh        # Despliegue automatizado de load balancers
│   │   ├── deleteVM.sh       # Eliminación de VMs master/worker
│   │   ├── deleteLB.sh       # Eliminación de VMs LB
│   │   ├── CONFIG.template   # Plantilla de variables de entorno (copiar a CONFIG.mk)
│   │   └── LB.mk.template    # Plantilla de config de LBs (copiar a LB.mk)
│   └── K8S/                  # Scripts de inicialización del clúster (ignorados en git)
│
├── dynamic/                  # Archivos generados dinámicamente (hosts, ign) — ignorados
├── keys/                     # Claves SSH — ignoradas en git
├── OVA/                      # Imagen FCOS — ignorada en git
├── INSTALL.md                # Guía de configuración inicial
└── README.md                 # Este archivo
```

---

## Flujo de despliegue

```
CONFIG.template ──► CONFIG.mk
                        │
                        ▼
              make startVM / make startLB
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
    startVM.sh     startLB.sh    generateHosts
          │
          ├─ 1. Importa OVA FCOS a VirtualBox
          ├─ 2. Configura NICs (NAT + Host-Only)
          ├─ 3. Genera archivo .ign desde Butane template (envsubst + butane)
          ├─ 4. Sube .ign al servidor mTLS (curl → Django portal :8443)
          ├─ 5. Inyecta URL del .ign como VirtualBox GuestProperty
          ├─ 6. Añade controlador NVMe (disco OS) + SATA (disco datos /dev/sda)
          └─ 7. Inicia la VM → Ignition descarga y aplica config en primer boot
```

### Proceso de Ignition en primer boot (FCOS)

1. **fetch-offline** — Intenta leer config local (no aplica)
2. **fetch** — Descarga el `.ign` del servidor mTLS con certificado CA personalizado
3. **disks** — Particiona `/dev/sda` (disco SATA de datos) → label `k8s-master-data` → XFS montado en `/var/lib/kubernetes`
4. **files** — Escribe archivos de configuración (NetworkManager, sysctl, scripts)
5. **systemd** — Habilita servicios y enmascara units no deseados

---

## Configuración inicial

### 1. Generar claves SSH

```bash
ssh-keygen -f ./keys/myKeys -t ed25519 -C "devopsadmin@example.com" -N ""
```

### 2. Descargar OVA de Fedora CoreOS

```bash
# Descarga automática de la versión stable
curl -LO $(curl -s https://builds.coreos.fedoraproject.org/streams/stable.json \
  | jq -r '.architectures.x86_64.artifacts.virtualbox.formats.ova.disk.location')
mv fedora-coreos-*.ova OVA/
```

### 3. Crear archivo de configuración

```bash
cp scripts/IAAS/CONFIG.template scripts/IAAS/CONFIG.mk
cp scripts/IAAS/LB.mk.template  scripts/IAAS/LB.mk
# Editar los archivos con tus IPs, versiones y credenciales
```

### 4. Desplegar las VMs

```bash
cd scripts/IAAS

# Desplegar load balancers
make startLB

# Desplegar nodos master y worker
make startVM

# Eliminar todas las VMs
make deleteVM
make deleteLB
```

---

## Aprovisionamiento automático (Ignition)

Cada nodo se configura en el primer boot mediante dos archivos Ignition:

| Archivo                    | Propósito                                                                 |
| -------------------------- | ------------------------------------------------------------------------- |
| `preconfig_<hostname>.ign` | Config inicial (Init): usuario, red básica, descarga del config principal |
| `<hostname>.ign`           | Config principal: red estática, disco de datos, servicios systemd         |

### Servicios systemd instalados en los nodos (Master / Worker)

La lógica de ejecución de los servicios de clúster está controlada dinámicamente mediante `ExecCondition` evaluando la variable de entorno `TYPE_NODE` durante el aprovisionamiento.

| Servicio                          | Roles      | Función                                                                      |
| --------------------------------- | ---------- | ---------------------------------------------------------------------------- |
| `install-containerd-runc.service` | Ambos      | Instala containerd, runc, kubelet, kubeadm, kubectl y etcd vía `rpm-ostree`  |
| `enable-services.service`         | Ambos      | Enmascara `systemd-resolved`, configura DNS local, aplica sysctl             |
| `init-k8s-master.service`         | Master     | Inicializa el clúster (`kubeadm init`) o lo une como control-plane adicional |
| `init-k8s-worker.service`         | Worker     | Une el nodo como worker estándar (`kubeadm join`)                            |
| `install-cilium.service`          | Master (1) | Instala Cilium CNI vía Helm (sólo se ejecuta en el primer master)            |

### Almacenamiento en Nodos

| Disco         | Dispositivo                  | Uso                                                                |
| ------------- | ---------------------------- | ------------------------------------------------------------------ |
| OS (OVA FCOS) | NVMe (`nvme0n1` o `nvme0n2`) | Sistema operativo inmutable                                        |
| Datos K8S     | SATA → `/dev/sda`            | Partición `k8s-master-data` (XFS) montada en `/var/lib/kubernetes` |

> **Nota:** El disco de datos se conecta a un controlador SATA separado (`SATA_K8S_Data`) para evitar colisiones con la enumeración dinámica de namespaces NVMe del disco del OS.

---

## Versiones de software

| Software       | Versión configurada        |
| -------------- | -------------------------- |
| Fedora CoreOS  | 43.20260316.3.1            |
| Kubernetes     | 1.35                       |
| containerd     | 2.x (incluido en FCOS)     |
| runc           | 1.x (incluido en FCOS)     |
| Cilium CNI     | 1.14.0                     |
| etcd / etcdctl | (instalado vía rpm-ostree) |
| HAProxy        | (incluido en FCOS LB)      |
| BIND DNS       | (incluido en FCOS LB)      |

---

## Troubleshooting

### Revisar el log de consola serial

```bash
# El log de cada VM se guarda automáticamente
tail -f scripts/IAAS/LOGS/k8s-master-01_console.log
```

### Errores comunes

| Error                                                  | Causa                                                  | Solución                                                   |
| ------------------------------------------------------ | ------------------------------------------------------ | ---------------------------------------------------------- |
| `coreos-ignition-unique-boot.service` falla            | `wipe_table: true` en disco del OS                     | Usar disco SATA separado para datos                        |
| `partition N didn't match: label ... got "BIOS-BOOT"`  | NVMe data disk apuntando al disco del OS               | El disco de datos debe estar en controlador SATA           |
| `systemd-resolved-varlink.socket` falla                | `mask --now systemd-resolved` no enmascara los sockets | Enmascarar service + varlink + monitor sockets             |
| SSH: `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` | Recreación de VMs cambia fingerprint                   | `ssh-keygen -R <IP>` o `rm ~/.ssh/known_hosts`             |
| Ignition no descarga config                            | CA cert no accesible en fetch-offline                  | Es esperado; se descarga en la fase `fetch` con red activa |

### Comandos útiles de diagnóstico

```bash
# Ver estado de servicios de aprovisionamiento (en la VM)
systemctl status install-containerd-runc.service
systemctl status enable-services.service

# Ver journalctl de un servicio
journalctl -u install-containerd-runc.service -f

# Validar un template Butane
export K8S_HOSTNAME=k8s-master-01 IP_ADDRESS_VM=192.168.56.30 ...
envsubst < provisioning/ConfigFile_Master.bu.template | butane --pretty --strict -d .
```

---

## Seguridad

- Las claves SSH (`keys/`) y archivos de configuración con credenciales (`CONFIG.mk`, `LB.mk`) están excluidos del repositorio via `.gitignore`.
- El servidor de Ignition usa **mTLS** (mutual TLS) con certificados propios — los nodos validan la identidad del servidor antes de descargar su configuración.
- Los archivos `.ign` generados contienen credenciales y se excluyen del repo (`*.ign`).
