#version=RHEL8
# RedOS Kickstart configuration
# Platform: x86_64

# System language
lang ru_RU.UTF-8
keyboard ru

# Network
network --bootproto=dhcp --device=eth0 --onboot=on --hostname=redos-vm

# Root password
rootpw --iscrypted $6$BEycOAq.x8znuX4H$otJzGzCPO6.8R2ChfWrEefVSv0odezrWJflN5md7GSRfaBVSTZEKg2tQU97VqJwg4WlFptc7u2JAZ4na/RKdc.

# User creation
user --name=admin --groups=wheel --password=$6$BEycOAq.x8znuX4H$otJzGzCPO6.8R2ChfWrEefVSv0odezrWJflN5md7GSRfaBVSTZEKg2tQU97VqJwg4WlFptc7u2JAZ4na/RKdc.
 --iscrypted

# System timezone
timezone Asia/Omsk

# Partitioning
part /boot --fstype=xfs --size=1024
part pv.01 --size=1 --grow
volgroup vg_system pv.01
logvol / --vgname=vg_system --size=10240 --name=root
logvol swap --vgname=vg_system --size=2048 --name=swap
logvol /home --vgname=vg_system --size=5120 --name=home

# SELinux
selinux --enforcing
firewall --enabled --service=ssh

# Services
services --enabled=sshd,NetworkManager,chronyd

# Installation logging
logging --level=info

# Packages
%packages
@^minimal-environment
@standard
vim
tmux
zsh
wget
curl
git
openssh-server
cloud-init
qemu-guest-agent
-iwl*firmware
%end

# Post-installation scripts
%post
# Enable and start services
systemctl enable sshd
systemctl enable qemu-guest-agent
systemctl enable cloud-init

# Update system
dnf update -y

# Configure SSH
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

systemctl disable firewalld

# Motd
cat > /etc/motd << EOF
Welcome to RedOS
Scripts are working, you're resting!
EOF

%end

%pre
# Pre-installation setup
echo "Starting RedOS installation"
%end

reboot