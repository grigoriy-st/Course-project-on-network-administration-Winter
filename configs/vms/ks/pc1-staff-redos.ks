cat > "$KICKSTARTER_DIR/pc1-staff-redos.ks" << 'EOF'
#version=RHEL8
url --url="file:///run/install/repo"
text
lang en_US.UTF-8
keyboard us
timezone Europe/Moscow --isUtc
network --bootproto=dhcp
rootpw --plaintext redos123
user --plaintext --name=admin --password=admin123
bootloader --location=mbr
zerombr
clearpart --all --initlabel
autopart
reboot
%packages
@^minimal-environment
%end
EOF