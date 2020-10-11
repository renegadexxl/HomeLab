#!/usr/bin/env bash
#
# @name: testing
# @discription: Check a vagrant file and box for basic functionality
#
# @exit:
#     0 on success
#     1 on failure

# Current Directory
CURRENT_DIR=$(pwd)
TARGET_DIR=$(pwd)

# work through all the remaining arguments
for arg in "$@"
do
  i=$(($i + 1))
  case "$arg" in
    *)
      if [ -d $arg ]; then if [ -f "$arg/Vagrantfile" ]
        then
          TARGET_DIR=$arg
        fi; fi
  esac
done

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

return=0

cd $TARGET_DIR

PROVIDER="$(cat Vagrantfile | grep "VAGRANT_DEFAULT_PROVIDER" | cut -d= -f2 | cut -d\' -f2)"


echo 'testing' > share/test.txt

printf "${YELLOW}vagrant validate${NORMAL} "
if [ $return -eq 0 ]; then if ! vagrant validate &>/dev/null
then
  return=1
  printf "${RED}$FAIL${NORMAL}\n"
else
  printf "${GREEN}$SUCCESS${NORMAL}\n"
fi; fi

printf "${YELLOW}vagrant up${NORMAL} "
if ! vagrant up &>/dev/null
then
  return=1
  printf "${RED}$FAIL${NORMAL}\n"
else
  printf "${GREEN}$SUCCESS${NORMAL}\n"
fi

printf "${YELLOW}ping${NORMAL} "
if [ $return -eq 0 ]; then if ! vagrant ssh -- -t 'ping -c1 www.google.com' &>/dev/null
then
  return=1
  printf "${RED}$FAIL${NORMAL}\n"
else
  printf "${GREEN}$SUCCESS${NORMAL}\n"
fi; fi

printf "${YELLOW}yum${NORMAL} "
if [ $return -eq 0 ]; then if ! vagrant ssh -- -t 'yum whatprovides mc' &>/dev/null
then
  return=1
  printf "${RED}$FAIL${NORMAL}\n"
else
  printf "${GREEN}$SUCCESS${NORMAL}\n"
fi; fi

printf "${YELLOW}nfs${NORMAL} "
if [ $return -eq 0 ]; then if ! vagrant ssh -- -t 'cat /vagrant/test.txt' &>/dev/null
then
  return=1
  printf "${RED}$FAIL${NORMAL}\n"
else
  printf "${GREEN}$SUCCESS${NORMAL}\n"
fi; fi

printf "${YELLOW}guest agent${NORMAL} "
case "$PROVIDER" in
  'libvirt')
    if [ $return -eq 0 ]; then if ! vagrant ssh -- -t 'rpm -qa qemu-guest-agent' &>/dev/null
    then
      return=1
      printf "${RED}$FAIL${NORMAL}\n"
    else
      printf "${GREEN}$SUCCESS${NORMAL}\n"
    fi; fi
  ;;
  'virtualbox')
    if [ $return -eq 0 ]; then if ! vagrant ssh -- -t 'systemctl status vboxadd-service' &>/dev/null
    then
      return=1
      printf "${RED}$FAIL${NORMAL}\n"
    else
      printf "${GREEN}$SUCCESS${NORMAL}\n"
    fi; fi
  ;;
esac

printf "${YELLOW}vagrant destroy${NORMAL} "
if ! vagrant destroy -f &>/dev/null
then
  return=1
  printf "${RED}$FAIL${NORMAL}\n"
else
  printf "${GREEN}$SUCCESS${NORMAL}\n"
fi

rm -rf share/test.txt
cd $CURRENT_DIR
exit $return
