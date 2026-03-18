#!/bin/bash

declare -A network_params=(
  # network_name : bridge_name
  ["wan"]="br-wan,100.64.0.0/30"
  ["core"]="br-core,"
  ["switch-l"]="br-sw-1"
  ["switch-r"]="br-sw-r"
)

declare -A local_net_files=(
    ["net-core-ur-lr"]="core-ur-lr"
    ["net-core-ur-rr"]="core-ur-rr"
    ["net-reserve-lr-rsw"]="reserve-lr-rsw"
    ["net-reserve-rr-sw"]="reserve-rr-lsw"
)