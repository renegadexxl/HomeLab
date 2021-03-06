#!/usr/bin/env bash
#
# @name: base
# @discription: Set basic variables and functions.
#
# @exit:
#     0 on success
#     1 on failure

##############################################
#            Variables Block                 #
##############################################

###
# Define Variables required for running the script
###

## Make sure the PATH variable is set and contains all the relevant directories
if [ -z "${PATH-}" ]; then export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/bin; fi
if ! echo "${PATH-}" | grep -q "/usr/local/bin"; then export PATH=/usr/local/bin:$PATH; fi
if ! echo "${PATH-}" | grep -q "/usr/sbin"; then export PATH=/usr/sbin:$PATH; fi
if ! echo "${PATH-}" | grep -q "/usr/bin"; then export PATH=/usr/bin:$PATH; fi
if ! echo "${PATH-}" | grep -q "/bin"; then export PATH=/bin:$PATH; fi

## get information about the script
SCRIPT_NAME=$(basename $0)
SCRIPT_FILE=$(readlink -f $SCRIPT_NAME)
SCRIPT_DIR=$(dirname $SCRIPT_FILE)
ELEVATED=$(if [ "$EUID" -eq 0 ]; then echo 0; else echo 1; fi)

## get username under which the script is being executed
SCRIPT_USER=$(if [ "$EUID" -ne 0 ]; then whoami; else echo ${SUDO_USER}; fi)
SCRIPT_USER=$(if [ "$SCRIPT_USER" == "" ]; then whoami; else echo ${SCRIPT_USER}; fi)

## get home directory of the user
USER_HOME=$(getent passwd $SCRIPT_USER | cut -d: -f6)

## set working directory for the files generated by the script
WORKING_DIR="${SCRIPT_DIR}/log"

## set log file
LOGFILE="${WORKING_DIR}/$(basename $SCRIPT_NAME .sh).log"

## initiate internal error count
ERROR_COUNT=0

## set verion
VERSION="1.0.0"

## get script Arguments
SCRIPT_ARGS=( "$@" )

## Set verbose output/debug mode to disabled
VERBOSE=1

## Set Script to display Result
NO_RESULT=1

###
# Define Variables to make the Script Output look pretty
###

## Colors
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

## Characters
SUCCESS="\xE2\x9C\x94"
FAIL="\xE2\x9D\x8C"

##############################################
#            Function Block                  #
##############################################

###
# Common Functions
###

########################################
# @name: logging
# @discription: write text into log file
# @input: Text Message to write to log file
# @global:
#       LOGFILE
# @return: none
# @usage: print_usage
########################################
function logging() {
  local log_time=$(date +"[%F %T]")
  echo "${log_time} ${@}" >> $LOGFILE
}

########################################
# @name: print_usage
# @discription: display help message
# @global:
#
# @input: none
# @return: none
# @usage: print_usage
########################################
function print_usage() {
  local message=(
    "Script to setup a Workstation."
    "Usage: ${0} [options] [arguments]"
    ""
    "Options:"
    "  --help                             Print help."
    "  --version                          Show version number."
    "  --verbose                          Show full output of commands used inside the script."
    "  --no-result                        Don't show the result text at the end"
    "  --vmware                           Run vmware build. Resulting in ova file"
    "  --vbox                             Run virutalbox build. Resulting in ova file, vagrant box and vagrant test directory"
    "  --libvirt                          Run libvirt build. Resulting in qcow2 file, vagrant box and vagrant test directory"
    )

  printf "%s\n" "${message[@]}"
}

# @name: print_section
# @discription: display section header
# @global:
#       CYAN
#       NORMAL
# @input: Text Message to display
# @return: none
# @usage: print_section "$text"
function print_section() {
  printf "${CYAN}\n$@\n"
  let width=$(tput cols)-7
  printf "%${width}s"|tr ' ' '='
  printf "${NORMAL}\n"
}

