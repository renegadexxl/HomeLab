#!/usr/bin/env bash
#
# Setup script for a freshly installed System.
#
# Exit values:
#     0 on success
#     1 on failure

###############################################################################
# This Script takes a freshly installed RHEL/CENTOS 8 or Fedora System and    #
# installs all the Tools                                                      #
###############################################################################

###
# Define Variables required for running the script
###

## Make sure the PATH variable is set and contains all the relevant directories
if [ -z "${PATH-}" ]; then export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/bin; fi
if ! echo "${PATH-}" | grep -q "/usr/local/bin"; then export PATH=/usr/local/bin:$PATH; fi
if ! echo "${PATH-}" | grep -q "/usr/sbin"; then export PATH=/usr/sbin:$PATH; fi
if ! echo "${PATH-}" | grep -q "/usr/bin"; then export PATH=/usr/bin:$PATH; fi
if ! echo "${PATH-}" | grep -q "/bin"; then export PATH=/bin:$PATH; fi

## basic script settings
SCRIPTNAME=$(basename $BASH_SOURCE)
SCRIPTFILE=$(readlink -f $BASH_SOURCE)
SCRIPT_DIR=$(dirname $SCRIPTFILE)
LOGFILE="/var/log/${SCRIPTNAME}.log"

## define default settings for various Options
ONLY_USER=0
NO_USER=0
SCRIPT_USER=$(if [ "$EUID" -ne 0 ]; then whoami; else echo ${SUDO_USER}; fi)
SCRIPT_USER=$(if [ "$SCRIPT_USER" == "" ]; then whoami; else echo ${SCRIPT_USER}; fi)
USER_HOME=$(getent passwd $SCRIPT_USER | cut -d: -f6)
export ERROR_COUNT=0

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
# Messages for the User.
###

# Write to Log
function logging ()
{
  local log_time=$(date +"[%F %T]")
  echo "${log_time} ${@}" >> $LOGFILE
}

## Display Help
function usage
{
    local message=(
      "Script to setup a Workstation."
      "Usage: ${0} [options] [arguments]"
      ""
      "Options:"
      "  --help, -h                         Print help."
      "  --no-usersettings                  Skip setting up the user dot files and group membership."
      "  --only-usersettings                Don't install anything, just configure the current user."
      "  --user <username>                  Install Settings under a different User not the one you are logged in as."
    )

    printf "%s\n" "${message[@]}"
}

## Seperate Output into Sections by putting up a Header
function section ()
{
  printf "${CYAN}\n$1\n"
  let width=$(tput cols)-7
  printf "%${width}s"|tr ' ' '='
  printf "${NORMAL}\n"
}

