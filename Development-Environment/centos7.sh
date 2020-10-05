#!/bin/bash
NAME=$(basename $0 .sh)
PROVIDER="libvirt"

# Replace Vagrantfile
if [ -d "vagrant/${NAME}" ]
then
  cat <<EOF > Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :
ENV['VAGRANT_DEFAULT_PROVIDER'] = '${PROVIDER}'

Vagrant.configure("2") do |config|
  config.vm.box = "${NAME}"
  config.vm.synced_folder "share", "/vagrant", type: "nfs", nfs_udp: false, nfs_version: 3
end
EOF
fi
