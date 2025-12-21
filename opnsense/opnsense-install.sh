#!/bin/bash
set -e

export VMID=101
export VMNAME="opnsense"
export ISO_PATH="/var/lib/vz/template/iso"
export ISO_URL="https://pkg.opnsense.org/releases/25.7/OPNsense-25.7-dvd-amd64.iso.bz2"
export ISO_CHECKSUM="fa4b30df3f5fd7a2b1a1b2bdfaecfe02337ee42f77e2d0ae8a60753ea7eb153e"
export ISO_NAME="OPNsense-25.7-dvd-amd64.iso"
export ISO_PATH_FILE="${ISO_PATH}/${ISO_NAME}"
export ISO_STORAGE="local"
export DISK_STORAGE="local-lvm"
export DISK_SIZE="32"
export CORES="2"
export MEMORY="3072"
export WAN_BRIDGE="vmbr0"
export LAN_BRIDGE="vmbr1"

if [ -z "$1" ]; then
    echo "No argument provided."
    echo "[start, destroy, clean]."
elif [ "$1" = "start" ]; then

    # === DOWNLOAD OPNsense ISO ===
    if [ -e "$ISO_PATH_FILE" ]; then
        echo "[+] OPNsense ISO already exists, skipping..."
    else
        echo "[+] Downloading OPNsense ISO..."
        wget -O /tmp/$ISO_NAME.bz2 $ISO_URL
        echo "[+] Verifying ISO checksum..."
        CALC_CHECKSUM=$(sha256sum /tmp/$ISO_NAME.bz2 | awk '{print $1}')
        if [ "$CALC_CHECKSUM" != "$ISO_CHECKSUM" ]; then
            echo "[!] Checksum verification failed!"
            echo "Expected: $ISO_CHECKSUM"
            echo "Got     : $CALC_CHECKSUM"
            exit 1
        else
            echo "[+] Checksum verified successfully."
        fi
        bunzip2 /tmp/$ISO_NAME.bz2
        mv /tmp/$ISO_NAME /var/lib/vz/template/iso/$ISO_NAME
    fi

    # === CREATE NEW LAN BRIDGE ===
    if ! grep -q "$LAN_BRIDGE" /etc/network/interfaces; then
        echo "[+] Creating new LAN bridge $LAN_BRIDGE..."
        echo "auto $LAN_BRIDGE" >> /etc/network/interfaces
        echo "iface $LAN_BRIDGE inet manual" >> /etc/network/interfaces
        echo "    bridge-ports none" >> /etc/network/interfaces
        echo "    bridge-stp off" >> /etc/network/interfaces
        echo "    bridge-fd 0" >> /etc/network/interfaces
        echo "[+] Restarting networking..."
        systemctl restart networking
    else
        echo "[+] LAN bridge $LAN_BRIDGE already exists, skipping..."
    fi

    # === CREATE VM ===
    if qm status "$VMID" &>/dev/null; then
        echo "[+] VM $VMID exists. skipping..."
    else
        qm create $VMID \
            --name $VMNAME \
            --ostype l26 \
            --memory $MEMORY \
            --cores $CORES \
            --net0 virtio,bridge=$WAN_BRIDGE \
            --net1 virtio,bridge=$LAN_BRIDGE \
            --scsihw virtio-scsi-pci \
            --scsi0 $DISK_STORAGE:$DISK_SIZE \
            --ide2 $ISO_STORAGE:iso/$ISO_NAME,media=cdrom \
            --boot order=ide2 \
            --efidisk0 local-lvm:1 \
            --bios ovmf \
            --onboot 1
        echo "[+] VM $VMID created."
    fi
    qm start $VMID
    echo "[+] VM $VMID started."
elif [ "$1" = "destroy" ]; then
    qm stop $VMID || true
    qm destroy $VMID
    echo "[+] VM $VMID destroyed."
elif [ "$1" = "clean" ]; then
    qm set $VMID --boot order=scsi0 --ide2 none,media=cdrom
    qm set $VMID --bootdisk scsi0
    echo "[+] VM $VMID cleaned."
else
    echo "Unknown argument: $1"
fi