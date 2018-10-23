#!/bin/bash
#Originally based on work by BitYoda, reworked and optimized for StoneCoin by CryproTYM

TMP_FOLDER=$(mktemp -d)
#new
CONFIG_FILE='stone.conf'
CONFIGFOLDER='/root/.stonecore'
CONFIGFOLDERONLY='.stonecore'
COIN_DAEMON='stoned'
COIN_CLI='stone-cli'
COIN_TX='stone-tx'
EXTRACT_DIR='stonecore-2.1.0/bin' # Todo make this work and auto

#Old for removal
OLD_CONFIG_FILE='stonecoin.conf'
OLD_CONFIGFOLDER='/root/.stonecrypto'
OLD_CONFIGFOLDERONLY='.stonecrypto'
OLD_COIN_DAEMON='stonecoind'
OLD_COIN_CLI='stonecoin-cli'
OLD_COIN_TX='stonecoin-tx'

#other settings
COIN_PATH='/usr/local/bin/'
COIN_REPO='https://github.com/stonecoinproject/stonecoin'
COIN_TGZ='https://github.com/stonecoinproject/Stonecoin/releases/download/v2.1.0.1-9523a37/stonecore-2.1.0-linux64.tar.gz'
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')
SENTINEL_REPO=''
COIN_NAME='Stone'
COIN_PORT=22323
RPC_PORT=22324

#addnodes
ADDNODE1='pool.stonecoin.rocks:22323'
ADDNODE2='explorer.stonecoin.rocks:22323'
ADDNODE3=''
ADDNODE4=''
ADDNODE5=''
ADDNODE6=''

#data
DATE=$(date +"%Y%m%d%H%M")
NODEIP=$(curl -s4 icanhazip.com)
BOOTSTRAPURL='https://github.com/stonecoinproject/Stonecoin/releases/download/Bootstrapv2.0/stonecore.tar.gz'

#syncmanager
SYNC_SCRIPT_URL="https://raw.githubusercontent.com/stonecoinproject/stonemnsetup/master/stonesyncmanager.sh"
synccroncmd="/bin/bash -c '~/.stonesyncmanager/stonesyncmanager.sh'"
synccronjob="0 */8 * * * $synccroncmd"
synccroncmdold="/bin/bash -c '~/.stonesyncmanager/stonesyncmanager.sh'"


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
    sudo killall $OLD_COIN_DAEMON > /dev/null 2>&1
    sudo killall $COIN_DAEMON > /dev/null 2>&1
    sudo systemctl disable Stonecoin.service
    sudo systemctl stop Stonecoin.service
    sudo systemctl disable Stone.service
    sudo systemctl stop Stone.service
    sleep 1
    #Backup old just in case
    mkdir ~/.stonebackups
    cp ~/.stonecrypto/wallet.dat ~/.stonebackups/wallet.dat.1.$DATE
    cp ~/.stonecore/wallet.dat ~/.stonebackups/wallet.dat.$DATE
    sleep 1
    #remove files
    rm -r ~/.stonecrypto/ #blocks ~/.stonecrypto/chainstate ~/.stonecrypto/database
   # rm ~/.stonecrypto/ #peers.dat ~/.stonecrypto/mncache.dat ~/.stonecrypto/banlist.dat
    rm -r ~/.stonecore/ #blocks ~/.stonecore/chainstate ~/.stonecore/database
   # rm ~/.stonecore/ #peers.dat ~/.stonecore/mncache.dat ~/.stonecore/banlist.dat
    #remove binaries and Stone utilities
    cd /usr/local/bin && sudo rm $OLD_COIN_CLI $OLD_COIN_TX $OLD_COIN_DAEMON > /dev/null 2>&1 && sleep 2 && cd
    cd /usr/local/bin && sudo rm $COIN_CLI $COIN_TX $COIN_DAEMON > /dev/null 2>&1 && sleep 2 && cd
    unInstallSyncManager
    echo -e "${GREEN}* Done${NONE}";
}

