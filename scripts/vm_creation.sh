#!/bin/bash

source vars.sh
mkdir -p "$SOCKET_DIR"

create_vesr_images() {
    for vm_name in ${ELTEX_VM_NAMES[@]}; do
        if [[ -f "$VMS_PATH$vm_name.qcow2" ]]; then
            echo "Image $vm_name.qcow2 recreated in folder $VMS_PATH"
            rm "$VMS_PATH/$vm_name.qcow2"
            qemu-img create -f qcow2 "$VMS_PATH/$vm_name.qcow2" 3G
        else
            qemu-img create -f qcow2 "$VMS_PATH/$vm_name.qcow2" 3G
        fi
    done
}

build_network_args() {
    local vm_name="$1"
    local networks="${VM_NETWORKS["$vm_name"]}"
    local network_args=()
    
    if [[ -z "$networks" ]]; then
        echo "For $vm_name no network are specified! Setup default"
        networks="default"
    fi
    
    IFS=',' read -ra net_array <<< "$networks"

    for net in "${net_array[@]}"; do
        # Check network existing
        if sudo virsh net-info "$net" &>/dev/null; then
            network_args+=(--network "network=$net,model=virtio")
            echo "Connect to libvirt network: $net" >&2
        # Check bridgge existing
        # elif sudo ovs-vsctl list-br | grep -q "^$net$"; then
        #     network_args+=(--network "bridge=$net,model=virtio")
        #     network_args+=(--network "virtualport_type=openvswitch")
        #     echo "Connect to OVS bridge: $net" >&2
        # else
        #     echo "WARNING: Network $net does not exist, skipping..." >&2
        fi
    done

    printf '%s\n' "${network_args[@]}"

    return 0
}

create_linux_images() {
    for vm_name in "${!HOST_VMS[@]}"; do
        local vm_data_arr   # element format: "os_type, vcpus, ram, rom"
        IFS=', ' read -ra vm_data_arr <<< "${HOST_VMS[$vm_name]}"
        # echo "${vm_data_arr[@]}"
        local rom="${vm_data_arr[3]}"

        qemu-img create -f qcow2 "$VMS_PATH/$vm_name.qcow2" $rom
    done
}

create_linux_vms() {
    for vm_name in "${!HOST_VMS[@]}"; do
        local vm_data_arr
        IFS=', ' read -ra vm_data_arr <<< "${HOST_VMS[$vm_name]}"
        # echo "${vm_data_arr[@]}"
        local os_type="${vm_data_arr[0]}"
        local iso_path 
        # -- TO DO -- 
        # local auto_cfg_path # Auto setup config
        # local l_extra_args  # local extra flags
        # case "$os_type" in
        #     "redos")
        #         iso_path="$REDOS_VM_ISO"
        #         auto_cfg_path="$KICKSTARTER_DIR/rs1-redos.ks"
        #         l_extra_args="inst.ks=file:/ks.cfg console=tty0 console=ttyS0,115200"
        #         ;;
        #     "astra")
        #         iso_path="$ASTRA_VM_ISO"
        #         auto_cfg_path="$PRESEED_DIR/$vm_name-astra.cfg"
        #         l_extra_args="auto=true priority=critical preseed/file=/preseed.cfg"
        #         ;;
        #     *)
        #         echo "Error: Unknown os type"
        #         return 1
        #         ;;
        # esac

        local vcpus="${vm_data_arr[1]}"
        local ram="${vm_data_arr[2]}"
        local rom="${vm_data_arr[3]::-1}"
        local qcow2_path="$VMS_PATH/$vm_name.qcow2"
        local vnc_port=${VNC_VM_PORTS[$vm_name]}

        local network_args=()
        while IFS= read -r arg; do
            [[ -n "$arg" ]] && network_args+=("$arg")
        done < <(build_network_args "$vm_name")

        if [[ "$os_type" == "redos" ]]; then
            cmd=(
                sudo virt-install \
                --name "$vm_name" \
                --vcpus "$vcpus" \
                --memory "$ram" \
                --location "$iso_path" \
                # --location file://$ASTRA_VM_ISO \
                # --initrd-inject "$auto_cfg_path" \
                # --extra-args "$l_extra_args" \
                --disk path="$qcow2_path",size=$rom \
                "${network_args[@]}" \
                --graphics vnc,port="$vnc_port" \
                --console pty,target_type=serial \
                --os-variant rhel8.0 \
                --noautoconsole \
                --wait -1
            )
        elif [[ "$os_type" == "astra" ]]; then
            cmd=(
                sudo virt-install \
                --name "$vm_name" \
                --vcpus "$vcpus" \
                --memory "$ram" \
                --cdrom "$iso_path" \
                # --boot cdrom \
                # --initrd-inject "$auto_cfg_path" \
                # --extra-args "$l_extra_args" \
                --disk path="$qcow2_path",size="$rom",bus=virtio \
                --controller type=scsi,model=virtio-scsi \
                "${network_args[@]}" \
                --graphics vnc,port="$vnc_port" \
                --console pty,target_type=serial \
                --os-variant debian10 \
                --noautoconsole \
                --wait -1
            )
        fi
        
        # printf '%s\n' "${cmd[*]}" 
        "${cmd[@]}"

        if [ $? -eq 0 ]; then
            echo "vncviewer localhost:$vnc_port"
        else
            echo "Error in creation $vm_name"
        fi
    done
    :
}

create_vesr_vms() {
    for vm_name in "${ELTEX_VM_NAMES[@]}"; do
        local vnc_port=${VNC_VM_PORTS[$vm_name]}

        if sudo virsh list --all --name | grep -q "^${vm_name}$"; then
            echo "VM $vm_name is created. Delete it to start."
            continue
        fi

        local vesr_networks=$(build_network_args "$vm_name") # connected needed networks

        sudo virt-install \
            --name "$vm_name" \
            --memory 2048 \
            --vcpus 2 \
            --disk path="${VMS_PATH}/${vm_name}.qcow2",format=qcow2,bus=ide \
            --cdrom "/mnt/Data_500GB/VMs/ISOs/Network_vms/Eltex/vesr-1.28.1-build5.iso" \
            "${vesr_networks[@]}" \
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
# create_vesr_vms
create_linux_images
create_linux_vms
# start_qemu_vms
#

