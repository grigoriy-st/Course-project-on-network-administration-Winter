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

clear_all_networks() {
  for net_name in ${!LOCAL_NET_FILES[@]}; do
    sudo virsh net-destroy "$net_name"
    sudo virsh net-undefine "$net_name"
  done
}

start_virsh_networks() {
  for net_file_name in ${!LOCAL_NET_FILES[@]}; do
      net_name="${LOCAL_NET_FILES[$net_file_name]}"
      net_filepath="../configs/networks/$net_file_name.xml"

      if ! sudo virsh net-define --file $net_filepath; then
        echo "Error in net-define $net_filepath";
        return 1
      fi

      if ! sudo virsh net-start "$net_name"; then
        echo "Error in net-start $net_name"
        return 1
      fi
      
      if ! sudo virsh net-autostart "$net_name"; then
        echo "Error in net-autostart $net_name";
        return 1
      fi


      if [[ $? -ne 0 ]]; then  
        echo "Network $net_name with int ${LOCAL_NET_FILES[$net_name]} is created!"
      fi
  done
}

clear_all_networks
start_virsh_networks