unInstallSyncManager(){
( crontab -l | grep -v -F "$synccroncmd" ) | crontab - >/dev/null 2>&1
sleep 1
( crontab -l | grep -v -F "$synccroncmdold" ) | crontab - >/dev/null 2>&1
sleep 1
rm -rf ~/.stonesyncmanager >/dev/null 2>&1
sleep 1
}

function download_node() {
  echo -e "${GREEN}Downloading and Installing VPS $COIN_NAME Daemon${NC}"
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ
  #compile_error
  tar xvzf $COIN_ZIP >/dev/null 2>&1
  # need to make this auto update with new releases
  cd stonecore-2.1.0/bin
  chmod +x $COIN_DAEMON $COIN_CLI
  cp $COIN_DAEMON $COIN_CLI $COIN_PATH
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
}

installSyncManager(){
echo -e "${GREEN}Downloading and Installing STONE Sync Manager${NC}"
mkdir ~/.stonesyncmanager >/dev/null 2>&1
wget -q $SYNC_SCRIPT_URL
chmod 775 stonesyncmanager.sh >/dev/null 2>&1
mv stonesyncmanager.sh ~/.stonesyncmanager/stonesyncmanager.sh >/dev/null 2>&1
addSyncManagerCrontab
sleep 1
}

addSyncManagerCrontab(){
echo -e "${GREEN}Adding crontab..${NC}"
( crontab -l | grep -v -F "$synccroncmdold" ) | crontab - >/dev/null 2>&1
sleep 2
cat <(fgrep -i -v "$synccroncmd" <(crontab -l)) <(echo "$synccronjob") | crontab - >/dev/null 2>&1
echo -e "${GREEN}Just sleeping so you can read this..${NC}"
sleep 2
echo -e "${GREEN}STONE Sync Manager Installation Complete!${NC}"
sleep 3
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

function wipe_config() {
  echo -e "Stopping systemd.."
  sudo systemctl disable Stone.service
  sudo systemctl stop Stone.service
  echo -e "Clearing current config file.."
  sleep 1
  rm ~/.stonecore/stone.conf
  sleep 1
  echo -e "Creating new config file.."
  sleep 1
}

function reEnableSystemd() {
  echo -e "Re-enabling systemd.."
  sleep 1
  systemctl daemon-reload
  sleep 3
  systemctl start $COIN_NAME.service
  systemctl enable $COIN_NAME.service >/dev/null 2>&1
  sleep 1
}

function addBootstrap() {
  echo -e "Downloading Bootstrap"
  #mkdir $CONFIGFOLDER >/dev/null 2>&1
  cd ~/
  wget -q $BOOTSTRAPURL
  tar -xzf stonecore.tar.gz
  rm stonecore.tar.gz
  sleep 1
}

function create_config() {
  sleep 1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=22324
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
addnode=$ADDNODE1
addnode=$ADDNODE2
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
apt-get update -y >/dev/null 2>&1
apt-get ufw -y >/dev/null 2>&1
#apt-get install libzmq3-dev -y >/dev/null 2>&1
apt-get install -y git wget curl >/dev/null 2>&1
#if [ "$?" -gt "0" ];
#  then
#    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
#    echo "apt-get update"
#    echo "apt -y install software-properties-common"
#    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
#    echo "apt-get update"
#    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
#libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
#bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
# exit 1
#fi
}

function masternode_info() {
  echo
  echo "Give your masternode a name: "
  read mnAlias </dev/tty
  echo "Paste the transaction ID from masternode outputs: "
  read mnTx </dev/tty
  echo "Enter the output index number from masternode outputs 0 or 1:"
  read mnIndex </dev/tty
  echo -e "Awesome you're almost done! Just paste the green line below into your local masternode.conf and then start alias."
  echo "Press enter to continue"
  read dumpEnter </dev/tty
}

function reSync() {
    sudo systemctl disable Stone.service
    sudo systemctl stop Stone.service
    #replace addnodes need to add new cat func
    #sed -i "/\b\(addnode\)\b/d" ~/.stonecore/stone.conf
    #sleep 1
#cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
#addnode=$ADDNODE1
#addnode=$ADDNODE2
#EOF
    sleep 1
    mkdir ~/.stonebackups
    cp ~/.stonecore/stone.conf ~/.stonebackups/stone.conf
    sleep 2
    rm -r ~/.stonecore #/blocks ~/.stonecore/chainstate ~/.stonecore/database
    #rm ~/.stonecore #/peers.dat ~/.stonecore/mncache.dat ~/.stonecore/banlist.dat
    sleep 2
    #stone-cli stop
    addBootstrap
    sleep 1
    mv ~/.stonebackups/stone.conf ~/.stonecore/stone.conf
    sleep 1
    sudo systemctl enable Stone.service
    sudo systemctl start Stone.service
    echo -e "Finishing up..."
    sleep 5
    upgradeInfo
}

function clearBanned() {
    echo -e "Doing some maintenance..."
    sleep 2
    $COIN_CLI clearbanned
    $COIN_CLI stop
    sleep 5
}

function goodBye() {
 clear
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}  TTTTTTT  OOOOO  NN   NN EEEEEEE  CCCCC  OOOOO  IIIII NN   NN     RRRRRR   OOOOO   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e    "${GREEN}  \$\$${NC}${CYAN}        TTT   OO   OO NNN  NN EE      CCC    OO   OO  III  NNN  NN     RR   RR OO   OO CCC    KK KK  ${NC}${GREEN}\$\$      ${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT   OO   OO NN N NN EEEEE   CC     OO   OO  III  NN N NN     RRRRRR  OO   OO CC     KKKK    ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e    "${GREEN}       \$\$${NC}${CYAN}   TTT   OO   OO NN  NNN EE      CCC    OO   OO  III  NN  NNN ${NC}${GREEN}dot${NC}${CYAN} RR  RR  OO   OO CCC    KK KK       ${NC}${GREEN}\$\$ ${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT    OOOO0  NN   NN EEEEEEE  CCCCC  OOOO0  IIIII NN   NN ${NC}${GREEN}dot${NC}${CYAN} RR   RR  OOOO0   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${GREEN}Hope you enjoyed another script from STONE${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${PURPLE}We're sorry to see you go, come back soon!${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 exit 1
}

function newInstallInfo() {
 clear
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}  TTTTTTT  OOOOO  NN   NN EEEEEEE  CCCCC  OOOOO  IIIII NN   NN     RRRRRR   OOOOO   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e    "${GREEN}  \$\$${NC}${CYAN}        TTT   OO   OO NNN  NN EE      CCC    OO   OO  III  NNN  NN     RR   RR OO   OO CCC    KK KK  ${NC}${GREEN}\$\$      ${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT   OO   OO NN N NN EEEEE   CC     OO   OO  III  NN N NN     RRRRRR  OO   OO CC     KKKK    ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e    "${GREEN}       \$\$${NC}${CYAN}   TTT   OO   OO NN  NNN EE      CCC    OO   OO  III  NN  NNN ${NC}${GREEN}dot${NC}${CYAN} RR  RR  OO   OO CCC    KK KK       ${NC}${GREEN}\$\$ ${NC}"
 echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT    OOOO0  NN   NN EEEEEEE  CCCCC  OOOO0  IIIII NN   NN ${NC}${GREEN}dot${NC}${CYAN} RR   RR  OOOO0   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${GREEN}$mnAlias $NODEIP:$COIN_PORT $COINKEY $mnTx $mnIndex${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${PURPLE}Full Setup Guide. https://github.com/stonecoinproject/stonemnsetup/${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${CYAN}Ensure Node is fully SYNCED with BLOCKCHAIN.${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${PURPLE}Usage Commands.${NC}"
 echo -e "${PURPLE}Check masternode status: $COIN_CLI masternode status${NC}"
 echo -e "${PURPLE}Check blockchain status: $COIN_CLI getinfo${NC}"
 echo -e "${PURPLE}Restart daemon: $COIN_CLI stop${NC}"
 echo -e "${PURPLE}VPS Configuration file location:${NC}${CYAN}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${CYAN}Follow in Discord to stay updated.  https://discord.gg/8u7U3gh${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${RED}Donations go towards STONE development${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 echo -e "${YELLOW}STONE: Si8dAZHaP1utVqxJJf1t2KVU6cBkk6FrVz${NC}"
 echo -e "${YELLOW}BTC: 3QFJ9UTJGbBHBYqZsqTzXHyxifML44Wdyp${NC}"
 echo -e "${YELLOW}XMR: 445kB5Mxzj5LKeTt6RrgTvciqnPVT4HgyE4zN3grJTvaEyrCMuCPAyx7Kah3bq2RBZMoTauDDVFVvBuKcer5NnCKDoeT9DW${NC}"
 echo -e "${YELLOW}LTC: LgdPXvnYRvQoAVGZq2SUomZwkbv4Hjecok${NC}"
 echo -e "${YELLOW}RAVEN: RKUaCMEKqJi3ERnbEXXh9M3LKTK79hJuSt${NC}"
 echo -e "${BLUE}==================================================================================================================${NC}"
 exit 1
}

function upgradeInfo() {
  clear
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}  TTTTTTT  OOOOO  NN   NN EEEEEEE  CCCCC  OOOOO  IIIII NN   NN     RRRRRR   OOOOO   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
  echo -e    "${GREEN}  \$\$${NC}${CYAN}        TTT   OO   OO NNN  NN EE      CCC    OO   OO  III  NNN  NN     RR   RR OO   OO CCC    KK KK  ${NC}${GREEN}\$\$      ${NC}"
  echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT   OO   OO NN N NN EEEEE   CC     OO   OO  III  NN N NN     RRRRRR  OO   OO CC     KKKK    ${NC}${GREEN}\$\$\$\$\$  ${NC}"
  echo -e    "${GREEN}       \$\$${NC}${CYAN}   TTT   OO   OO NN  NNN EE      CCC    OO   OO  III  NN  NNN ${NC}${GREEN}dot${NC}${CYAN} RR  RR  OO   OO CCC    KK KK       ${NC}${GREEN}\$\$ ${NC}"
  echo -e "${GREEN}   \$\$\$\$\$${NC}${CYAN}    TTT    OOOO0  NN   NN EEEEEEE  CCCCC  OOOO0  IIIII NN   NN ${NC}${GREEN}dot${NC}${CYAN} RR   RR  OOOO0   CCCCC KK  KK  ${NC}${GREEN}\$\$\$\$\$  ${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${PURPLE}Congratulations! You've just upgraded your masternode.${NC}"
  echo -e "${PURPLE}We hope you enjoyed another Stone simple script!${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${PURPLE}Usage Commands.${NC}"
  echo -e "${PURPLE}Check version info: $COIN_DAEMON --version${NC}"
  echo -e "${PURPLE}Check masternode status: $COIN_CLI masternode status${NC}"
  echo -e "${PURPLE}Check blockchain status: $COIN_CLI getinfo${NC}"
  echo -e "${PURPLE}Restart daemon: $COIN_CLI stop${NC}"
  echo -e "${PURPLE}Help faster sync snd unstuck: $COIN_CLI clearbanned${NC}"
  echo -e "${PURPLE}VPS Configuration file location:${NC}${CYAN}$CONFIGFOLDER/$CONFIG_FILE${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${CYAN}Follow in Discord to stay updated.  https://discord.gg/8u7U3gh${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${RED}Donations go towards STONE development${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  echo -e "${YELLOW}STONE: Si8dAZHaP1utVqxJJf1t2KVU6cBkk6FrVz${NC}"
  echo -e "${YELLOW}BTC: 3QFJ9UTJGbBHBYqZsqTzXHyxifML44Wdyp${NC}"
  echo -e "${YELLOW}XMR: 445kB5Mxzj5LKeTt6RrgTvciqnPVT4HgyE4zN3grJTvaEyrCMuCPAyx7Kah3bq2RBZMoTauDDVFVvBuKcer5NnCKDoeT9DW${NC}"
  echo -e "${YELLOW}LTC: LgdPXvnYRvQoAVGZq2SUomZwkbv4Hjecok${NC}"
  echo -e "${YELLOW}RAVEN: RKUaCMEKqJi3ERnbEXXh9M3LKTK79hJuSt${NC}"
  echo -e "${BLUE}==================================================================================================================${NC}"
  exit 1
}

function newInstall() {
   while true; do
       echo "You chose to install a new STONE masternode."
       read -p "Are you sure? (y/n): " yn </dev/tty
       case $yn in
           [Yy]* ) echo "This may take some time, be patient and wait for the prompts."; sleep 2; installNode;;
           [Nn]* ) echo "Restarting..."; sleep 2; clear; mainMenu; exit;;
           * ) echo "Please answer yes or no.";;
       esac
   done
 }
