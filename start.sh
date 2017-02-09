#!/bin/bash

RESET_PIN=7
WAIT_TIME=0.1

if [ $(id -u) -ne "0" ]
then
  echo "ERROR: please run as root"
  exit 1
fi

if [ ! -d /sys/class/gpio/gpio$RESET_PIN ]
then
  echo "$RESET_PIN" > /sys/class/gpio/export
  sleep $WAIT_TIME
fi

echo "out" > /sys/class/gpio/gpio$RESET_PIN/direction
sleep $WAIT_TIME
echo "1" > /sys/class/gpio/gpio$RESET_PIN/value
sleep $WAIT_TIME
echo "0" > /sys/class/gpio/gpio$RESET_PIN/value

echo "Gateway reset successfully"

while [[ $(ping -c1 google.com 2>&1 | grep " 0% packet loss") == "" ]]; do
  echo "[LoRaWAN Gateway]: Waiting for internet connection..."
  sleep 30
  done

./lora_pkt_fwd
