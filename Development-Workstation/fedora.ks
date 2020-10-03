#version=F32

# URLs and REPOs
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-32&arch=x86_64"


# Use graphical install
graphical
# Keyboard layouts
keyboard --xlayouts='at'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=dhcp --activate
network  --hostname=dev.testing.local

# Run the Setup Agent on first boot
firstboot --enable

# System services
services --enabled=chronyd,sshd,NetworkManager

ignoredisk --only-use=sda
autopart
# Partition clearing information
clearpart --all --initlabel

# System timezone
timezone Europe/Vienna --isUtc --ntpservers=0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org

# Root password
rootpw --iscrypted $6$WGVzNmQnyiNJlMsC$QM3rSfpq8WapQXnaUBd3YON6ZYVPPKWfneSDF4tM9axQtQ8DUR2fnwGoQ.Aizvb5IVGWoPsKKmf74jGYRoH7z1
user --groups=wheel --name=renegadexxl --password=$6$jDVRdPj0zCPJMsi2$iFjy21st4ckVbv/Tuyx4VQvKePQcFgtifEuHwS4gMJB/T.59zgKXDpnHjotSE/RrnKPbgCvYcBtx8EwgG9PYq1 --iscrypted --gecos="renegadexxl"

%packages
# Base
@base-x
@guest-desktop-agents
@standard
@core
@fonts
@input-methods
@dial-up
@multimedia
@hardware-support
@printing

# Explicitly specified here:
# <notting> walters: because otherwise dependency loops cause yum issues.
kernel
kernel-modules
kernel-modules-extra



# Cinnamon Spin
fedora-release-cinnamon
@networkmanager-submodules
@cinnamon-desktop
@libreoffice
parole
rhythmbox

# extra backgrounds
f32-backgrounds-extras-gnome

# Basic Tools of the trade
vim
wget
mc
tmux
curl
NetworkManager-tui
ssm
bind-utils
net-tools


%end

%addon com_redhat_kdump --disable --reserve-mb='128'

%end

%anaconda
# --minquality does not seem to work
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end

%post --log=/var/log/kickstart_post.log
dnf -y update
mkdir /var/my_scripts
chmod 777 /var/my_scripts
wget http://192.168.8.121/setup.sh -O /var/my_scripts/setup.sh
chmod 777 /var/my_scripts/setup.sh
(crontab -l; echo "@reboot /var/my_scripts/setup.sh --user renegadexxl";) | crontab -
%end

# Reboot After Installation
reboot --eject
