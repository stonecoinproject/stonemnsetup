#!/bin/bash

#EXPBLOCK=$(curl -s4 "http://explorer.stonecoin.rocks/api/getblockcount")
#EXPBLOCK="1500000" #used for mismatch testing
#EXPBLOCKLOW=$(expr $EXPBLOCK - 4)
#EXPBLOCKHIGH=$(expr $EXPBLOCK + 4)

BOOTSTRAPURL='https://github.com/stonecoinproject/Stonecoin/releases/download/Bootstrapv2.0/stonecore.tar.gz'

start(){
echo "$(date +%F_%T) **Initializing STONE Sync Manager**" >> ~/.stonesyncmanager/stonesync.log
isMnRunning
}

checkServer(){
echo "$(date +%F_%T) Pinging explorer.." >> ~/.stonesyncmanager/stonesync.log
EXPBLOCK=$(curl -s4 "http://explorer.stonecoin.rocks/api/getblockcount")
if [ "$EXPBLOCK" -eq "$EXPBLOCK" ];
then
  echo "$(date +%F_%T) Successful ping!" >> ~/.stonesyncmanager/stonesync.log
  checkBlock
else
  echo "$(date +%F_%T) **ERROR** STONE Explorer down, try again later!" >> ~/.stonesyncmanager/stonesync.log
  echo "$(date +%F_%T) Exiting!" >> ~/.stonesyncmanager/stonesync.log
  endLog
fi
}

isMnRunning(){
echo "$(date +%F_%T) Checking STONE service.." >> ~/.stonesyncmanager/stonesync.log
sleep 3
MNACTIVE=$(systemctl is-active Stone.service)
sleep 2
if [ $MNACTIVE = "active" ]; then
  echo "$(date +%F_%T) STONE service active!" >> ~/.stonesyncmanager/stonesync.log
  echo "$(date +%F_%T) Verifying block height.." >> ~/.stonesyncmanager/stonesync.log
  checkServer
  #printBlock
else
  reEnableSystemd
fi
}


printBlock(){
MNBLOCK=$(stone-cli getblockcount)
  echo -e "$MNBLOCK"
}

checkBlock(){
MNBLOCK=$(stone-cli getblockcount)
sleep 3
EXPBLOCK=$(curl -s4 "http://explorer.stonecoin.rocks/api/getblockcount")
sleep 3
echo "$(date +%F_%T) Masternode Block $MNBLOCK" >> ~/.stonesyncmanager/stonesync.log
echo "$(date +%F_%T) Explorer Block $EXPBLOCK" >> ~/.stonesyncmanager/stonesync.log
EXPBLOCKLOW=$(expr $EXPBLOCK - 4)
EXPBLOCKHIGH=$(expr $EXPBLOCK + 4)
if [ -z "$MNBLOCK" ] 
then
  echo "$(date +%F_%T) Daemon not reporting data, if this persists a resinstall may be required!" >> ~/.stonesyncmanager/stonesync.log
  echo "$(date +%F_%T) Exiting!" >> ~/.stonesyncmanager/stonesync.log
  endLog
else
  if [ "$MNBLOCK" -ge "$EXPBLOCKLOW" ] && [ "$MNBLOCK" -le "$EXPBLOCKHIGH" ]; then
    echo "$(date +%F_%T) Block height matches!" >> ~/.stonesyncmanager/stonesync.log
    complete
  else
    echo "$(date +%F_%T) Block mismatch, double checking.." >> ~/.stonesyncmanager/stonesync.log
    doubleCheckBlock
  fi
fi
}


