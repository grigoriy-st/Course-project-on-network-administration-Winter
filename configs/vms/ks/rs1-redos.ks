#version=RHEL8
# RedOS Kickstart configuration
url --url="file:///run/install/repo"
text

lang ru_RU.UTF-8
keyboard ru
timezone Asia/Omsk --isUtc

network --bootproto=dhcp --device=eth0 --onboot=on --hostname=oms-rs1

rootpw --iscrypted $6$BEycOAq.x8znuX4H$otJzGzCPO6.8R2ChfWrEefVSv0odezrWJflN5md7GSRfaBVSTZEKg2tQU97VqJwg4WlFptc7u2JAZ4na/RKdc.
user --iscrypted --name=admin --groups=wheel --password=$6$BEycOAq.x8znuX4H$otJzGzCPO6.8R2ChfWrEefVSv0odezrWJflN5md7GSRfaBVSTZEKg2tQU97VqJwg4WlFptc7u2JAZ4na/RKdc.

bootloader --location=mbr
zerombr
clearpart --all --initlabel
autopart --type=plain

selinux --enforcing
firewall --enabled --service=ssh
services --enabled=sshd,NetworkManager

%packages
@^minimal-environment
@standard
ansible
python3
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

%post
systemctl enable sshd qemu-guest-agent cloud-init
systemctl set-default multi-user.target

cat >> /etc/ssh/sshd_config << EOF
PermitRootLogin yes
PasswordAuthentication yes
EOF

hostnamectl set-hostname oms-rs1

cat > /etc/motd << 'EOF'
Welcome to RedOS - oms-rs1
Scripts are working, you're resting!
EOF

echo "RedOS installation completed successfully" > /root/install.log
%end

reboot
EOF