## Tell the User we succeeded
function ok_line ()
{
  local result="[${GREEN}${SUCCESS}${NORMAL}]"
  let offset=$(tput cols)-${#1}-10
  printf "\r$@%${offset}s${result}\n"
  logging "OK: $@"
}

## Tell the User we screwed it up
function fail_line ()
{
  local result="[${GREEN}${FAIL}${NORMAL}]"
  let offset=$(tput cols)-${#1}-10
  printf "\r$@%${offset}s${result}\n"
  logging "FAIL: $@"
  export ERROR_COUNT=$(($ERROR_COUNT + 1))
}

## Progress Indicator
function progress ()
{
  local txt=$1
  shift
  local cmd=("$@")

  LAST_OUTPUT=$("${cmd[@]}" 2>/tmp/error.tmp) &

  local pid=$!
  local spin='-\|/'
  local i=0

  let offset=$(tput cols)-${#txt}-10

  while kill -0 $pid 2>/dev/null
  do
    local i=$(( (i+1) %4 ))
	  let offset=$(tput cols)-${#txt}-10
	  printf "\r${txt}%${offset}s[${spin:$i:1}]"
    sleep .1
  done

  wait $pid

  LAST_STATUS=$?
  LAST_ERROR=$(cat /tmp/error.tmp)
  rm -rf /tmp/error.tmp

  if [ $LAST_STATUS -eq 0 ]
  then
	 ok_line "${txt}"
  else
	 fail_line "${txt}"
   logging "COMMAND: ${cmd[*]}"
   logging "ERROR OUTPUT: ${LAST_ERROR}"
  fi
}

## check for NetworkManager
function check_nm ()
{
  is_installed NetworkManager

  if ! sudo systemctl status NetworkManager | grep running &> /dev/null
  then
    is_installed NetworkManager-tui

    local cmd=(systemctl enable --now NetworkManager)
    progress "Starting NetworkManager" "${cmd[@]}"

    echo "${RED}NetworkManager needed to be installed or enabled, please check Network Configuration with nmtui${NORMAL}"
    exit 1
  fi

}

## Check if package is installed, if not, install it
function is_installed ()
{
  local pkg="$1"

  rpm -q $pkg &>/dev/null
  LAST_STATUS=$?
  ok_line "Checking if ${pkg} is installed"

  if [ $LAST_STATUS -eq 1 ]
  then
    local cmd=(dnf -y install $pkg)
    progress "Installing ${pkg}" "${cmd[@]}"
  fi
}

## Check if group is installed, if not, install it
function is_group_installed ()
{
  local pkg="$@"

  dnf group list --installed | grep "${pkg[@]}" &>/dev/null
  LAST_STATUS=$?
  ok_line "Checking if ${pkg} Group is installed"

  if [ $LAST_STATUS -eq 1 ]
  then
    cmd=(dnf -y group install "${pkg}")
    progress "Installing Group ${pkg}" "${cmd[@]}"
  fi
}

# Check and install a whole list of local pkgs
function install_list ()
{
  local pkgs=("$@")

  for pkg in "${pkgs[@]}"
  do
    rpm -q $pkg &>/dev/null
    LAST_STATUS=$?
    ok_line "Checking if ${pkg} is installed"

    if [ $LAST_STATUS -eq 1 ]
    then
      cmd=(dnf -y install $pkg)
      progress "Installing ${pkg}" "${cmd[@]}"
    fi
  done
}

###
# General functions
###

## Refresh dnf Cache
function dnf_cache ()
{
  cmd=(dnf clean all)
  progress "Cleaning dnf Cache" "${cmd[@]}"

  cmd=(dnf makecache)
  progress "Renewing dnf Cache" "${cmd[@]}"
}

## Update System
function system_update ()
{
  cmd=(dnf -y update)
  progress "Installing Update" "${cmd[@]}"

  is_installed dnf-utils

  cmd=(needs-restarting)
  progress "Making sure that no restart is neccessary" "${cmd[@]}"

  if [ $LAST_STATUS -eq 1 ]
  then
    printf "\n\n${RED}The System is going to restart in two minuts.\nPlease run the script again afterwards!\n"
    sleep 120
    reboot
  fi
}

## Install Basic tools
function install_basic_tools ()
{
  section "Install basic tools"
  is_group_installed "Development Tools"
  local pkgs=(vim-enhanced)
  local pkgs+=(zsh)
  local pkgs+=(mc)
  local pkgs+=(gnome-font-viewer)
  local pkgs+=(gnome-tweaks)
  local pkgs+=(gnome-control-center)
  local pkgs+=(tmux)
  local pkgs+=(curl)
  local pkgs+=(ruby)
  local pkgs+=(ruby-devel)
  local pkgs+=(util-linux-user)
  local pkgs+=(redhat-rpm-config)
  local pkgs+=(gcc)
  local pkgs+=(gcc-c++)
  local pkgs+=(make)
  local pkgs+=(python3-devel)
  local pkgs+=(ansible)
  local pkgs+=(vim-syntastic-ansible)
  local pkgs+=(NetworkManager-tui)
  install_list ${pkgs[@]}
}

## Install keepass
function install_keepass ()
{
  is_installed keepass
}

## Install Atom Text Editor
function install_atom ()
{
  rpm -q atom &>/dev/null
  LAST_STATUS=$?
  ok_line "Checking if atom is installed"

  if [ $LAST_STATUS -eq 1 ]
  then
    local path=$(curl -sL "https://api.github.com/repos/atom/atom/releases/latest" | grep "https.*atom.x86_64.rpm" | cut -d '"' -f 4)
    local cmd=(dnf -y install $path)
    progress "Installing atom" "${cmd[@]}"
  fi

  is_installed ShellCheck
}

## Install Google Chrome
function install_chrome ()
{
  is_installed fedora-workstation-repositories

  dnf config-manager --set-enabled google-chrome &>/dev/null

  is_installed google-chrome-stable
  is_installed fedora-chromium-config
}

## Install RDP
function install_rdp ()
{
  local pkgs=(xrdp)
  local pkgs+=(tigervnc-server)
  install_list ${pkgs[@]}

  local cmd=(systemctl enable --now xrdp)
  progress "Starting RDP Server" "${cmd[@]}"

  if firewall-cmd --list-ports | grep 3389/tcp
  then
    local cmd=(firewall-cmd --add-port=3389/tcp --permanent)
    progress "Add Port 3389 to Firewall" "${cmd[@]}"
    local cmd=(firewall-cmd --reload)
    progress "Configuring Firewall" "${cmd[@]}"
  fi

  if sudo systemctl status pcscd.socket | grep running  &>/dev/null
  then
   systemctl stop pcscd.socket &> /dev/null
   systemctl disable pcscd.socket &> /dev/null
  fi

  if sudo systemctl status pcscd | grep running
  then
   systemctl stop pcscd &> /dev/null
   systemctl disable pcscd &> /dev/null
  fi

  ok_line "Stopping pcscd to prevent error message when logging on over RDP"
}

## Install vagrant
function install_vagrant ()
{
  is_installed vagrant

  if ! genent group vagrant &>/dev/null
  then
    groupadd vagrant
    cat <<EOF >> /etc/sudoers

Cmnd_Alias VAGRANT_EXPORTS_CHOWN = /bin/chown 0\:0 /tmp/*
Cmnd_Alias VAGRANT_EXPORTS_MV = /bin/mv -f /tmp/* /etc/exports
Cmnd_Alias VAGRANT_NFSD_CHECK = /usr/bin/systemctl status --no-pager nfs-server.service
Cmnd_Alias VAGRANT_NFSD_START = /usr/bin/systemctl start nfs-server.service
Cmnd_Alias VAGRANT_NFSD_APPLY = /usr/sbin/exportfs -ar
%vagrant ALL=(root) NOPASSWD: VAGRANT_EXPORTS_CHOWN, VAGRANT_EXPORTS_MV, VAGRANT_NFSD_CHECK, VAGRANT_NFSD_START, VAGRANT_NFSD_APPLY
EOF
  fi

}

## Install packer
function install_packer ()
{
  local cmd=(dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo)
  progress "Adding packer Repositories" "${cmd[@]}"
  is_installed packer
}

## Install docker
function install_docker ()
{

  local cmd=(grubby --update-kernel=ALL --args=\"systemd.unified_cgroup_hierarchy=0\")
  progress "Modifying Kernel Settings" "${cmd[@]}"

  local pkgs=(moby-engine)
  local pkgs+=(docker-compose)
  install_list ${pkgs[@]}

  if ! sudo systemctl status docker | grep running &>/dev/null
  then
    local cmd=(systemctl enable --now docker)
    progress "Starting Docker" "${cmd[@]}"
  fi

  local cmd=(getent group docker)
  progress "Checking Docker Group" "${cmd[@]}"

  if [ $LAST_STATUS -eq 1 ]
  then
    local cmd=(groupadd docker)
    progress "Adding Docker Group" "${cmd[@]}"
  fi

  if ! firewall-cmd --list-all --zone=docker | grep docker0 &>/dev/null
  then
    local cmd=(firewall-cmd --permanent --zone=docker --add-interface=docker0)
    progress "Add Docker Interface to Firewall" "${cmd[@]}"
  fi

  if ! firewall-cmd --list-all --zone=docker | grep "masquerade: yes" &>/dev/null
  then
    local cmd=(firewall-cmd --zone=docker --add-masquerade)
    progress "Add Masquerade to Docker Zone " "${cmd[@]}"
  fi

  local cmd=(firewall-cmd --reload)
  progress "Configuring Firewall" "${cmd[@]}"
}

## Install VirtualBox
function install_vb ()
{
  local cmd=(dnf config-manager --add-repo http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo)
  progress "Adding VirtualBox Repositories" "${cmd[@]}"

  local pkgs=(binutils)
  local pkgs+=(gcc)
  local pkgs+=(make)
  local pkgs+=(patch)
  local pkgs+=(libgomp)
  local pkgs+=(dkms)
  local pkgs+=(qt5-qtx11extras)
  local pkgs+=(libxkbcommon)
  local pkgs+=(glibc-headers)
  local pkgs+=(glibc-devel)
  local pkgs+=(kernel-headers)
  local pkgs+=(kernel-devel)
  install_list ${pkgs[@]}

  export KERN_DIR=/usr/src/kernels/`uname -r`
  is_installed VirtualBox-6.1

  local cmd=(vboxconfig)
  progress "Running VirtualBox Config" "${cmd[@]}"

  if ! vboxmanage list extpacks | grep "Extension Packs:" &> /dev/null
  then
    local cmd=(wget https://download.virtualbox.org/virtualbox/6.1.14/Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack)
    progress "Downloading VirtualBox Extension Pack" "${cmd[@]}"

    local cmd=(vboxmanage extpack install Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack --accept-license=33d7284dc4a0ece381196fda3cfe2ed0e1e8e7ed7f27b9a9ebc4ee22e24bd23c)
    progress "Installing VirtualBox Extension Pack" "${cmd[@]}"

    local cmd=(rm -rf Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack)
    progress "Removing VirtualBox Extension Pack download" "${cmd[@]}"
  fi
}

## Install KVM
function install_kvm ()
{
  local pkgs=(qemu-kvm)
  local pkgs+=(libvirt)
  local pkgs+=(virt-install)
  local pkgs+=(virt-manager)
  local pkgs+=(libguestfs-tools)
  local pkgs+=(virt-top)
  local pkgs+=(libvirt-daemon-driver-vbox)
  install_list ${pkgs[@]}

  if ! systemctl status libvirtd | grep running &>/dev/null
  then
    local cmd=(systemctl enable --now libvirtd)
    progress "Starting libvirtd" "${cmd[@]}"
  fi

  local cmd=(getent group kvm)
  progress "Checking KVM Group" "${cmd[@]}"

  if [ $LAST_STATUS -eq 1 ]
  then
    local cmd=(groupadd kvm)
    progress "Adding KVM Group" "${cmd[@]}"

    echo "polkit.addRule(function(action, subject) {
 if (action.id == "org.libvirt.unix.manage" && subject.local && subject.active && subject.isInGroup("libvirt")) {
 return polkit.Result.YES;
 }
 if (action.id == "org.libvirt.unix.manage" && subject.local && subject.active && subject.isInGroup("kvm")) {
 return polkit.Result.YES;
 }
});" > /etc/polkit-1/rules.d/80-libvirt.rules
  fi

  if [ -d /home/kvm ]
  then
    ok_line "Checking KVM VM Directory"
  else
    local cmd=(mkdir /home/kvm)
    progress "Creating KVM VM Directory" "${cmd[@]}"
    local cmd=(chown root:kvm /home/kvm)
    progress "Changing KVM VM Directory owner" "${cmd[@]}"
    local cmd=(chmod 770 /home/kvm)
    progress "Changing KVM VM Directory access" "${cmd[@]}"
    local cmd=(umask 0007 /home/kvm)
    progress "Changing KVM VM Directory umask" "${cmd[@]}"
    local cmd=(chmod g+s /home/kvm)
    progress "Changing KVM VM Directory dafault group for new files" "${cmd[@]}"
    local cmd=(semanage fcontext -t virt_image_t -a "/home/kvm(/.*)?")
    progress "Changing KVM VM Directory Selinux Context" "${cmd[@]}"
    local cmd=(restorecon /home/kvm/)
    progress "Setting KVM VM Directory Selinux Context" "${cmd[@]}"
    local cmd=(rmdir /var/lib/libvirt/images/)
    progress "Removing default KVM VM Directory" "${cmd[@]}"
    local cmd=(ln -s /home/kvm /var/lib/libvirt/images)
    progress "Creating Link to new KVM VM Directory" "${cmd[@]}"
  fi
}

## Install VMware Player 16
function install_vmware ()
{
  wget https://download3.vmware.com/software/player/file/VMware-Player-16.0.0-16894299.x86_64.bundle
  sh ./VMware-Player-16.0.0-16894299.x86_64.bundle
  rm -rf VMware-Player-16.0.0-16894299.x86_64.bundle
}

## Install vagrant dependencies
function install_vagrant_libvirt ()
{
  dnf -y install cmake byacc

  cd /tmp
  mkdir libssh
  cd libssh

  dnf download --source libssh
  local file=$(ls libssh*)
  rpm2cpio $file | cpio -imdV
  local file=$(ls *.tar.xz)
  tar xf $file
  local dir=${file%".tar.xz"}
  mkdir build
  cd build
  cmake ../$dir -DOPENSSL_ROOT_DIR=/opt/vagrant/embedded/
  make
  cp lib/libssh* /opt/vagrant/embedded/lib64

  cd /tmp
  mkdir krb5-libs
  cd krb5-libs

  dnf download --source krb5-libs
  local file=$(ls krb5*)
  rpm2cpio $file | cpio -imdV
  local file=$(ls *.tar.xz)
  tar xf $file
  local dir=${file%".tar.xz"}
  cd $dir/src
  ./configure
  make
  cp -a lib/crypto/libk5crypto.* /opt/vagrant/embedded/lib64/

  firewall-cmd --permanent --zone public --add-service mountd
  firewall-cmd --permanent --zone public --add-service rpc-bind
  firewall-cmd --permanent --zone public --add-service nfs
  firewall-cmd --permanent --zone public --add-service nfs3

  firewall-cmd --permanent --zone libvirt --add-service mountd
  firewall-cmd --permanent --zone libvirt --add-service rpc-bind
  firewall-cmd --permanent --zone libvirt --add-service nfs
  firewall-cmd --permanent --zone libvirt --add-service nfs3

  firewall-cmd --reload

  cd $SCRIPT_DIR
}

# Install bridge for use with kvm
function install_kvm_net ()
{
  local dev=$(ip a | grep -B 3 "inet " | grep "state UP" | cut -d: -f2 | tr -d '[:space:]')
  local net=$(nmcli --terse --fields NAME,DEVICE,TYPE c show --active | grep "$dev" | head -n 1 | cut -d: -f1)
  local type=$(nmcli --terse --fields NAME,DEVICE,TYPE c show --active | grep "$dev" | head -n 1 | cut -d: -f3)

  if [ $type == "bridge" ]
  then
    ok_line "Existing Bridge detected"
  else
    local cmd=(nmcli connection add type bridge autoconnect yes con-name br0 ifname br0)
    progress "Adding a Bridge Connection" "${cmd[@]}"
    local cmd=(nmcli device modify br0 ipv4.method auto)
    progress "Setting Bridge to DHCP" "${cmd[@]}"
    local cmd=(nmcli connection del "$net")
    progress "Deleting default Connection" "${cmd[@]}"
    local cmd=(nmcli connection add type bridge-slave autoconnect yes con-name $dev ifname $dev master br0)
    progress "Slaving network device to bridge" "${cmd[@]}"
  fi
}

## Setup gnome-terminal
function setup_terminal ()
{
  wget https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete.ttf -O $USER_HOME/Downloads/Hack.ttf
  mkdir $USER_HOME/.local/share/fonts
  mv $USER_HOME/Downloads/Hack.ttf $USER_HOME/.local/share/fonts/Hack-Regular.ttf
  fc-cache -vf $USER_HOME/.local/share/fonts
  export profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
  export profile=${profile:1:-1}
  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/" use-system-font false
  gsettings set "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$profile/" font 'Hack Nerd Font 12'
  gsettings set org.gnome.Terminal.Legacy.Settings default-show-menubar false
}

## Install oh-my-zsh
function setup_ohmyzsh ()
{
  # Remove Existing Oh-My-ZSH installation
  if [ -d $USER_HOME/.oh-my-zsh ]; then mv $USER_HOME/.oh-my-zsh $USER_HOME/.oh-my-zsh.bak; fi
  if [ -f $USER_HOME/.zshrc ]; then mv $USER_HOME/.zshrc $USER_HOME/.zshrc.bak; fi

  # Install and configure ZSH, Oh-My-ZSH and Theme
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended
  git clone https://github.com/bhilburn/powerlevel9k.git $USER_HOME/.oh-my-zsh/custom/themes/powerlevel9k
  sed -i 's/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"powerlevel9k\/powerlevel9k\"/g' $USER_HOME/.zshrc
  sed -i '/^ZSH_THEME=.*/a POWERLEVEL9K_MODE=\"nerdfont-complete\"' $USER_HOME/.zshrc
  sed -i '/^POWERLEVEL9K_MODE=.*/a POWERLEVEL9K_DATE_FORMAT=\"%D{%d.%m.%y} \"' $USER_HOME/.zshrc
  sed -i '/^POWERLEVEL9K_DATE_FORMAT=.*/a POWERLEVEL9K_TIME_FORMAT=\"%D{%H:%M}\"' $USER_HOME/.zshrc
  sed -i '/^POWERLEVEL9K_TIME_FORMAT=.*/a POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon ssh context dir dir_writable vcs)' $USER_HOME/.zshrc
  sed -i '/^POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=.*/a POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs time date)' $USER_HOME/.zshrc
  source $USER_HOME/.zshrc

  # Install Plugins
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  sed -i '/^plugins=.*/ {s/)$/ zsh-autosuggestions)/}' $USER_HOME/.zshrc
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$USER_HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  sed -i '/^plugins=.*/ {s/)$/ zsh-syntax-highlighting)/}' $USER_HOME/.zshrc
  sed -i '/^plugins=.*/ {s/)$/ sudo)/}' $USER_HOME/.zshrc
  sed -i '/^plugins=.*/ {s/)$/ history)/}' $USER_HOME/.zshrc
  sed -i '/^plugins=.*/ {s/)$/ tmux)/}' $USER_HOME/.zshrc


  # Install colorls
  gem install colorls
  sed -i '/source \$ZSH\/oh-my-zsh.sh/a source \$(dirname \$(gem which colorls))\/tab_complete.sh' $USER_HOME/.zshrc

  # install fzf
  git clone --depth 1 https://github.com/junegunn/fzf.git $USER_HOME/.fzf
  $USER_HOME/.fzf/install --all
  sed -i '/^plugins=.*/i export FZF_BASE=$HOME/.fzf' $USER_HOME/.zshrc
  sed -i '/^plugins=.*/ {s/)$/ fzf)/}' $USER_HOME/.zshrc

  # install fd
  wget https://github.com/sharkdp/fd/releases/download/v7.4.0/fd-v7.4.0-x86_64-unknown-linux-musl.tar.gz -O $USER_HOME/fd-v7.4.0-x86_64-unknown-linux-musl.tar.gz
  tar -xzf fd-v7.4.0-x86_64-unknown-linux-musl.tar.gz
  cp fd $USER_HOME/fd-v7.4.0-x86_64-unknown-linux-musl/fd /usr/local/bin/
  cp fd $USER_HOME/fd-v7.4.0-x86_64-unknown-linux-musl/fd.1 /usr/local/share/man/man1/
  mandb
  rm -rf $USER_HOME/fd*
  sed -i '/^plugins=.*/ {s/)$/ fd)/}' $USER_HOME/.zshrc

  # add custom stuff
  touch $USER_HOME/.zshrc
  cat <<EOT >> $USER_HOME/.zshrc
# User configuration
export EDITOR=vim

# Custom Alias Segment
alias vi='vim'
alias ping='ping -c5'
alias ..='cd ..'
alias cls='clear'
alias mc='mc --colors normal=green'
alias e=$EDITOR
alias se='sudo $EDITOR'
alias hr='hash -r'
alias ls='colorls --group-directories-first'
alias ll='colorls --group-directories-first -l'
alias la='colorls --group-directories-first -a'
alias lal='colorls --group-directories-first -la'


# User functions

function x()
{
  if [ -f "$1" ] ; then
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz) tar xzf "$1" ;;
      *.tar.bz) tar xzf "$1" ;;
      *.tar.Z) tar xzf "$1" ;;
      *.bz2) bunzip2 "$1" ;;
      *.rar) unrar x "$1" ;;
      *.gz) gunzip "$1" ;;
      *.jar) unzip "$1" ;;
      *.tar) tar xf "$1" ;;
      *.tbz2) tar xjf "$1" ;;
      *.tgz) tar xzf "$1" ;;
      *.zip) unzip "$1" ;;
      *.Z) uncompress "$1" ;;
      *.7z) 7z x "$1" ;;
      *) echo "'$1' cannot be extracted." ;;
    esac
  else
    echo "'$1' is not a valid archive."
  fi
}