doubleCheckBlock(){
sleep 60
MNBLOCK=$(stone-cli getblockcount)
EXPBLOCK=$(curl -s4 "http://explorer.stonecoin.rocks/api/getblockcount")
echo "$(date +%F_%T) Masternode Block $MNBLOCK" >> ~/.stonesyncmanager/stonesync.log
echo "$(date +%F_%T) Explorer Block $EXPBLOCK" >> ~/.stonesyncmanager/stonesync.log
EXPBLOCKLOW=$(expr $EXPBLOCK - 4)
EXPBLOCKHIGH=$(expr $EXPBLOCK + 4)
if [ "$MNBLOCK" -ge "$EXPBLOCKLOW" ] && [ "$MNBLOCK" -le "$EXPBLOCKHIGH" ]; then
  echo "$(date +%F_%T) Block Height matches!" >> ~/.stonesyncmanager/stonesync.log
  complete
else
  echo "$(date +%F_%T) Confirmed out of sync, running resync function.." >> ~/.stonesyncmanager/stonesync.log
  reSync
fi
}

reEnableSystemd() {
  echo "$(date +%F_%T) STONE daemon not running, attempting to re-enable.." >> ~/.stonesyncmanager/stonesync.log
  sleep 1
  systemctl daemon-reload
  sleep 3
  systemctl start Stone.service
  systemctl enable Stone.service >/dev/null 2>&1
  sleep 5
  MNACTIVE=$(systemctl is-active Stone.service)
  sleep 2
  if [ $MNACTIVE = "active" ]; then
    echo "$(date +%F_%T) STONE service active!" >> ~/.stonesyncmanager/stonesync.log
    echo "$(date +%F_%T) Verifying block height.." >> ~/.stonesyncmanager/stonesync.log
    isMnRunning
    #printBlock
  else
    echo "$(date +%F_%T) ERROR Unable to start STONE service, Please re-install using the official script!" >> ~/.stonesyncmanager/stonesync.log
    echo "$(date +%F_%T) STONE masternode tutorial can be found here: https://github.com/stonecoinproject/stonemnsetup" >> ~/.stonesyncmanager/stonesync.log
    echo "$(date +%F_%T) Exiting!" >> ~/.stonesyncmanager/stonesync.log
    endLog
  fi
}

endLog(){
echo "$(date +%F_%T) -------------------------------End Log-------------------------------" >> ~/.stonesyncmanager/stonesync.log
exit
}

function reSync() {
  echo "$(date +%F_%T) Disabling Stone.service.." >> ~/.stonesyncmanager/stonesync.log
  sudo systemctl disable Stone.service
  sudo systemctl stop Stone.service
  sleep 1
  echo "$(date +%F_%T) Creating config backup.." >> ~/.stonesyncmanager/stonesync.log
  mkdir ~/.stonebackups
  cp ~/.stonecore/stone.conf ~/.stonebackups/stone.conf
  sleep 2
  rm -r ~/.stonecore
  sleep 2
  echo "$(date +%F_%T) Add bootstrap.." >> ~/.stonesyncmanager/stonesync.log
  addBootstrap
  sleep 1
  echo "$(date +%F_%T) Restore config file.." >> ~/.stonesyncmanager/stonesync.log
  mv ~/.stonebackups/stone.conf ~/.stonecore/stone.conf
  sleep 1
  echo "$(date +%F_%T) Enable Stone.service.." >> ~/.stonesyncmanager/stonesync.log
  sudo systemctl enable Stone.service
  sudo systemctl start Stone.service
  sleep 5
  complete
}

function addBootstrap() {
  echo "$(date +%F_%T) Downloading bootstrap.." >> ~/.stonesyncmanager/stonesync.log
  cd ~/
  wget -q $BOOTSTRAPURL
  tar -xzf stonecore.tar.gz
  rm stonecore.tar.gz
  echo "$(date +%F_%T) Bootstrap implemented successfully!" >> ~/.stonesyncmanager/stonesync.log
  sleep 1
}

startMasternode(){
  echo "$(date +%F_%T) Starting masternode.." >> ~/.stonesyncmanager/stonesync.log
  $(stone-cli masternode start)
  complete
}

complete(){
  echo "$(date +%F_%T) STONE Sync Manager Complete!" >> ~/.stonesyncmanager/stonesync.log
  endLog
}

start
