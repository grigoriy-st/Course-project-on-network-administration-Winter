#!/bin/bash

source vars.sh
mkdir -p "$SOCKET_DIR"

main() {
    # -- TO Review --
    # create_vm_images
    # create_vesr_images
    # create_vesr_vms
    clear_ex_host_vms
    # create_linux_vms
    # start_qemu_vms
    declare -A vm_config
    for vm_name in "${!HOST_VMS[@]}"; do
        local raw_vm_params="${HOST_VMS[$vm_name]}"
        if parse_vm_data "$vm_name" "$raw_vm_params" vm_config; then
            :
        else
            echo "Failed to parse vm config!"
        fi
        
        create_linux_images vm_config
        
        local os_type="${vm_config["os_type"]}"
        if [[ "$os_type" == "redos" ]]; then
            # create_vm_redos vm_config
            create_vm_redos_by_ks vm_config
        elif [[ "$os_type" == "astra" ]]; then
            create_vm_astra
        fi

    # sudo chown "$USER:$USER" "$socket_path" 2>/dev/null

    break
    done

    return 0
}

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
    return 0
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
            # echo "Connect to libvirt network: $net" >&2
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


# Params:
# $1 - vm_name
# $2 - vm_params="os_type, vcpus, ram, rom"
# $3 - vm_config : Reference associated array 
parse_vm_data() {
    local vm_name=$1
    local vm_params=$2
    local -n result_array=$3
    local vm_data_arr
    IFS=', ' read -ra vm_data_arr <<< "$vm_params"
    
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
            # l_extra_args="inst.ks=file:/$(basename "$auto_cfg_path") inst.text console=tty0 console=ttyS0,115200"
            l_extra_args="inst.text console=tty0 console=ttyS0,115200"
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
    local rom="${vm_data_arr[3]::-1}" # strip before G
    local qcow2_path="$VMS_PATH/$vm_name.qcow2"
    local vnc_port=${VNC_VM_PORTS[$vm_name]}
    local socket_path="${SOCKET_DIR}/${vm_name}.sock"

    # printf "qcow2_path: %s\niso_path: %s\n" "$qcow2_path" "$iso_path"
    # rm -f "$socket_path"

    local network_args=()
    while IFS= read -r arg; do
        [[ -n "$arg" ]] && network_args+=("$arg")
    done < <(build_network_args "$vm_name")

    if [[ ! -f "$auto_cfg_path" ]]; then
        echo "ERROR: Kickstart file not found: $auto_cfg_path"
        return 1
    fi
    
    local ip_addr=($(ip -f inet -o addr show enp7s0 | cut -d' ' -f 7 | cut -d/ -f 1))
    # if [[ ! -f "/mnt/iso/${vm_name}/.treeinfo" ]]; then
    #     echo "ERROR: ISO mount failed"
    #     sudo umount "/mnt/iso/${vm_name}"
    #     return 1
    # fi

    # echo "HTTP ROOT in PARSE: $http_root"
    result_array=(
        ["host_name"]="$vm_name"
        ["os_type"]="$os_type"
        ["iso_path"]="$iso_path"
        ["auto_cfg_path"]="$auto_cfg_path"
        ["l_extra_args"]="$l_extra_args"
        ["vcpus"]="$vcpus"
        ["ram"]="$ram"
        ["rom"]="$rom" 
        ["qcow2_path"]="$qcow2_path"
        ["vnc_port"]="$vnc_port"
        ["socket_path"]="$socket_path"
        ["networks_args"]="$networks_args"
        ["host_ip"]="$ip_addr"
        ["http_root"]="$http_root"
    )
    return 0
}

debug_print() {
    echo "[DEBUG] $1"
}