function unInstallConf() {
   while true; do
       echo "You chose to remove your STONE masternode."
       read -p "Are you sure? (y/n): " yn </dev/tty
       case $yn in
           [Yy]* ) echo "This will only take a moment"; sleep 2; unInstall;;
           [Nn]* ) echo "Restarting..."; sleep 2; clear; mainMenu; exit;;
           * ) echo "Please answer yes or no.";;
       esac
   done
}

function upgradeOnly() {
   while true; do
       echo "You chose to upgrade your existing STONE masternode."
       read -p "Are you sure? (y/n): " yn </dev/tty
       case $yn in
           [Yy]* ) echo "This should only take a moment."; sleep 2; upgradeNode;;
           [Nn]* ) echo "Restarting..."; sleep 2; clear; mainMenu; exit;;
           * ) echo "Please answer yes or no.";;
       esac
   done
 }

function reSyncConf() {
   while true; do
       echo "You chose to resync your existing STONE masternode."
       read -p "Are you sure? (y/n): " yn </dev/tty
       case $yn in
           [Yy]* ) echo "This should only take a moment."; sleep 2; reSync;;
           [Nn]* ) echo "Restarting..."; sleep 2; clear; mainMenu; exit;;
           * ) echo "Please answer yes or no.";;
       esac
   done
 }

