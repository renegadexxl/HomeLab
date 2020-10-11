#!/usr/bin/env bash
#
# @name: pipline
# @discription: Create all the images
#
# @exit:
#     0 on success
#     1 on failure

me=$(basename $0)
list=($(ls -d *.sh | grep -v $me))

for item in ${list[@]}
do
  bash $item $@ --no-result
done