if [ "$SSH_CONNECTION" != "" ]; then
  session="ssh"
  tmux has-session -t $session 2>/dev/null

  if [ $? != 0 ]; then
    tmux new-session -s $session
  fi

  # Attach to created session
  if [[ -z "$TMUX" ]]; then
    tmux attach-session -t $session
  fi
fi

EOT
}

## Set up vim
function setup_vim ()
{
  git clone https://github.com/VundleVim/Vundle.vim.git $USER_HOME/.vim/bundle/Vundle.vim
  touch $USER_HOME/.vimrc
  cat <<EOT > $USER_HOME/.vimrc
set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=$USER_HOME/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'zacanger/angr.vim'
Plugin 'morhetz/gruvbox'

call vundle#end()            " required
filetype plugin indent on    " required
EOT
if [ -d $USER_HOME/.vim/bundle/Vundle.vim ]
then
  vim +PluginInstall +qall
fi

cat <<EOT >> $USER_HOME/.vimrc

set showmode
set showcmd
set showmatch
set ttyfast
set encoding=utf-8
set fileencoding=utf-8
set termencoding=utf-8
set wildchar=<TAB>
set backspace=indent,eol,start
set ruler
set number
set mouse=a

"use a terminal title
set title
set titlestring=%F\ [vim]

" tab settings
set tabstop=2 "tab character amount
set expandtab "tabs as space
set autoindent
set smartindent "smart autoindenting on a new line
set shiftwidth=2 "set spaces for autoindent
set softtabstop=2

"statusline
let g:airline_powerline_fonts = 1
set laststatus=2
"set statusline=%<%F\ %h%m%r%=%k\ %-10.(%l/%L,%c%V%)\ %P\ [%{&encoding}:%{&fileformat}]%(\ %w%)\ %y


"Will allow you to use :w!! to write to a file using sudo if you forgot to "sudo vim file" (it will prompt for sudo password when writing)
cmap w!! %!sudo tee > /dev/null %

syntax on
colorscheme gruvbox
set background=dark    " Setting dark mode
EOT
}

