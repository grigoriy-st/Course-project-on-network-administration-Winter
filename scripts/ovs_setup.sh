#!/bin/bash

clean_old_ports() {
    for br in OMS-LSW OMS-RSW; do
        for port in lsw-pc1 lsw-pc2 rsw-pc3 rsw-pc4 rsw-pc5; do
            sudo ovs-vsctl del-port $br $port 2>/dev/null
        done
    done
    
    for port in lsw-pc1 lsw-pc2 rsw-pc3 rsw-pc4 rsw-pc5; do
        sudo ip link delete $port 2>/dev/null
    done  
}

create_needed_interfaces() {
    # sudo ovs-vsctl add-br vbr-lr-lsw
    :
    # sudo ip link add name vbr-lr-lsw type bridge
    # sudo ip link add name vbr-rr-rsw type bridge
    # sudo ovs-vsctl add-port OMS-RSW vbr-rr-rsw -- set Interface vbr-rr-rsw type=internal
    # sudo ovs-vsctl add-port OMS-LSW vbr-lr-lsw -- set Interface vbr-lr-lsw type=internal

    # sudo ip link set dev vbr-rr-rsw up
    # sudo ip link set dev vbr-lr-lsw up
}

create_oms_lsw() {
    sudo ovs-vsctl add-br OMS-LSW

    # OMS-D1-LR -> OMS-LSW (trunk) Auto creation
    # sudo ovs-vsctl add-port OMS-LSW vbr-lr-lsw
    # sudo ovs-vsctl set port vbr-lr-lsw vlan_mode=trunk trunks=10,99
    # sudo ovs-vsctl set port OMS-LSW vlan_mode=trunk trunks=10,99
    sudo ovs-vsctl add-port OMS-LSW lr-lsw -- set Interface lr-lsw type=internal
    sudo ovs-vsctl set port lr-lsw vlan_mode=trunk
    sudo ovs-vsctl set port lr-lsw trunks=10,99

    sudo ip link set lr-lsw up
    # OMS-LSW -> PC1 (access VLAN 10)
    sudo ovs-vsctl add-port OMS-LSW lsw-pc1 -- set Interface lsw-pc1 type=internal
    sudo ovs-vsctl set port lsw-pc1 vlan_mode=access tag=10
    sudo ip link set lsw-pc1 up
    sudo ip addr add 10.0.10.254/24 dev lsw-pc1 2>/dev/null || true

    # OMS-LSW -> PC2 (access VLAN 99)
    sudo ovs-vsctl add-port OMS-LSW lsw-pc2 -- set Interface lsw-pc2 type=internal
    sudo ovs-vsctl set port lsw-pc2 vlan_mode=access tag=99
    sudo ip link set lsw-pc2 up
    sudo ip addr add 10.0.99.254/24 dev lsw-pc2 2>/dev/null || true
}


create_oms_rsw() {
    sudo ovs-vsctl add-br OMS-RSW

    # OMS-D2-RR -> OMS-RSW (trunk VLAN 30,40,50)
    # sudo ovs-vsctl add-port OMS-RSW vbr-rr-rsw
    sudo ovs-vsctl add-port OMS-RSW rr-rsw -- set Interface rr-rsw type=internal
    sudo ovs-vsctl set port rr-rsw vlan_mode=trunk
    sudo ovs-vsctl set port rr-rsw trunks=30,40,50
    sudo ip link set rr-rsw up

    # OMS-RSW -> PC3 (access VLAN 30)
    sudo ovs-vsctl add-port OMS-RSW rsw-pc3 -- set Interface rsw-pc3 type=internal
    sudo ovs-vsctl set port rsw-pc3 vlan_mode=access tag=30
    sudo ip link set rsw-pc3 up
    sudo ip addr add 10.0.30.254/24 dev rsw-pc3 2>/dev/null || true

    # OMS-RSW -> PC4 (access VLAN 40)
    sudo ovs-vsctl add-port OMS-RSW rsw-pc4 -- set Interface rsw-pc4 type=internal
    sudo ovs-vsctl set port rsw-pc4 vlan_mode=access tag=40
    sudo ip link set rsw-pc4 up
    sudo ip addr add 10.0.40.254/24 dev rsw-pc4 2>/dev/null || true


    # OMS-RSW -> PC5 (access VLAN 50)
    sudo ovs-vsctl add-port OMS-RSW rsw-pc5 -- set Interface rsw-pc5 type=internal
    sudo ovs-vsctl set port rsw-pc5 vlan_mode=access tag=50  # Исправлено: было rsw-pc4
    sudo ip link set rsw-pc5 up
    sudo ip addr add 10.0.50.254/24 dev rsw-pc5 2>/dev/null || true
    # other ...
}

clean_old_ports
create_needed_interfaces
create_oms_lsw # uncoment to execute
sleep 5
create_oms_rsw
