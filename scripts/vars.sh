#!/bin/bash

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
    # reserve routes
    ["r-lr-rsw"]="r-lr-rsw"
    ["r-rr-lsw"]="r-rr-lsw"
)

declare -A VM_NETWORKS=(
    ["DomRU-ISP"]="default"
    ["OMS-UR"]="default,ur-lr,ur-rr"
    ["OMS-D1-LR"]="ur-lr,r-lr-rsw"
    ["OMS-D2-RR"]="ur-rr,r-rr-lsw"
    ["OMS-WRR1"]="guest"
    ["OMS-LSW"]="ur-lr,r-rr-lsw"
    ["OMS-RSW"]="r-lr-rsw,guest"
)