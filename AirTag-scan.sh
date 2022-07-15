#!/bin/bash
# based off of iBeacon Scan by Radius Networks
# Modified by Larry Pesce (@haxorthematrix) to hunt for both types of AirTag beacons

if [[ $1 == "parse" ]]; then
  packet=""
  capturing=""
  count=0
  while read line
  do
    count=$[count + 1]
    if [ "$capturing" ]; then
      if [[ $line =~ ^[0-9a-fA-F]{2}\ [0-9a-fA-F] ]]; then
        packet="$packet $line"
      else
        if [[ $packet =~ ^04\ 3E\ 2B\ 02\ 01\ .{26}\ 1E\ FF\ 4C\ 00\ 12\ 19 ]]; then
          echo "Registered AirTag Found!"
          echo ${packet:0:138}
        else
          if [[ $packet =~ ^04\ 3E\ 2B\ 02\ 01\ .{26}\ 1E\ FF\ 4C\ 00\ 07\ 19 ]]; then
            echo "Unregistered AirTag Found!"
            echo ${packet:0:138}
          fi
        capturing=""
        packet=""
        fi
      fi
    fi
    if [ ! "$capturing" ]; then
      if [[ $line =~ ^\> ]]; then
        packet=`echo $line | sed 's/^>.\(.*$\)/\1/'`
        capturing=1
      fi
    fi
  done
else
  sudo hcitool lescan --duplicates 1>/dev/null &
  if [ "$(pidof hcitool)" ]; then
    sudo hcidump --raw | ./$0 parse $1
  fi
fi
