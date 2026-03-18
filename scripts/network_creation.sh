#!/bin/bash

source vars.sh

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

# create_network_files
# start_networks

start_virsh_networks() {
  for net_file_name in ${!local_net_files[@]}; do
      net_name="${local_net_files[$net_file_name]}"
      
      sudo virsh net-define "../configs/networks/$net_file_name.xml"
      sudo virsh net-start "$net_name"
      sudo virsh net-autostart "$net_name"

      if [[ $? -eq 0 ]]; then  
        echo "Network $net_name with int ${local_net_files[$net_name]} is created!"
      fi
  done
}

start_virsh_networks