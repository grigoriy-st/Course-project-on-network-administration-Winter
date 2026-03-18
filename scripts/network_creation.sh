#!/bin/bash

declare -A network_params=(
  # network_name : bridge_name
  ["wan"]="br-wan"
  ["core"]="br-core"
  ["switch-l"]="br-sw-1"
  ["switch-r"]="br-sw-r"
)

# network files creation
create_network_files() {
  for net_name in "${!network_params[@]}"; do
    cat > /tmp/$net_name-network.xml << EOF
      <network>
        <name>$net_name</name>
        <forward mode='bridge'/>
        <bridge name='${netowrk_params[$net_name]}'/>
        <virtualport type='openvswitch'/>
      </network>
EOF
    echo "Network $net_name is started!"
  done
}

# defining and starting networks
start_networks() {
  for i in ${network_names[@]}; do
      sudo virsh net-define "/tmp/${i}-network.xml"
      sudo virsh net-start "$i"
      sudo virsh net-autostart "$i"
  done
}

create_network_files
start_networks