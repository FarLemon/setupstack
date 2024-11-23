#!/bin/bash
set -e



# ----- Color Codes -----
RESTORE='\033[0m'
NC='\033[0m'
BLACK='\033[00;30m'
RED='\033[00;31m'
GREEN='\033[00;32m'
YELLOW='\033[00;33m'
BLUE='\033[00;34m'
PURPLE='\033[00;35m'
CYAN='\033[00;36m'
SEA="\\033[38;5;49m"
LIGHTGRAY='\033[00;37m'
LBLACK='\033[01;30m'
LRED='\033[01;31m'
LGREEN='\033[01;32m'
LYELLOW='\033[01;33m'
LBLUE='\033[01;34m'
LPURPLE='\033[01;35m'
LCYAN='\033[01;36m'
WHITE='\033[01;37m'
OVERWRITE='\e[1A\e[K'



# ----- Emoji Codes -----
CHECK_MARK="${GREEN}\xE2\x9C\x94${NC}"
X_MARK="${RED}\xE2\x9C\x96${NC}"
PIN="${RED}\xF0\x9F\x93\x8C${NC}"
CLOCK="${GREEN}\xE2\x8C\x9B${NC}"
ARROW="${SEA}\xE2\x96\xB6${NC}"
BOOK="${RED}\xF0\x9F\x93\x8B${NC}"
HOT="${ORANGE}\xF0\x9F\x94\xA5${NC}"
WARNING="${RED}\xF0\x9F\x9A\xA8${NC}"
RIGHT_ANGLE="${GREEN}\xE2\x88\x9F${NC}"



# ----- Variables -----
ID=""
SETUPSTACK_LOG="$HOME/.setupstack.log"
SETUPSTACK_DIR="$HOME/.setupstack"
SSH_DIR="$HOME/.ssh"
IS_FIRST_RUN="$HOME/.setupstack_run"



# ----- General Functions -----
function _task {
	if [[ $TASK != "" ]]; then
		printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
	fi

	# set new task title
	TASK=$1
	printf "${LBLACK} [ ]  ${TASK} \n${LRED}"
}

# performs commands with error checking
function _cmd {
	# create log if doesn't exist
	if ! [[ -f $SETUPSTACK_LOG ]]; then
		touch $SETUPSTACK_LOG
	fi
	
	# empty log
	> $SETUPSTACK_LOG

	# hide stdout, on error we print and exit
	if eval "$1" 1> /dev/null 2> $SETUPSTACK_LOG; then
		return 0 # on success
	fi

	# read error from log and add spacing
	printf "${OVERWRITE}${LRED} [X]  ${TASK}${LRED}\n"
	while read line; do
		printf "      ${line}\n"
	done < $SETUPSTACK_LOG
	printf "\n"

	# remove log file
	rm $SETUPSTACK_LOG

	# exit install
	exit 1
}

function _clear_task {
	TASK=""
}

function _task_done {
	printf "${OVERWRITE}${LGREEN} [✓]  ${LGREEN}${TASK}\n"
	_clear_task
}



# ----- OS Specific Setup Functions -----
function arch_setup {
	if ! [ -x "$(command -v ansible)" ]; then
		_task "Installing Ansible"
		_cmd "sudo pacman -Syu --noconfirm"
		_cmd "sudo pacman -S --noconfirm ansible"
	fi

	if ! pacman -Q openssh >/dev/null 2>&1; then
		_task "Installing OpenSSH"
		_cmd "sudo pacman -S --noconfirm openssh"
	fi

	_task "Setting Locale"
	_cmd "sudo localectl set-locale LANG=en_US.UTF-8"
}



function update_ansible_galaxy {
	local os=$1
	local os_prerequisites=""

	_task "Updating Ansible Galaxy"

	if [ -f "$SETUPSTACK_DIR/prerequisites/$os.yml" ]; then
   		_task "${OVERWRITE}Updating Ansible Galaxy with OS Config: $os"
  		os_prerequisites="$SETUPSTACK_DIR/prerequisites/$os.yml"
	fi

  	_cmd "ansible-galaxy install -r $SETUPSTACK_DIR/prerequisites/common.yml $os_prerequisites"
}



# detect OS
if [ -f /etc/os-release ]; then
	source /etc/os-release
else
	ID=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

# run detected os setup
_task "Loading setup for detected OS: $ID"
case $ID in
	arch)
		arch_setup
		;;
	*)
		_task "Unsupported OS"
		_cmd "echo 'Unsupported OS'"
		;;
esac

if ! [[ -f "$SSH_DIR/authorized_keys" ]]; then
	_task "Generating SSH Keys"
	_cmd "mkdir -p $SSH_DIR"
	_cmd "chmod 700 $SSH_DIR"
	_cmd "ssh-keygen -b 4090 -t ed25519 -a 100 -f $SSH_DIR/id_ed25519 -N '' -C $USER@$HOSTNAME"
	_cmd "cat $SSH_DIR/id_ed25519.pub >> $SSH_DIR/authorized_keys"
fi

if ! [[ -d "$SETUPSTACK_DIR" ]]; then
	_task "Cloning Repository"
	_cmd "git clone --quiet https://github.com/FarLemon/setupstack.git $SETUPSTACK_DIR"
else
	_task "Updating Local Repository"
	_cmd "git -C $SETUPSTACK_DIR pull origin main --quiet"
fi

pushd "$SETUPSTACK_DIR" 2>&1 > /dev/null
update_ansible_galaxy $ID

ansible-playbook "$SETUPSTACK_DIR/dotfiles/main.yml" "$@"

popd 2>&1 > /dev/null

if ! [[ -f "$IS_FIRST_RUN" ]]; then
  echo -e "${CHECK_MARK} ${GREEN}First run complete!${NC}"
  echo -e "${ARROW} ${CYAN}Please reboot your computer to complete the setup${NC}"
  touch "$IS_FIRST_RUN"
fi

# vi:ft=sh