setup_http_server() {
    local http_root=$1
    local vm_name=$2
    local iso_path=$3
    local kickstart_file=$4
    
    
    mkdir -p "$http_root"
    
    # Copy kickstart
    cp "$kickstart_file" "$http_root/ks.cfg"
    
    # Mount ISO
    local iso_mount="/mnt/iso/${vm_name}"
    sudo mkdir -p "$iso_mount"
    
    if ! mountpoint -q "$iso_mount"; then
        sudo mount -o loop,ro "$iso_path" "$iso_mount"
    fi
    
    # Mount all ISO files in install_tree
    local install_tree_dir="$http_root/install_tree"

    local copy_over=0
    if [ -d "$install_tree_dir" ]; then
        local answer
        echo "Folder $install_tree_dir is existing! Update data?(y/n)"
        read -r answer
        if [[ "${answer,,}" == "y" ]]; then
            copy_over=1
        else
            copy_over=0
        fi
    fi

    if [[ $copy_over -eq 1 ]]; then
        mkdir -p "$install_tree_dir"
        
        echo "Copying ISO files to $install_tree_dir (this may take a few minutes)..."
        sudo cp -r "$iso_mount"/* "$install_tree_dir/" 2>/dev/null
        
        sudo chown -R $(whoami):$(whoami) "$http_root"
        chmod -R 755 "$http_root"
        
        if [[ ! -d "$install_tree_dir/repodata" ]]; then
            echo "ERROR: repodata not found in ISO!"
            
            if [[ -d "$iso_mount/BaseOS/repodata" ]]; then
                mkdir -p "$install_tree_dir/BaseOS"
                cp -r "$iso_mount/BaseOS/repodata" "$install_tree_dir/BaseOS/"
                cp -r "$iso_mount/BaseOS/Packages" "$install_tree_dir/BaseOS/"
                
                ln -s BaseOS/repodata "$install_tree_dir/repodata"
            else
                echo "ERROR: Cannot find repodata in ISO"
                return 1
            fi
        fi
    fi
    
    echo "Checking install_tree structure:"
    ls -la "$install_tree_dir"
    if [[ -d "$install_tree_dir/repodata" ]]; then
        echo "repodata found"
        ls -la "$install_tree_dir/repodata"
    else
        echo "repodata NOT found"
        return 1
    fi
    
    # HTTP Server
    cd "$http_root"
    pkill -f "http.server" 2>/dev/null
    python3 -m http.server 8000 --bind 0.0.0.0 > "/tmp/http_${vm_name}.log" 2>&1 &
    local http_pid=$!
    cd - > /dev/null
    
    sleep 2
    
    echo "${http_pid}:${iso_mount}"
    return 0
}

cleanup_vm_deployment() {
    local http_pid="${vm_config["http_pid"]}"
    local vm_name="${vm_config["host_name"]}"
    local http_root="${vm_config["http_root"]}"
    
    echo "Clean up VM $vm_name deployment? (y/n)"
    local answer
    read answer
    
    if [[ "$answer" == "y" ]]; then
        [[ -n "$http_pid" ]] && sudo kill "$http_pid" 2>/dev/null
        
        sudo umount "/mnt/iso/${vm_name}" 2>/dev/null
        
        [[ -d "$http_root" ]] && rm -rf "$http_root"
        
        echo "Cleanup completed"
    else
        echo "Skipping cleanup. ISO mounted at /mnt/iso/$vm_name"
        echo "HTTP root at: $http_root"
    fi
}

# Params
# $1 - vm_name
# $2 - iso_path
mount_iso_img() {
    local vm_name=$1
    local iso_path=$2

    sudo mkdir -p "/mnt/iso/${vm_name}"
    sudo mount -o loop,ro "$iso_path" "/mnt/iso/${vm_name}"

    return 0
}

print_vm_config() {
    for key in "${!vm_config[@]}"; do
        echo "  $key: ${vm_config[$key]}"
    done
    return 0
}

# Params:
# $1 - vm_config : Reference Associated array
create_linux_images() {
    # print_vm_config vm_config
    for vm_name in "${!HOST_VMS[@]}"; do
        local rom="${vm_config["rom"]}"
        qemu-img create -f qcow2 "$VMS_PATH/$vm_name.qcow2" $rom
    done
}

# Params:
# $1 - vm_config : Reference Associated array
create_vm_redos_by_ks() {
    local vm_name="${vm_config["host_name"]}"
    local rom="${vm_config["rom"]}"
    local ram="${vm_config["ram"]}"
    local vcups="${vm_config["vcpus"]}"
    local iso_path="${vm_config["iso_path"]}"
    local qcow2_path="${vm_config["qcow2_path"]}"
    local vnc_port="${vm_config["vnc_port"]}"
    local network_args="${vm_config["network_args"]}"
    local host_ip="${vm_config["host_ip"]}"
    local l_extra_args="${vm_config["l_extra_args"]}"
    local auto_cfg_path="${vm_config["auto_cfg_path"]}"
    local http_root="${vm_config["http_root"]}"
    mount_iso_img $vm_name "$REDOS_VM_ISO"
    
    echo "Data: $http_root" "$vm_name" "$iso_path" "$auto_cfg_path"
    setup_http_server "$http_root" "$vm_name" "$iso_path" "$auto_cfg_path"

    local http_setup
    http_setup=$(setup_http_server "$http_root" "$vm_name" "$iso_path" "$auto_cfg_path")
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to setup HTTP server"
        return 1
    fi
    
    local http_pid=$(echo "$http_setup" | cut -d: -f1)
    local iso_mount=$(echo "$http_setup" | cut -d: -f2-)
    
    local kernel_args="inst.ks=http://${host_ip}:8000/ks.cfg inst.repo=http://${host_ip}:8000/install_tree console=tty0 console=ttyS0,115200"

    sudo virt-install \
        --name "$vm_name" \
        --vcpus "$vcpus" \
        --memory "$ram" \
        --disk path="$qcow2_path",size="$rom",bus=virtio \
        --location "$iso_path" \
        --extra-args "$kernel_args" \
        --network network=default \
        --network type=ethernet,source=OMS-LSW,model=virtio \
        --graphics vnc,port="$vnc_port" \
        --console pty,target_type=serial \
        --os-variant rhel8.0 \
        --noautoconsole \
        --wait -1
    

    if [ $? -eq 0 ]; then
        echo "vncviewer localhost:$vnc_port"
    else
        echo "Error in creation $vm_name"
    fi

    cleanup_vm_deployment vm_config
    return 0
}

# Params:
# $1 - vm_config : Reference Associated array
create_vm_redos() {
    local vm_name="${vm_config["host_name"]}"
    local rom="${vm_config["rom"]}"
    local qcow2_path="${vm_config["qcow2_path"]}"
    local vnc_port="${vm_config["vnc_port"]}"
    local network_args="${vm_config["network_args"]}"
    local l_extra_args="${vm_config["l_extra_args"]}"
    
    mount_iso_img $vm_name "$REDOS_VM_ISO"
    # print_vm_config $vm_config
    
    sudo virt-install \
        --name $vm_name \
        --vcpus 2 \
        --memory 2048 \
        --disk path="$qcow2_path",size="$rom",bus=virtio \
        --cdrom "$REDOS_VM_ISO" \
        --network type=ethernet,source=OMS-LSW,model=virtio \
        --graphics vnc,port="$vnc_port" \
        --console pty,target_type=serial \
        --os-variant rhel8.0 \
        --noautoconsole
    

    cleanup_vm_deployment vm_config
    return 0
}

# Params:
# $1 - host_name
create_vm_astra() {
    # -- TO DO --
    local vm_name="${vm_config["host_name"]}"
    local qcow2_path="${vm_config["qcow2_path"]}"
    local vnc_port="${vm_config["vnc_port"]}"

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
    
    cleanup_vm_deployment vm_config
    return 0
}

clear_ex_host_vms() {
    for vm_name in "${!HOST_VMS[@]}"; do
        sudo virsh shutdown $vm_name 2>/dev/null
        sudo virsh destroy $vm_name  2>/dev/null
        sudo virsh undefine $vm_name 2>/dev/null
    done
    return 0
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

    return 0
}

main