function newGenKeyConf() {
    while true; do
        echo "You chose to install the STONE Sync Manager."
        read -p "Are you sure? (y/n): " yn </dev/tty
        case $yn in
            [Yy]* ) echo "This should only take a moment."; sleep 2; newGenKey;;
            [Nn]* ) echo "Restarting..."; sleep 2; clear; mainMenu; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

function mainMenu(){
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #Blue
    NUMBER=`echo "\033[33m"` #yellow
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`

    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}****Welcome to the STONE Masternode Setup****${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NUMBER} 1)${MENU} New Install                          **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Upgrade only                         **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 3)${MENU} Resync                               **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 4)${MENU} Install Sync Manager                 **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Uninstall                            **${NORMAL}"
    echo -e "${MENU}**${NUMBER} 6)${MENU} Exit                                 **${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Enter option and press enter or ${RED_TEXT}enter to exit. ${NORMAL}"
    echo -e "${ENTER_LINE}Note: You must complete new install if you are upgrading from pre x16r${NORMAL}"
    read opt </dev/tty
    menuLoop
}

function menuLoop() {

while [ opt != '' ]
    do
        case $opt in
        1)newInstall;
        ;;
        2)upgradeOnly;
        ;;
        3)reSyncConf;
        ;;
        4)newGenKeyConf;
        ;;
        5)unInstallConf;
        ;;
        6)echo -e "Exiting...";sleep 1;exit 0;
        ;;
        \n)exit 0;
        ;;
        *)clear;
        "Pick an option from the menu";
        mainMenu;
        ;;
    esac
done
}

function upgradeNode() {
  #purgeOldInstallation #Removed from upgrade only, use resync if necessary
  download_node
  configure_systemd
  clearBanned
  upgradeInfo
}

function installNode() {
  purgeOldInstallation
  prepare_system #some vps do not have curl preinstalled
  download_node
  get_ip
  addBootstrap
  create_config
  create_key
  update_config
  enable_firewall
  configure_systemd
  clearBanned
  installSyncManager
  masternode_info
  newInstallInfo
}

function newGenKey() {
 # wipe_config
 # get_ip
 # create_config
 # create_key
 # update_config
 # reEnableSystemd
 # masternode_info
  installSyncManager
  newInstallInfo
}

function unInstall() {
    purgeOldInstallation
    echo -e "Finalilzing the cleanup..."
    sleep 5
    goodBye
}
##### Main #####

clear
mainMenu