## Set up Tmux
function setup_tmux ()
{
  git clone https://github.com/jimeh/tmux-themepack.git $USER_HOME/.tmux-themepack
  touch $USER_HOME/.tmux.conf
  cat <<EOT > $USER_HOME/.tmux.conf
# set true colors
set -g default-terminal "screen-256color"

# remap prefix from 'C-b' to 'C-y'
unbind C-b
set-option -g prefix C-y
bind-key C-y send-prefix

# split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# reload config file (change file location to your the tmux.conf you want to use)
bind r source-file $USER_HOME/.tmux.conf

# switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Shift arrow to switch windows
bind -n S-Left  previous-window
bind -n S-Right next-window

# Enable mouse mode (tmux 2.1 and above)
set -g mouse on
setw -g monitor-activity on

# Selection with mouse should copy to clipboard right away, in addition to the default action.
unbind -n -Tcopy-mode-vi MouseDragEnd1Pane
bind -Tcopy-mode-vi MouseDragEnd1Pane send -X copy-selection-and-cancel\; run "tmux save-buffer - | xclip -i -sel clipboard > /dev/null"


# Middle click to paste from the clipboard
unbind-key MouseDown2Pane
bind-key -n MouseDown2Pane run " X=$(xclip -o -sel clipboard); tmux set-buffer \"$X\"; tmux paste-buffer -p; tmux display-message 'pasted!' "
source-file ${USER_HOME}/.tmux-themepack/powerline/double/blue.tmuxtheme
EOT
}

