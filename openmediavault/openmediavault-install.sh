#!/bin/bash
set -e

export VMID=100
export VMNAME="openmediavault"
export ISO_PATH="/var/lib/vz/template/iso"
export ISO_URL="https://sourceforge.net/projects/openmediavault/files/iso/7.4.17/openmediavault_7.4.17-amd64.iso"
export ISO_CHECKSUM=""
export ISO_NAME="openmediavault_7.4.17-amd64.iso"
export ISO_PATH_FILE="${ISO_PATH}/${ISO_NAME}"
export ISO_STORAGE="local"
export DISK_STORAGE="local-lvm"
export DISK_SIZE="32"
export CORES="2"
export MEMORY="3072"
export BRIDGE="vmbr1"
export DEV1="wwn-0x5000c500fafa2260"
export DEV2="wwn-0x5000c500fafa49cc"


if [ -z "$1" ]; then
    echo "No argument provided."
    echo "[start, destroy, clean]."
elif [ "$1" = "disks" ]; then
    echo "[+] Checking disks."
    ls -l /dev/disk/by-id/
    echo "current DEV1=${DEV1}"
    echo "current DEV2=${DEV2}"
    echo "[+] Checking disks. Completed."
elif [ "$1" = "disks-whipe" ]; then
    echo "[+] Whiping disks."
    wipefs -a /dev/sda
    sgdisk --zap-all /dev/sda
    wipefs -a /dev/sdb
    sgdisk --zap-all /dev/sdb
    echo "[+] Whiping disks. Completed."
elif [ "$1" = "start" ]; then

    # === DOWNLOAD OMV ISO ===
    if [ -e "$ISO_PATH_FILE" ]; then
        echo "[+] OMV ISO already exists, skipping..."
    else
        echo "[+] Downloading OMV ISO."
        wget -O "${ISO_PATH_FILE}" "${ISO_URL}"
        # echo "[+] Verifying ISO checksum..."
        # CALC_CHECKSUM=$(sha256sum /tmp/$ISO_NAME.bz2 | awk '{print $1}')
        # if [ "$CALC_CHECKSUM" != "$ISO_CHECKSUM" ]; then
        #     echo "[!] Checksum verification failed!"
        #     echo "Expected: $ISO_CHECKSUM"
        #     echo "Got     : $CALC_CHECKSUM"
        #     exit 1
        # else
        #     echo "[+] Checksum verified successfully."
        # fi
        echo "[+] Downloading OMV ISO. Completed."
    fi

    # === CREATE VM ===
    if qm status "$VMID" &>/dev/null; then
        echo "[+] VM $VMID exists. skipping..."
    else
        echo "[+] Creating VM $VMID."
        qm create $VMID \
            --name $VMNAME \
            --ostype l26 \
            --memory 4096 \
            --cores 2 \
            --net0 virtio,bridge=$BRIDGE \
            --scsihw virtio-scsi-pci \
            --scsi0 ${DISK_STORAGE}:$DISK_SIZE \
            --scsi1 /dev/disk/by-id/$DEV1 \
            --scsi2 /dev/disk/by-id/$DEV2 \
            --ide2 ${ISO_STORAGE}:iso/${ISO_NAME},media=cdrom \
            --boot order=ide2 \
            --onboot 1
            # --efidisk0 local-lvm:1 # UEFI
            # --bios ovmf # UEFI
        echo "[+] Creating VM $VMID. Completed."
    fi
    echo "[+] VM $VMID starting."
    qm start $VMID
    echo "[+] VM $VMID starting. Completed"
elif [ "$1" = "destroy" ]; then
    echo "[+] VM $VMID destroying."
    qm stop $VMID || true
    qm destroy $VMID
    echo "[+] VM $VMID destroying. Completed."
elif [ "$1" = "clean" ]; then
    echo "[+] VM $VMID cleaning."
    qm set $VMID --boot order=scsi0 --ide2 none,media=cdrom
    qm set $VMID --bootdisk scsi0
    echo "[+] VM $VMID cleaning. Completed"
else
    echo "Unknown argument: $1"
fi