#!/bin/env bash

# Remove Existing Box
if [ -f "finished/${NAME}_${PROVIDER}.box" ]
then
  rm -rf "finished/${NAME}_${PROVIDER}.box"
fi

if vagrant box list | grep $NAME
then
  vagrant box remove $NAME -f
fi

# Prevent Packer from running out of space on small /tmp partitions then Create the vagrant box
TMPDIR=/var/tmp packer build packer/templates/${NAME}.json

# Remove leftover files from packer
rm -rf packer_cache
rm -rf iso/*.iso.lock

# Get ready for vagrant
if [ ! -d "vagrant/${NAME}" ]; then mkdir -p "vagrant/${NAME}"; fi

# Make sure packer created the box
if [ -f "finished/${NAME}_${PROVIDER}.box" ]
then
  # Add Box to vagrant
  vagrant box add ${NAME} finished/${NAME}_${PROVIDER}.box

  # Init Vagrant
  cd vagrant/${NAME}
  vagrant init ${NAME}

  # Add Synced Folder
  mkdir share
fi