## Set up Atom
function setup_atom ()
{
  apm install ansible-galaxy asciidoc-assistant language-asciidoc asciidoc-preview asciidoc-image-helper autocomplete-asciidoc autocomplete-ansible busy-signal docker intentions language-ansible linter linter-ansible-linting linter-ansible-syntax linter-docker linter-ui-default linter-yaml linter-vagrant-validate linter-packer-validate linter-shellcheck
}

## Setup dot files for user settings
function user_settings ()
{
  cd $USER_HOME
  section "User Settings"
  local cmd=(setup_terminal)
  progress "Setting up Gnome Terminal" "${cmd[@]}"
  local cmd=(setup_ohmyzsh)
  progress "Setting up Oh-My-ZSH and plugins" "${cmd[@]}"
  local cmd=(setup_vim)
  progress "Setting up vim and plugins" "${cmd[@]}"
  local cmd=(setup_tmux)
  progress "Setting up tmux" "${cmd[@]}"
  local cmd=(setup_atom)
  progress "Setting up Atom" "${cmd[@]}"
  local cmd=(ln -s /home/kvm $USER_HOME/kvm)
  progress "Creating Link to KVM VM Directory" "${cmd[@]}"

  rm -rf $USER_HOME/.vagrant.d
  vagrant plugin install vagrant_libvirt
  #local cmd=(vagrant plugin install vagrant_libvirt)
  #progress "Installing vagrant-libvirt plugin" "${cmd[@]}"

  cd $SCRIPT_DIR
}

