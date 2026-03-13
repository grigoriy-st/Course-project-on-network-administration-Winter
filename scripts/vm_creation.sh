#!/bin/bash

VMS_PATH="/mnt/Data_500GB/VMs/QEMU_KVM/Winter_Project"
ISO_IMGS_PATH="/mnt/Data_500GB/VMs/ISOs"
ELTEX_VM_ISO="$ISO_IMGS_PATH/Network_vms/Eltex/vesr-1.37.4-build2.iso"
ELTEX_VM_NAMES=(
    "DomRu-ISP" 
    "OMS-UR"
    "OMS-D1-LR"
    "OMS-D2-RR"
)

SOCKET_DIR="$HOME/.qemu-sockets"
mkdir -p "$SOCKET_DIR"

declare -A VNC_VM_PORTS=(
    ["DomRu-ISP"]=5901
    ["OMS-UR"]=5902
    ["OMS-D1-LR"]=5903
    ["OMS-D2-RR"]=5904
)

create_vm_images() {
    for vm_name in ${ELTEX_VM_NAMES[@]}; do
        if [[ -f "$VMS_PATH$vm_name.qcow2" ]]; then
            echo "Хранилище $vm_name.qcow2 пересоздано в папке $VMS_PATH"
            rm "$VMS_PATH/$vm_name.qcow2"
            qemu-img create -f qcow2 "$VMS_PATH/$vm_name.qcow2" 3G
        else
            qemu-img create -f qcow2 "$VMS_PATH/$vm_name.qcow2" 3G
        fi
    done
}


create_qemu_vms() {
    for vm_name in ${ELTEX_VM_NAMES[@]}; do
        vnc_port=${VNC_VM_PORTS[$vm_name]}
        socket_path="/tmp/vm-${vm_name}.sock"

        if [[ -f "$socket_path" ]]; then
            rm -f "$socket_path"
        fi

        sudo qemu-system-x86_64 \
            -enable-kvm \
            -m 2G \
            -drive file="${VMS_PATH}/${vm_name}.qcow2",index=0,if=virtio \
            -drive file="${ELTEX_VM_ISO}",media=cdrom,index=1 \
            -boot d \
            -vnc :"${vnc_port}" \
            -chardev socket,id=serial0,path="${socket_path}",server=on,wait=off \
            -device isa-serial,chardev=serial0 \
            -netdev user,id=net0,hostfwd=tcp::2222-:22 \
            -device virtio-net-pci,netdev=net0

        sleep 2

        if [ $? -eq 0 ]; then
            echo "VM $vm_name создана и доступна в vnc: vncviewer :$vnc_port"
        else
            echo "FAIL: VM $vm_name не запустилась"
        fi
        break
    done
}

start_qemu_vms() {
    for vm_name in ${ELTEX_VM_NAMES[@]}; do
        vnc_port=${VNC_VM_PORTS[$vm_name]}
        socket_path="/tmp/vm-${vm_name}.sock"

        if [[ -f "$socket_path" ]]; then
            rm -f "$socket_path"
        fi

        sudo qemu-system-x86_64 \
            -enable-kvm \
            -m 2G \
            -drive file="${VMS_PATH}/${vm_name}.qcow2",if=virtio \
            -vnc :"${vnc_port}" \
            -chardev socket,id=serial0,path="${socket_path}",server=on,wait=off \
            -device isa-serial,chardev=serial0 \
            -netdev user,id=net0,hostfwd=tcp::2222-:22 \
            -device virtio-net-pci,netdev=net0

        sleep 2

        if [ $? -eq 0 ]; then
            echo "VM $vm_name создана и доступна в vnc: vncviewer :$vnc_port"
        else
            echo "FAIL: VM $vm_name не запустилась"
        fi
        # break
    done
}

create_virt_vms() {
    for vm_name in "${ELTEX_VM_NAMES[@]}"; do
        vnc_port=${VNC_VM_PORTS[$vm_name]}

        if sudo virsh list --all --name | grep -q "^${vm_name}$"; then
            echo "VM $vm_name уже существует. Удалите её сначала."
            continue
        fi
        
        sudo virt-install \
            --name "$vm_name" \
            --memory 2048 \
            --vcpus 2 \
            --disk path="${VMS_PATH}/${vm_name}.qcow2",format=qcow2,bus=ide \
            --cdrom "/mnt/Data_500GB/VMs/ISOs/Network_vms/Eltex/vesr-1.28.1-build5.iso" \
            --network network=default,model=virtio \
            --graphics vnc,port=$vnc_port \
            --console pty,target_type=serial \
            --os-variant generic \
            --noautoconsole \
            --wait -1

        if [ $? -eq 0 ]; then
            echo "vncviewer localhost:$vnc_port"
        else
            echo "Ошибка создания $vm_name"
        fi
        
        # break
    done
}

create_virt_vms
# create_vm_images
# start_qemu_vms
#

