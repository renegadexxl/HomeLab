# Turning on text-mode installation (little quicker than GUI)
text

# Setting up authentication and keyboard
authselect --enableshadow --passalgo=sha512
keyboard --xlayouts='at'

# Installation source
cdrom

# Setting up language to English
lang en-US.UTF-8

# Setting up network interface to DHCP
network --bootproto=dhcp --ipv6=auto --hostname=localhost.local --activate

# Root password (remember that plaintext only for information purposes)
rootpw --iscrypted $6$WGVzNmQnyiNJlMsC$QM3rSfpq8WapQXnaUBd3YON6ZYVPPKWfneSDF4tM9axQtQ8DUR2fnwGoQ.Aizvb5IVGWoPsKKmf74jGYRoH7z1

# Vagrant user
user --groups=wheel --name=vagrant --password="vagrant" --gecos="vagrant"


# Setting up firewall and enabling SSH for remote management
firewall --enabled --service=ssh

# Setting timezone
timezone Europe/Vienna --isUtc

# Setting up Security-Enhanced Linux into enforcing
selinux --enforcing

# Setting up MBR
bootloader --location=mbr

# Setting up Logical Volume Manager and autopartitioning
clearpart --all --initlabel
autopart --type=lvm

# Eject cdrom and reboot
reboot --eject

# Installing only packages for minimal install
%packages
@Core
chrony
%end

%post --interpreter=/bin/bash

# update the system
dnf -y update

# add epel repo
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

###
# vagrant settings
###

# Setup default sudoers
cat <<EOF >> /etc/sudoers
Defaults !requiretty
root ALL=(ALL) ALL
vagrant ALL=(ALL) NOPASSWD: ALL
EOF

%end