## Change The Script User
function change_user ()
{
  local usr=$1

  if getent passwd $usr &>/dev/null
  then
    SCRIPT_USER=$usr
    local dir=$(getent passwd $usr | cut -d: -f6)

    if [ -d "$dir" ]
    then
      USER_HOME=$dir
    fi
  fi
}

###
# Deal with Options and Arguments
###

## Process Options that have to be taken care of before everything else
function process_priority_arguments ()
{
  local args=( "$@" )
  local i=0

  if [[ $args == *"--help"* ]]; then
    usage
    exit 0
  fi
}

## Process options
function process_arguments ()
{
  local args=( "$@" )
  local i=0

  for arg in "${args[@]}"
  do
    i=$(($i + 1))
    case "$arg" in
      --no-usersettings)
        NO_USER=1
      ;;
      --only-usersettings)
        ONLY_USER=1
      ;;
      --user)
        change_user ${args[$i]}
      ;;
    esac
  done
}

##############################################
#              Script Logic                  #
##############################################

process_priority_arguments $@
touch $LOGFILE
process_arguments $@

if [ $(ps -ef| grep $SCRIPTFILE | wc -l ) -lt 2 ]
then
  section "Checking requirements for the script"
  check_nm
  is_installed "sed"
  is_installed "wget"
