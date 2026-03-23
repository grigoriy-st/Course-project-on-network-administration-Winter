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
        
        local os_type="${vm_data_arr[0]}"
        local iso_path 
        
        local auto_cfg_path # Auto setup config
        local l_extra_args  # local extra flags
        local http_root

        case "$os_type" in
            "redos")
                iso_path="$REDOS_VM_ISO"
                auto_cfg_path="$KICKSTARTER_DIR/$vm_name-redos.ks"
                http_root="${NEW_TEMP_DIR}/redos-http-${vm_name}"
                # Для локального location используем file:// путь
                l_extra_args="inst.ks=file:/$(basename "$auto_cfg_path") inst.text console=tty0 console=ttyS0,115200"
                ;;
            "astra")
                iso_path="$ASTRA_VM_ISO"
                auto_cfg_path="$PRESEED_DIR/$vm_name-astra.cfg"
                l_extra_args="auto=true priority=critical preseed/file=/preseed.cfg"
                ;;
            *)
                echo "Error: Unknown os type"
                return 1
                ;;
        esac

        local vcpus="${vm_data_arr[1]}"
        local ram="${vm_data_arr[2]}"
        local rom="${vm_data_arr[3]::-1}"
        local qcow2_path="$VMS_PATH/$vm_name.qcow2"
        local vnc_port=${VNC_VM_PORTS[$vm_name]}
        local socket_path="${SOCKET_DIR}/${vm_name}.sock"

        printf "qcow2_path: %s\niso_path: %s\n" "$qcow2_path" "$iso_path"
        rm -f "$socket_path"

        local network_args=()
        while IFS= read -r arg; do
            [[ -n "$arg" ]] && network_args+=("$arg")
        done < <(build_network_args "$vm_name")

        if [[ ! -f "$auto_cfg_path" ]]; then
            echo "ERROR: Kickstart file not found: $auto_cfg_path"
            return 1
        fi
        
        # Монтируем ISO
        sudo mkdir -p "/mnt/iso/${vm_name}"
        sudo mount -o loop,ro "$iso_path" "/mnt/iso/${vm_name}"
        
        # Проверка монтирования
        if [[ ! -f "/mnt/iso/${vm_name}/.treeinfo" ]]; then
            echo "ERROR: ISO mount failed"
            sudo umount "/mnt/iso/${vm_name}"
            return 1
        fi

        if [[ "$os_type" == "redos" ]]; then
            sudo mkdir -p "/mnt/iso/${vm_name}"
            sudo mount -o loop,ro "$iso_path" "/mnt/iso/${vm_name}"
            
            sudo virt-install \
                --name pc1-staff \
                --vcpus 2 \
                --memory 2048 \
                --disk path="$qcow2_path",size="$rom",bus=virtio \
                --cdrom "$REDOS_VM_ISO" \
                --network type=ethernet,source=OMS-LSW,model=virtio \
                --graphics vnc,port="$vnc_port" \
                --console pty,target_type=serial \
                --os-variant rhel8.0 \
                --noautoconsole

        elif [[ "$os_type" == "astra" ]]; then
            sudo mkdir -p "/mnt/iso/$os_type"
            sudo mount -o loop "$iso_path" "/mnt/iso/$os_type"

            cmd=(
                sudo virt-install
                --name "$vm_name" \
                --vcpus "$vcpus" \
                --memory "$ram" \
                --cdrom "$iso_path" \
                # --cdrom "$iso_path" \
                # --boot cdrom \
                --disk path="$qcow2_path",size="$rom",bus=virtio \
                # --initrd-inject "$auto_cfg_path" \
                # --extra-args "$l_extra_args" \
                # --controller type=scsi,model=virtio-scsi \
                # --network type=direct,source=OMS-LSW,source_mode=bridge,model=virtio \
                "${networks_args[@]}" \
                --serial "unix,path=$socket_path,mode=bind" \
                --graphics vnc,port="$vnc_port" \
                --console pty,target_type=serial \
                --os-variant debian10 \
                --noautoconsole \
                --wait -1
            )
        fi
 
        # printf '%s\n' "${cmd[*]}" 
        "${cmd[@]}"
        sudo chown "$USER:$USER" "$socket_path" 2>/dev/null

        echo "Clean extra data?(y/n)"
        local answer
        read answer
        
        if [[ "$answer" == "y" ]]; then
            sudo kill $HTTP_PID
            sudo umount "/mnt/iso/${vm_name}" 2>/dev/null
            sudo kill $HTTP_PID 2>/dev/null
            sudo umount "/mnt/iso/${vm_name}"
            rm -rf "$http_root"
        else
            echo "Iso image /mnt/iso/$os_type is mounted"
        fi

        if [ $? -eq 0 ]; then
            echo "vncviewer localhost:$vnc_port"
        else
            echo "Error in creation $vm_name"
        fi

        break
    done
}

clear_ex_host_vms() {
    for vm_name in "${!HOST_VMS[@]}"; do
        sudo virsh shutdown $vm_name 2>/dev/null
        sudo virsh destroy $vm_name  2>/dev/null
        sudo virsh undefine $vm_name 2>/dev/null
    done
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
clear_ex_host_vms
create_linux_images
create_linux_vms
# start_qemu_vms
#

