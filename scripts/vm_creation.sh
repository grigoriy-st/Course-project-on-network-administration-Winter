#!/bin/bash

source vars.sh
mkdir -p "$SOCKET_DIR"

create_vesr_images() {
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

build_network_args() {
    local vm_name="$1"
    networks="${VM_NETWORKS["$vm_name"]}"
    NETWORK_ARGS=()
    
    if [[ -z "$networks" ]]; then
        echo "For $vm_name no network are specified! Setup default"
        networks="default"
    fi
    
    IFS=',' read -ra net_array <<< "$networks"

    for net in "${net_array[@]}"; do
        # Check network existing
        if sudo virsh net-info "$net" &>/dev/null; then
            NETWORK_ARGS+=(--network "network=$net,model=virtio")
            echo "Connect to net: $net"
        else
            echo "Network in undefine..."
        fi
    done
}

create_linux_images() {
    local vm_name=$1
    :
}

create_linux_vms() {
    local vm_name=$1
    local 
    :
}

create_vesr_vms() {
    for vm_name in "${ELTEX_VM_NAMES[@]}"; do
        vnc_port=${VNC_VM_PORTS[$vm_name]}

        if sudo virsh list --all --name | grep -q "^${vm_name}$"; then
            echo "VM $vm_name is created. Delete it to start."
            continue
        fi

        build_network_args "$vm_name" # connected needed networks

        sudo virt-install \
            --name "$vm_name" \
            --memory 2048 \
            --vcpus 2 \
            --disk path="${VMS_PATH}/${vm_name}.qcow2",format=qcow2,bus=ide \
            --cdrom "/mnt/Data_500GB/VMs/ISOs/Network_vms/Eltex/vesr-1.28.1-build5.iso" \
            "${NETWORK_ARGS[@]}" \
            --graphics vnc,port=$vnc_port \
            --console pty,target_type=serial \
            --os-variant generic \
            --noautoconsole \
            --wait -1

        if [ $? -eq 0 ]; then
            echo "vncviewer localhost:$vnc_port"
        else
            echo "Error in creation $vm_name"
        fi
        
    done
}

# create_vm_images
# create_vesr_images
create_vesr_vms
# start_qemu_vms
#

