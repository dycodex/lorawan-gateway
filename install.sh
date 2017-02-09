#!/bin/bash

set -e

if [ $UID != 0 ]; then
  echo "ERROR: Please run as root!"
  exit 1
fi

echo "Installing Lora-net packet forwarder"

GATEWAY_EUI_NIC="eth0"
if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
  GATEWAY_EUI_NIC="wlan0"
fi

if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
  echo "ERROR: No network interface found. Cannot set gateway ID."
  exit 1
fi

GATEWAY_EUI=$(ip link show $GATEWAY_EUI_NIC | awk '/ether/ {print $2}' | awk -F\: '{print $1$2$3"FFFE"$4$5$6}')
GATEWAY_EUI=${GATEWAY_EUI^^}

echo "Detected EUI $GATEWAY_EUI from $GATEWAY_EUI_NIC"

INSTALL_DIR="/opt/lorawan-gateway"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi

pushd $INSTALL_DIR

if [ ! -d lora_gateway ]; then
  git clone https://github.com/Lora-net/lora_gateway.git
  pushd lora_gateway
else
  pushd lora_gateway
  git reset --hard
  git pull
fi

make

popd

if [ ! -d packet_forwarder ]; then
  git clone https://github.com/Lora-net/packet_forwarder.git
  pushd packet_forwarder
else
  pushd packet_forwarder
  git reset --hard
  git pull
fi

make

popd

if [ ! -d bin ]; then mkdir bin; fi
if [ -f ./bin/lora_pkt_fwd ]; then rm ./bin/lora_pkt_fwd; fi
ln -s $INSTALL_DIR/packet_forwarder/lora_pkt_fwd/lora_pkt_fwd ./bin/lora_pkt_fwd
cp -f ./packet_forwarder/lora_pkt_fwd/global_conf.json ./bin/global_conf.json

LOCAL_CONFIG_FILE=$INSTALL_DIR/bin/local_conf.json
if [ -e $LOCAL_CONFIG_FILE ]; then rm $LOCAL_CONFIG_FILE; fi;

echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\":\"$GATEWAY_EUI\",\n\t\t\"server_address\": \"localhost\", \n\t\t\"serv_port_up\":1700, \n\t\t\"serv_port_down\": 1700, \n\t\t\"serv_enabled\": true,\n\t\t\"contact_email\":\"\",\n\t\t\"description\": \"LoRaWAN Gateway\" \n\t}\n}" >$LOCAL_CONFIG_FILE

popd

echo "Installation completed."
cp ./start.sh $INSTALL_DIR/bin/
cp ./lorawan-gateway.service /lib/systemd/system/
systemctl enable lorawan-gateway.service

echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now