# @name: print_command
# @discription: display command for verbose
# @global:
#       YELLOW
#       NORMAL
# @input: Text Message to display
# @return: none
# @usage: print_command "$text"
function print_command() {
  printf "${YELLOW}\n$@\n"
  let width=$(tput cols)-7
  printf "%${width}s"|tr ' ' '-'
  printf "${NORMAL}\n"
}

# @name: print_success
# @discription: display and log success
# @global:
#       GREEN
#       NORMAL
#       SUCCESS
# @input: Text Message to display
# @return: none
# @usage: print_success "$text"
function print_success() {
  local result="[${GREEN}${SUCCESS}${NORMAL}]"
  let offset=$(tput cols)-${#1}-10
  printf "\r$@%${offset}s${result}\n"
  logging "OK: $@"
}

########################################
# @name: print_ok
# @discription: display and log failure
# @global:
#       RED
#       NORMAL
#       FAIL
#       ERROR_COUNT
# @input: Text Message to display
# @return: increase ERROR_COUNT
# @usage: print_fail "$text"
########################################
function print_fail() {
  local result="[${RED}${FAIL}${NORMAL}]"
  let offset=$(tput cols)-${#1}-10
  printf "\r$@%${offset}s${result}\n"
  logging "FAIL: $@"
  export ERROR_COUNT=$(($ERROR_COUNT + 1))
}

########################################
# @name: run_silent
# @discription: run bash command without displaying status
# @global:
#       VERBOSE
#       WORKING_DIR
# @input:
#       Shell Command
#       Text Message to display
# @return:
#       RUN_STATUS      0 on success
#                       1 on failure
#       RUN_OUTPUT      Command Output
#       RUN_ERROR       Command Error message
# @usage: run_silent "$command" "$message"
########################################
function run_silent() {
  local cmd="$1"
  local txt="$2"
  touch ${WORKING_DIR}/output.tmp
  touch ${WORKING_DIR}/error.tmp

  if [ $VERBOSE -eq 0 ]
  then
    print_command "$cmd"
    exec 3> >(tee ${WORKING_DIR}/output.tmp)
    eval $cmd >&3 2>/tmp/error.tmp
  else
    local spin='-\|/'
    local i=0

    (eval $cmd 2>/tmp/error.tmp 1>${WORKING_DIR}/output.tmp) &
    local pid=$!

    let offset=$(tput cols)-${#txt}-10

    while kill -0 $pid 2>/dev/null
    do
      local i=$(( (i+1) %4 ))
  	  let offset=$(tput cols)-${#txt}-10
  	  printf "\r${txt}%${offset}s[${spin:$i:1}]"
      sleep .1
    done

    wait $pid
  fi

  RUN_STATUS=$?
  RUN_OUTPUT="$(cat ${WORKING_DIR}/output.tmp)"
  rm -rf ${WORKING_DIR}/output.tmp
  RUN_ERROR="$(cat ${WORKING_DIR}/error.tmp)"
  rm -rf ${WORKING_DIR}/error.tmp

  return $RUN_STATUS
}

########################################
# @name: run_cmd
# @discription: run bash command and display status
# @global: none
# @input:
#       Shell Command
#       Text Message to display
# @return: none
# @usage: run_cmd "$command" "$message"
########################################
function run_cmd() {
  local cmd="$1"
  local txt="$2"

  if run_silent "$cmd" "$txt"
  then
    print_success "${txt}"
  else
    print_fail "${txt}"
    logging "COMMAND: ${cmd}"
    logging "COMMAND OUTPUT: $RUN_OUTPUT"
    logging "ERROR OUTPUT: $RUN_ERROR"
  fi
}

########################################
# @name: run_success
# @discription: run bash command and display success no matter what
# @global: none
# @input:
#       Shell Command
#       Text Message to display
# @return: none
# @usage: run_success "$command" "$message"
########################################
function run_success() {
  local cmd="$1"
  local txt="$2"

  run_silent "$cmd" "$txt"
  print_success "${txt}"
  return $RUN_STATUS
}