fi

if [ "$EUID" -eq 0 ]
then
  chmod 666 $LOGFILE

  if [ $ONLY_USER -eq 0 ]
  then
    dnf_cache
    system_update
    install_basic_tools

    section "Install graphical Tools"
    install_keepass
    install_atom
    install_chrome
    install_rdp

    section "Install virtualization Tools"
    install_packer
    install_vagrant
    install_docker
    install_vb
    install_kvm

    local cmd=(install_vmware)
    progress "Compiling neccessary Dependencies for vagrant-libvirt" "${cmd[@]}"
    #local cmd=(install_vagrant_libvirt)
    #progress "Compiling neccessary Dependencies for vagrant-libvirt" "${cmd[@]}"
    install_vagrant_libvirt

  fi

  if [ $NO_USER -eq 0 ]
  then
    sudo -u $SCRIPT_USER sh $SCRIPTFILE --only-usersettings

    cmd=(pip3 install thefuck)
    progress "Adding Oh-My-ZSH plugin thefuck" "${cmd[@]}"
    echo "eval \$(thefuck --alias)" >> $USER_HOME/.zshrc

    cmd=(usermod -aG vagrant $SCRIPT_USER)
    progress "Add User to vagrant Group" "${cmd[@]}"
    cmd=(usermod -aG docker $SCRIPT_USER)
    progress "Add User to docker Group" "${cmd[@]}"
    cmd=(usermod -aG kvm $SCRIPT_USER)
    progress "Add User to KVM Group" "${cmd[@]}"
    cmd=(chsh -s /bin/zsh $SCRIPT_USER)
    progress "Setting default Shell to ZSH" "${cmd[@]}"

  fi

  #install_kvm_net

  if [ $ERROR_COUNT -eq 0 ]
  then
    crontab -l | grep -v "$SCRIPTFILE"  | crontab -
    printf "\n\n${RED}The System is going to restart in two minutes.\n${NORMAL}"
    sleep 120
    reboot
  else
    printf "\n\n${RED}There were some Errors during the Setup. Please check the log at $LOGFILE.\n${NORMAL}"
  fi
else
  if [ $NO_USER -eq 0 ]
  then
    user_settings
  fi
fi
