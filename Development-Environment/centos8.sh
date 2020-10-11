#!/usr/bin/env bash
#
# @name: centos7
# @discription: Generate CentOS 8.2-2004 Minimal Installation
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
export ISO_LOCAL="${ISO_DIR}/CentOS-8.2.2004-x86_64-minimal.iso"
export ISO_URL="http://mirror.digitalnova.at/CentOS/8.2.2004/isos/x86_64/CentOS-8.2.2004-x86_64-minimal.iso"
export ISO_CHECKSUM="sha256:47ab14778c823acae2ee6d365d76a9aed3f95bb8d0add23a06536b58bb5293c0"

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
