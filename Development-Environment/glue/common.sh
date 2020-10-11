#!/usr/bin/env bash
#
# @name: base
# @discription: Set common variables and functions.
#
# @exit:
#     0 on success
#     1 on failure


##############################################
#            Variables Block                 #
##############################################

# Various Directories
export KICKSTART_DIR="$SCRIPT_DIR/kickstart"
export ISO_DIR="${SCRIPT_DIR}/iso"
export VAGRANT_BASE_DIR="${SCRIPT_DIR}/vagrant"

# Packer Settings
export PACKER_SCRIPT_DIR="$SCRIPT_DIR/packer/scripts"
export PACKER_TEMPLATE_DIR="$SCRIPT_DIR/packer/templates"
export PACKER_BUILD_DIR="/var/tmp"
export PACKER_RESULT_DIR="$SCRIPT_DIR/finished"

##############################################
#            Function Block                  #
##############################################

########################################
# @name: script_init
# @discription: create framework for the script to use
# @global:
#       WORKING_DIR
#       LOGFILE
#       ISO_DIR
#       PACKER_RESULT_DIR
# @input: none
# @return: none
# @usage: script_init
########################################
function script_init() {
  local i=0
  local pl=()

  # if help is needed print it and quit
  if [[ $SCRIPT_ARGS == *"--help"* ]]
  then
    print_usage
    exit 0
  fi

  # if version is asked for, print it and quit
  if [[ $SCRIPT_ARGS == *"--version"* ]]
  then
    echo $VERSION
    exit 0
  fi

  # set up working dir and logfile
  if [ ! -d $WORKING_DIR ]; then mkdir $WORKING_DIR; fi
  touch $LOGFILE

  # work through all the remaining arguments
  for arg in "${SCRIPT_ARGS[@]}"
  do
    i=$(($i + 1))
    case "$arg" in
      --verbose)
        export DEBUG=0
      ;;
      --no-result)
        NO_RESULT=0
      ;;
      --vmware)
        pl+=("vmware")
      ;;
      --vbox)
        pl+=("virtualbox")
      ;;
      --libvirt)
        pl+=("libvirt")
      ;;
    esac
  done

  if [ ! -d $ISO_DIR ]; then mkdir -p $ISO_DIR; fi
  if [ ! -d $PACKER_RESULT_DIR ]; then mkdir -p $PACKER_RESULT_DIR; fi
  if [ $DEBUG -eq 0 ]
  then
    export HEADLESS='false'
    VERBOSE=0
  else
    export HEADLESS='true'
  fi

  if (( ${#pl[@]} ))
  then
    export PROVIDER_LIST=$pl
  else
    export PROVIDER_LIST=( "vmware" "virtualbox" "libvirt" )
  fi
}

########################################
# @name: remove_old
# @discription: remove files from a previous runs
# @global:
#       NAME
#       PROVIDER
#       RUN_OUTPUT
# @input:
#
# @return: none
# @usage: remove_old
########################################
function remove_old() {
  # Remove Existing Box
  if [ -f "${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}.box" ]
  then
    run_cmd "rm -rf ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}.box" "Remove Box file"
  fi

  # Remove Existing ova files
  if [ -f "${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}.ova" ]
  then
    run_cmd "rm -rf ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}.ova" "Remove ova file"
  fi

  # Kill all running VMs as it may intefere with other Virtualization Software (aka. Libvirt and VirtualBox don't like each other)
  vboxmanage list runningvms | sed -r 's/.*\{(.*)\}/\1/' | xargs -L1 -I {} VBoxManage controlvm {} poweroff &>/dev/null
  vmrun list | grep -v VMs: | xargs -I{} vmrun stop {} &>/dev/null
  killall -s 9 VirtualBox &>/dev/null
  killall -s 9 qemu-system-x86_64 &>/dev/null
  killall -s 9 vmware &>/dev/null
}

########################################
# @name: restore_kickstart
# @discription: check for backup file and restore them
# @global:
#       KICKSTART_DIR
#       KICKSTART_FILE
# @input: none
# @return: none
# @usage: restore_kickstart
########################################
function restore_kickstart() {
  if [ -f ${KICKSTART_DIR}/${KICKSTART_FILE}.bak ]
  then
    if [ -f ${KICKSTART_DIR}/${KICKSTART_FILE} ]
    then
      rm -rf ${KICKSTART_DIR}/${KICKSTART_FILE}
    fi
    mv ${KICKSTART_DIR}/${KICKSTART_FILE}.bak ${KICKSTART_DIR}/${KICKSTART_FILE}
  fi
}

########################################
# @name: run_packer
# @discription: run packer
# @global:
#       KICKSTART_DIR
#       KICKSTART_FILE
#       HOSTNAME
#       RHEL_USER
#       RHEL_PASS
# @input: none
# @return: none
# @usage: run_packer
########################################
function run_packer() {
  export TMPDIR=$PACKER_BUILD_DIR

  run_cmd "restore_kickstart" "Make sure there is no remaining Kickstart Backup file"
  run_cmd "cp ${KICKSTART_DIR}/${KICKSTART_FILE} ${KICKSTART_DIR}/${KICKSTART_FILE}.bak" "Backup Kickstart File"
  sed -i "s/localhost.local/${HOSTNAME}/g" ${KICKSTART_DIR}/${KICKSTART_FILE}
  sed -i "s/RHEL_USER/${RHEL_USER}/g" ${KICKSTART_DIR}/${KICKSTART_FILE}
  sed -i "s/RHEL_PASS/${RHEL_PASS}/g" ${KICKSTART_DIR}/${KICKSTART_FILE}
  print_success "Modifiy Kickstart File"

  run_cmd "packer build -only=$PROVIDER -parallel-builds=1 -force $PACKER_TEMPLATE_DIR/${NAME}.json" "Run Packer to build box"

  run_cmd "restore_kickstart" "Restore Kickstart File"
  run_cmd "rm -rf $SCRIPT_DIR/iso/*.iso.lock" "Remove ISO locks"
  run_cmd "rm -rf $SCRIPT_DIR/packer_cache" "Remove Packer Cache"
}


########################################
# @name: init_vagrant
# @discription: add box and init project directory
# @global:
#       NAME
#       VAGRANT_BOX_FILE
#       VAGRANT_PROJECT_DIR
# @input: none
# @return: none
# @usage: init_vagrant
########################################
function init_vagrant() {
  # Make sure packer created the box
  if [ -f "$VAGRANT_BOX_FILE" ]
  then
    # Add Box to vagrant
    run_cmd "vagrant box add $NAME $VAGRANT_BOX_FILE -f" "Add Box to vagrant"

    # Make sure there is a folder for our project
    print_success "Check Vagrant Project Directory"
    if [ ! -d "$VAGRANT_PROJECT_DIR" ]
    then
      mkdir -p "$VAGRANT_PROJECT_DIR"
      print_success "Create Vagrant Project Directory"
    else
      run_cmd "rm -rf $VAGRANT_PROJECT_DIR/*" "Clear Vagrant Project Directory"
    fi

    # Init Vagrant
    cd $VAGRANT_PROJECT_DIR
    run_cmd "vagrant init $NAME" "Initialize Vagrant Project"

    # Replace Vagrant File
    printf "%s\n" "${VAGRANTFILE[@]}" > Vagrantfile
    sed -i "s/^ENV\['VAGRANT_DEFAULT_PROVIDER'] = ''/ENV['VAGRANT_DEFAULT_PROVIDER'] = '${PROVIDER}'/g" Vagrantfile

    if [ "$PROVIDER" == "virtualbox" ]
    then
      sed -i '/config.vm.synced_folder/i \  config.vm.network "private_network", type: "dhcp"' Vagrantfile
    fi

    print_success "Replace Vagrant File"
    cd $SCRIPT_DIR

    # Add Synced Folder
    run_cmd "mkdir $VAGRANT_PROJECT_DIR/share" "Create Shared Folder"
  fi
}

########################################
# @name: check_iso
# @discription: Check ISO file and download if neccessary
# @global:
#       ISO_LOCAL
#       ISO_URL
# @input: none
# @return: none
# @usage: check_iso
########################################
function check_iso() {
  if [ ! -f $ISO_LOCAL ]
  then
    run_cmd "wget $ISO_URL -o $ISO_LOCAL" "Downloading ISO File"
  fi
}

########################################
# @name: script_run
# @discription: Run through all the providers
# @global:
#       NAME
#       PROVIDER_LIST
#       PACKER_RESULT_DIR
#       VAGRANT_BASE_DIR
# @input: none
# @return:
#       PROVIDER
#       VAGRANT_PROJECT_DIR
#       VAGRANT_BOX_FILE
# @usage: script_run
########################################

function script_run() {
  for v in "${PROVIDER_LIST[@]}"
  do
    ## Vagrant Setting depending on Provider
    export PROVIDER=$v
    export VAGRANT_PROJECT_DIR="${VAGRANT_BASE_DIR}/${NAME}_${PROVIDER}"
    export VAGRANT_BOX_FILE="${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}.box"

    print_section "${NAME} - ${PROVIDER}"
    remove_old
    run_packer

    if [ $PROVIDER != "vmware" ]; then init_vagrant; fi

    if [ $PROVIDER != "libvirt" ]
    then
      mv ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}/${NAME}_${PROVIDER}.ova ${PACKER_RESULT_DIR}
      rm -rf ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}
    else
      mv ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}/${NAME}_${PROVIDER} ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}.qcow2
      rm -rf ${PACKER_RESULT_DIR}/${NAME}_${PROVIDER}
    fi
  done

  if [ $ERROR_COUNT -gt 0 ]
  then
    if [ $NO_RESULT -ne 0 ]
    then
      print_section "Result"
      echo ""
      echo "${RED}There were some Errors during this run, please check the log at '$LOGFILE'${NORMAL}"
    fi
    echo "$(date +"[%F %T]") ${NAME}: FAILURE" >> $WORKING_DIR/summary.log
    exit 1
  else
    if [ $NO_RESULT -ne 0 ]
    then
      print_section "Result"
      echo ""
      echo "${GREEN}Everything went fine!"
      echo "Finished Files can be found at '$PACKER_RESULT_DIR'"
      echo "Base Vagrant Projects using those new boxes can be found at '$VAGRANT_BASE_DIR'${NORMAL}"
    fi
    echo "$(date +"[%F %T]") ${NAME}: SUCCESS" >> $WORKING_DIR/summary.log
    exit 0
  fi
}
