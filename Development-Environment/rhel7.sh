#!/usr/bin/env bash
#
# @name: centos7
# @discription: RHEL 7.9 Minimal Installation
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
export ISO_LOCAL="${ISO_DIR}/rhel-server-7.9-x86_64-dvd.iso"
export ISO_URL=""
export ISO_CHECKSUM="sha256:19d653ce2f04f202e79773a0cbeda82070e7527557e814ebbce658773fbe8191"

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
