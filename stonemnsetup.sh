#!/bin/bash
#Originally based on work by BitYoda, reworked and shortened for StoneCoin by CryproTYM

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='stonecoin.conf'
CONFIGFOLDER='/root/.stonecrypto'
CONFIGFOLDERONLY='.stonecrypto'
COIN_DAEMON='stonecoind'
COIN_CLI='stonecoin-cli'
COIN_TX='stonecoin-tx'
COIN_PATH='/usr/local/bin/'
COIN_REPO='https://github.com/stonecoinproject/stonecoin'
COIN_TGZ='https://github.com/stonecoinproject/Stonecoin/releases/download/v2.0.0.0-beta1/stonecoin--linux64.tar.gz'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
SENTINEL_REPO='N/A'
COIN_NAME='Stonecoin'
COIN_PORT=22323
RPC_PORT=22324

NODEIP=$(curl -s4 icanhazip.com)

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

purgeOldInstallation() {
    echo -e "${GREEN}Searching and removing old $COIN_NAME files and configurations${NC}"
    #kill wallet daemon
    sudo killall $COIN_DAEMON > /dev/null 2>&1
    #remove old ufw port allow
    sudo ufw delete allow $COIN_PORT/tcp > /dev/null 2>&1
    #remove old files
    #if [ -d "~/$CONFIGFOLDERONLY" ]; then #Depricated, possibly unnecessary
        sudo rm -r ~/$CONFIGFOLDERONLY > /dev/null 2>&1
    #fi
    #remove binaries and Stone utilities
    cd /usr/local/bin && sudo rm $COIN_CLI $COIN_TX $COIN_DAEMON > /dev/null 2>&1 && cd
    echo -e "${GREEN}* Done${NONE}";
}


function download_node() {
  echo -e "${GREEN}Downloading and Installing VPS $COIN_NAME Daemon${NC}"
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ
  compile_error
  tar xvzf $COIN_ZIP >/dev/null 2>&1
  # need to make this auto update with new releases
  cd stonecrypto-2.0.0/bin
  chmod +x $COIN_DAEMON $COIN_CLI
  cp $COIN_DAEMON $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
  clear
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target
[Service]
User=root
Group=root
Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid
ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME.service"
    echo -e "systemctl status $COIN_NAME.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  mkdir $CONFIGFOLDER >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {
  #Can be used in the future if we want to have users input their own key.
  #echo -e "${YELLOW}Enter your ${RED}$COIN_NAME Masternode GEN Key${NC}."
  #read -e COINKEY
  sleep 10
  $COIN_PATH$COIN_DAEMON -daemon
  sleep 30
  if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
   echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  if [ "$?" -gt "0" ];
    then
    echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the GEN Key${NC}"
    sleep 30
    COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
  fi
  $COIN_PATH$COIN_CLI stop
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
  cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
#bind=$NODEIP
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
#Addnodes
addnode=199.247.9.250:22323
addnode=199.247.16.62:22323
addnode=207.246.76.53:22323
addnode=206.81.12.251:22323
addnode=173.249.33.136:22323
addnode=167.99.137.60:22323
addnode=207.148.90.132:22323
addnode=63.209.35.17:22323
EOF
}


function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
  ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $COIN_NAME. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
  echo -e "${RED}$COIN_NAME is already installed.${NC}"
  exit 1
fi
}

# Cleanup, function depricated no compile required for future releases.
function prepare_system() {
echo -e "Preparing the VPS to setup. ${CYAN}$COIN_NAME${NC} ${RED}Masternode${NC}"
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${PURPLE}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install libzmq3-dev -y >/dev/null 2>&1
apt-get install -y git wget curl >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
 exit 1
fi
clear
}

function masternode_info() {
  echo
  echo "Give your masternode a name: "
  read mnAlias
  echo "Paste the transaction ID from masternode outputs: "
  read mnTx
  echo "Enter the output index number from masternode outputs 0 or 1:"
  read mnIndex
  echo -e "Awesome you're almost done! Just paste the green line below into your local masternode.conf and then start alias."
  echo "Press enter to continue"
  read dumpEnter
}

function important_information() {
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}  TTTTTTT  OOOOO  NN   NN EEEEEEE  CCCCC  OOOOO  IIIII NN   NN     RRRRRR   OOOOO   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e    "${GREEN}  \$\$${NC}${CYAN}        TTT   OO   OO NNN  NN EE      CCC    OO   OO  III  NNN  NN     RR   RR OO   OO CCC    KK KK  ${NC}${GREEN}\$\$      ${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT   OO   OO NN N NN EEEEE   CC     OO   OO  III  NN N NN     RRRRRR  OO   OO CC     KKKK    ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e    "${GREEN}       \$\$${NC}${CYAN}   TTT   OO   OO NN  NNN EE      CCC    OO   OO  III  NN  NNN ${NC}${GREEN}dot${NC}${CYAN} RR  RR  OO   OO CCC    KK KK       ${NC}${GREEN}\$\$ ${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT    OOOO0  NN   NN EEEEEEE  CCCCC  OOOO0  IIIII NN   NN ${NC}${GREEN}dot${NC}${CYAN} RR   RR  OOOO0   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${GREEN}$mnAlias $NODEIP:$COIN_PORT $COINKEY $mnTx $mnIndex"
 #echo -e "${GREEN}Start:${NC}${RED}systemctl start $COIN_NAME.service${NC}"#section removed to avoid confusion
 #echo -e "${GREEN}Stop:${NC}${RED}systemctl stop $COIN_NAME.service${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${PURPLE}Full Setup Guide. https://github.com/stonecoinproject/stonemnsetup/blob/master/README.md${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN}Ensure Node is fully SYNCED with BLOCKCHAIN.${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${PURPLE}Usage Commands.${NC}"
 echo -e "${PURPLE}Check masternode status: $COIN_CLI masternode status${NC}"
 echo -e "${PURPLE}Check blockchain status: $COIN_CLI getinfo${NC}"
 echo -e "${PURPLE}Restart daemon: $COIN_CLI stop${NC}"
 echo -e "${PURPLE}VPS Configuration file location:${NC}${CYAN}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${CYAN}Follow in Discord to stay updated.  https://discord.gg/8u7U3gh${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${RED}Donations go towards coin development${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"
 echo -e "${YELLOW}Stonecoin: Si8dAZHaP1utVqxJJf1t2KVU6cBkk6FrVz${NC}"
 echo -e "${YELLOW}BTC: 3QFJ9UTJGbBHBYqZsqTzXHyxifML44Wdyp${NC}"
 echo -e "${YELLOW}XMR: 445kB5Mxzj5LKeTt6RrgTvciqnPVT4HgyE4zN3grJTvaEyrCMuCPAyx7Kah3bq2RBZMoTauDDVFVvBuKcer5NnCKDoeT9DW${NC}"
 echo -e "${YELLOW}LTC: LgdPXvnYRvQoAVGZq2SUomZwkbv4Hjecok${NC}"
 echo -e "${YELLOW}RAVEN: RKUaCMEKqJi3ERnbEXXh9M3LKTK79hJuSt${NC}"
 echo -e "${BLUE}================================================================================================================================${NC}"

 }

function setup_node() {
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  configure_systemd
  masternode_info
  important_information
}


##### Main #####
clear

purgeOldInstallation
#checks #removed for temp
prepare_system #some vps do not have curl preinstalled
download_node
setup_node
