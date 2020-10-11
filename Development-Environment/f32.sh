#!/usr/bin/env bash
#
# @name: centos7
# @discription: Generate Fedora 32 Minimal Installation
#               for vmware, virtualbox, libvirt and vagrant.

. $(dirname $(readlink -f $0))/glue/base.sh
. $(dirname $(readlink -f $0))/glue/common.sh

##############################################
#            Variables Block                 #
##############################################

# Base Name to use for generation
export NAME=$(basename $0 .sh)

# Debug Mode
#   0 on
#   1 off
export DEBUG=1

# Kickstart Settings
export KICKSTART_FILE="$NAME.ks"
export HOSTNAME="${NAME}.testing.local"

# ISO Settings
export ISO_LOCAL="${ISO_DIR}/Fedora-Everything-netinst-x86_64-32-1.6.iso"
export ISO_URL="https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-32-1.6.iso"
export ISO_CHECKSUM="sha256:7ce4bb4b3e77e2b0c74e5aa3478eef1c26104a7040701f9de3d3a2cb06f6b05d"

# VM Settings
export RAM="4096"
export CPUS="4"
export HDD_SIZE="30720"

# Vagrant Settings
export VAGRANTFILE=(
  "# -*- mode: ruby -*-"
  "# vi: set ft=ruby :"
  "ENV['VAGRANT_DEFAULT_PROVIDER'] = ''"
  ""
  "Vagrant.configure('2') do |config|"
  "  config.vm.box = '${NAME}'"
  "  config.vm.synced_folder 'share', '/vagrant', type: 'nfs', nfs_udp: false, nfs_version: 3"
  "end"
)

##############################################
#              Script Logic                  #
##############################################

script_init
check_iso
script_run
