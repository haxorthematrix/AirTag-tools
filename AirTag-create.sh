#!/bin/bash

# Created by Larry Pesce (@haxorthematrix) to trasnsmit for both types of AirTag beacons
# using fixed values, keys and BD_ADDR from a device created by OpenHaystatk

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--unregistered)
      beacon="u"
      shift # past argument
      shift # past value
      ;;
    -r|--registered)
      beacon="r"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      echo "A required option for a registered (-r --registered) or unregistered (-u --unregistetered) beacon was not found."
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# sets BD_ADDR using the fixed address of d15292e23dec
# Not all devices supprt this and will hang.  Tested on the Parani Sena UD-100 which hangs.
# This may work with a Raspberry pi.

# sudo hcitool -i hci0 cmd 0x3f 0x001 0xec 0x3d 0xe2 0x92 0x52 0xd1

# We don't need to for this example, but we should be able to confirm the BD_ADDR change with:
# sudo hcitool cmd 0x04 0x009

sudo hcitool hci0 up #Make sure that our radio is up

if [[ $beacon == "u" ]]; then
    # sends beacon using the following data:
    # AirTag key 515292e23dec6725acc77b7e7a5cb8b8050519a2f6748a5ac7a00b89
    # AirTag payload 1eff4c001219006725acc77b7e7a5cb8b8050519a2f6748a5ac7a00b890100
    echo "Sending an unregistered AirTag beacon:"
    sudo hcitool -i hci0 cmd 0x03 0x0003 #HCI reset
    sudo hcitool -i hci0 cmd 0x08 0x0008 1f 1e ff 4c 00 07 19 00 67 25 ac c7 7b 7e 7a 5c b8 b8 05 05 19 a2 f6 74 8a 5a c7 a0 0b 89 01 00
    sudo hcitool -i hci0 cmd 0x08 0x0006 d0 07 d0 07 03 00 00 00 00 00 00 00 00 07 00
    sudo hcitool -i hci0 cmd 0x08 0x000a 01
fi


if [[ $beacon == "r" ]]; then
    # sends beacon using the following data:
    # AirTag key 515292e23dec6725acc77b7e7a5cb8b8050519a2f6748a5ac7a00b89
    # AirTag payload 1eff4c000719006725acc77b7e7a5cb8b8050519a2f6748a5ac7a00b890100
    echo "Sending a registered AirTag beacon:"
    sudo hcitool -i hci0 cmd 0x03 0x0003 # HCI reset
    sudo hcitool -i hci0 cmd 0x08 0x0008 1f 1e ff 4c 00 12 19 00 67 25 ac c7 7b 7e 7a 5c b8 b8 05 05 19 a2 f6 74 8a 5a c7 a0 0b 89 01 00
    sudo hcitool -i hci0 cmd 0x08 0x0006 d0 07 d0 07 03 00 00 00 00 00 00 00 00 07 00
    sudo hcitool -i hci0 cmd 0x08 0x000a 01
fi

echo "Exiting. Nothing to do."
