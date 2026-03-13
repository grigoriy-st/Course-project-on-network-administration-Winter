#!/bin/bash

network_names=("wan" "core" "switch-l" "switch-r")

# WAN
cat > /tmp/wan-network.xml << EOF
<network>
  <name>wan</name>
  <forward mode='bridge'/>
  <bridge name='br-wan'/>
  <virtualport type='openvswitch'/>
</network>
EOF

# core
cat > /tmp/core-network.xml << EOF
<network>
  <name>core</name>
  <forward mode='bridge'/>
  <bridge name='br-core'/>
  <virtualport type='openvswitch'/>
</network>
EOF

# switch-l
cat > /tmp/switch-l-network.xml << EOF
<network>
  <name>switch-l</name>
  <forward mode='bridge'/>
  <bridge name='br-sw-l'/>
  <virtualport type='openvswitch'/>
</network>
EOF

# switch-r
cat > /tmp/switch-r-network.xml << EOF
<network>
  <name>switch-r</name>
  <forward mode='bridge'/>
  <bridge name='br-sw-r'/>
  <virtualport type='openvswitch'/>
</network>
EOF


# Запуск сетей

for i in ${network_names[@]}; do
    sudo virsh net-define "/tmp/$i-network.xml"
    sudo virsh net-start "$i"
    sudo virsh net-autostart "$i"
done
