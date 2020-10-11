#!/usr/bin/env bash
#
# @name: centos7
# @discription: Generate RHEL 8.2 Minimal Installation
#               for vmware, virtualbox, libvirt and vagrant.

. $(dirname $(readlink -f $0))/glue/base.sh
. $(dirname $(readlink -f $0))/glue/common.sh
. $(dirname $(readlink -f $0))/glue/rhel.pwd

##############################################
#            Variables Block                 #
##############################################

# Base Name to use for generation of VMs
export NAME=$(basename $0 .sh)

# Debug Mode
#   0 on
#   1 off
export DEBUG=1

# Kickstart Settings
export KICKSTART_FILE="$NAME.ks"
export HOSTNAME="${NAME}.testing.local"

# ISO Settings
export ISO_LOCAL="${ISO_DIR}/rhel-8.2-x86_64-dvd.iso"
export ISO_URL=""
export ISO_CHECKSUM="sha256:7fdfed9c7cced4e526a362e64ed06bcdc6ce0394a98625a40e7d05db29bf7b86"

# VM Settings
export RAM="4096"
export CPUS="4"
export HDD_SIZE="30720"

# Vagrant Settings
export VAGRANT_BASE_DIR="${SCRIPT_DIR}/vagrant"
export VAGRANTFILE=(
  "# -*- mode: ruby -*-"
  "# vi: set ft=ruby :"
  "ENV['VAGRANT_DEFAULT_PROVIDER'] = ''"
  ""
  "Vagrant.configure('2') do |config|"
  ""
  "  if Vagrant.has_plugin?('vagrant-registration')"
  "    config.registration.username = '${RHEL_USER}'"
  "    config.registration.password = '${RHEL_PASS}'"
  "  end"
  ""
  "  config.vm.box = '${NAME}'"
  "  config.vm.synced_folder 'share', '/vagrant', type: 'nfs', nfs_udp: false, nfs_version: 3"
  "end"
)

##############################################
#              Script Logic                  #
##############################################

script_init
script_run
