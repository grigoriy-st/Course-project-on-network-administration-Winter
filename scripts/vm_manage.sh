#!/bin/bash

source vars.sh

start_vms() {
    for vm_name in "${!VNC_VM_PORTS[@]}"; do
        sudo virsh start $vm_name
    done
}

shutdown_vms() {
    for vm_name in "${!VNC_VM_PORTS[@]}"; do
        sudo virsh shutdown $vm_name
    done
}

shutdown_vms