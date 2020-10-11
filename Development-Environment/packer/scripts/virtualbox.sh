# Install Guest Additions Prerequisites
yum -y install perl gcc dkms kernel-devel kernel-headers make bzip2

# Mount ISO
mount -t iso9660 -o loop VBoxGuestAdditions.iso /mnt

# Install Guest Additions
/mnt/VBoxLinuxAdditions.run

# Clean Up
umount /mnt
rm -rf VBoxGuestAdditions.iso
