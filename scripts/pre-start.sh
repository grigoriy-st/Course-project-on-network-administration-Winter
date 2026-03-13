#!/bin/bash

sudo systemctl enable --now libvirtd
sudo systemctl enable --now ovsdb-server
sudo systemctl enable --now ovs-vswitchd

sudo usermod -aG libvirt,kvm $(whoami)

