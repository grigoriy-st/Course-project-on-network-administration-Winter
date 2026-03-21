#!/bin/bash

# DIRS
VMS_PATH="/mnt/Data_500GB/VMs/QEMU_KVM/Winter_Project"
ISO_IMGS_PATH="/mnt/Data_500GB/VMs/ISOs"
SOCKET_DIR="$HOME/.qemu-sockets"
LOCAL_PROJECT_DIR="/mnt/Data_500GB/__REMOTE__/Course-project-on-network-administration-Winter"
KICKSTARTER_DIR="$LOCAL_PROJECT_DIR/configs/vms/ks"
PRESEED_DIR="$LOCAL_PROJECT_DIR/configs/vms/preseed"
NEW_TEMP_DIR="/mnt/Data_500GB/tmp"

# ISOs
ELTEX_VM_ISO="$ISO_IMGS_PATH/Network_vms/Eltex/vesr-1.37.4-build2.iso"
REDOS_VM_ISO="$ISO_IMGS_PATH/Russian_OSs/redos-8-20250711.4.iso"
ASTRA_VM_ISO="$ISO_IMGS_PATH/Russian_OSs/orel-stable.iso"


# VMS
ELTEX_VM_NAMES=(
    # "DomRu-ISP" 
    "OMS-UR"
    "OMS-D1-LR"
    "OMS-D2-RR"
)

declare -A HOST_VMS=(
    # host_name : "os_type, vcpus, ram, rom"
    ["pc1-staff"]="astra, 1, 2048, 10G"
    # ["pc2-admin"]="redos, 2, 2048, 20G"
    # ["pc3-contractor"]="astra, 1, 2048, 10G"
    # ["rs1"]="redos, 2, 2048, 20G"
)

declare -A VNC_VM_PORTS=(
    ["DomRu-ISP"]=5901
    ["OMS-UR"]=5902
    ["OMS-D1-LR"]=5903
    ["OMS-D2-RR"]=5904
    ["pc1-staff"]=5905
    ["pc2-admin"]=5906
    ["pc3-contractor"]=5907
    ["rs1"]=5908
)

# NETWORKS
declare -A NETWORK_PARAMS=(
  # network_name : bridge_name
  ["wan"]="br-wan,100.64.0.0/30"
  ["core"]="br-core,"
  ["switch-l"]="br-sw-1"
  ["switch-r"]="br-sw-r"
)

declare -A LOCAL_NET_FILES=(
    # net_filename : net_name
    ["ur-lr"]="ur-lr"
    ["ur-rr"]="ur-rr"
    ["lr-lsw"]="lr-lsw"
    ["rr-rsw"]="rr-rsw"
    # access connections
    ["lsw-pc1"]="lsw-pc1"
    ["lsw-pc2"]="lsw-pc2"
    ["rsw-pc3"]="rsw-pc3"
    ["rsw-pc4"]="rsw-pc4"
    ["rsw-pc5"]="rsw-pc5"
    # reserve routes
    ["r-lr-rsw"]="r-lr-rsw"
    ["r-rr-lsw"]="r-rr-lsw"
)

declare -A VM_NETWORKS=(
    # ["DomRU-ISP"]="default"
    ["OMS-UR"]="default,ur-lr,ur-rr"
    ["OMS-D1-LR"]="ur-lr,lr-lsw,r-lr-rsw"
    ["OMS-D2-RR"]="ur-rr,r-rr-lsw"
    # ["pc1-staff"]="default,lsw-pc1"
    # ["pc2-admin"]="lsw-pc2"
    ["pc1-staff"]="default,OMS-LSW"
    ["pc2-admin"]="OMS-LSW"
    ["rs1"]="OMS-LSW"
    # ["OMS-WRR1"]="guest"
    # ["OMS-LSW"]="ur-lr,r-rr-lsw"
    # ["OMS-RSW"]="r-lr-rsw,guest"
)