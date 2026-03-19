#!/bin/bash

VM_NAME="proxmox-lab"
RAM="12288"
CPUS="4"
DISK_SIZE="50G"
PROXMOX_ISO="/mnt/Data_500GB/VMs/Proxmox-vm/iso/proxmox-ve_9.0-1.iso"
QCOW2_PATH="/mnt/Data_500GB/VMs/QEMU_KVM/Winter_Project/$VM_NAME.qcow2"

qemu-img create \
    -f qcow2 \
    "${QCOW2_PATH}" \
    "${DISK_SIZE}"

sudo virt-install \
    --name ${VM_NAME} \
    --memory ${RAM} \
    --vcpus ${CPUS} \
    --disk path=$QCOW2_PATH,format=qcow2,bus=virtio \
    --cdrom ${PROXMOX_ISO} \
    --network network=default,model=virtio \
    --graphic vnc,port=5901,listen=0.0.0.0 \
    --os-variant debian11 \
    --noautoconsole \
    --wait -1

echo "Conenct to localhost:5901"
