#!/bin/bash

# Created by Larry Pesce (@haxorthematrix) to transmit both types of AirTag beacons
# using fixed values, keys and BD_ADDR from a device created by OpenHaystack.

INTERFACE="hci0"
DELAY=2
GUI=0
beacon=""

usage() {
    cat <<EOF
Usage: $0 [-r|-u] [-i hciN] [-d seconds] [-g]
  -r, --registered        Transmit registered AirTag beacon
  -u, --unregistered      Transmit unregistered AirTag beacon
  -i, --interface hciN    Bluetooth interface (default: hci0)
  -d, --delay SECONDS     Delay between re-arming advertising (default: 2)
  -g, --gui               Pick options via yad GUI
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--unregistered)  beacon="u"; shift ;;
    -r|--registered)    beacon="r"; shift ;;
    -i|--interface)     INTERFACE="$2"; shift 2 ;;
    -d|--delay)         DELAY="$2"; shift 2 ;;
    -g|--gui)           GUI=1; shift ;;
    -h|--help)          usage; exit 0 ;;
    -*|--*)
        echo "Unknown option $1"
        usage
        exit 1
        ;;
    *) shift ;;
  esac
done

if [[ $GUI -eq 1 ]]; then
    command -v yad >/dev/null 2>&1 || { echo "yad not installed: sudo apt install yad"; exit 1; }
    ifaces=$(hciconfig 2>/dev/null | awk '/^hci/ {sub(":",""); print $1}' | paste -sd '!' -)
    [[ -z "$ifaces" ]] && ifaces="hci0"
    out=$(yad --title="AirTag Beacon Transmitter" --form --width=360 \
        --field="Interface:CB" "$ifaces" \
        --field="Beacon Type:CB" "unregistered!registered" \
        --field="Delay (sec):NUM" "$DELAY!1..60!1") || exit 0
    INTERFACE=$(echo "$out" | cut -d'|' -f1)
    btype=$(echo "$out" | cut -d'|' -f2)
    DELAY=$(echo "$out" | cut -d'|' -f3 | cut -d'.' -f1 | cut -d',' -f1)
    [[ "$btype" == "registered" ]] && beacon="r" || beacon="u"
fi

if [[ -z "$beacon" ]]; then
    echo "Error: must specify -r/--registered or -u/--unregistered (or use -g/--gui)."
    usage
    exit 1
fi

# sets BD_ADDR using the fixed address of d15292e23dec
# Not all devices support this and will hang. Tested on the Parani Sena UD-100 which hangs.
# This may work with a Raspberry Pi.
# sudo hcitool -i "$INTERFACE" cmd 0x3f 0x001 0xec 0x3d 0xe2 0x92 0x52 0xd1
#
# Confirm the BD_ADDR change with:
# sudo hcitool cmd 0x04 0x009

# hciconfig is the correct tool to bring the radio up; the prior hcitool form was invalid
sudo hciconfig "$INTERFACE" up || { echo "Failed to bring up $INTERFACE"; exit 1; }

cleanup() {
    echo
    echo "Stopping advertising on $INTERFACE..."
    sudo hcitool -i "$INTERFACE" cmd 0x08 0x000a 00 >/dev/null 2>&1
    exit 0
}
trap cleanup INT TERM

if [[ $beacon == "u" ]]; then
    label="unregistered"
    # AirTag payload 1eff4c000719006725acc77b7e7a5cb8b8050519a2f6748a5ac7a00b890100
    DATA="1f 1e ff 4c 00 07 19 00 67 25 ac c7 7b 7e 7a 5c b8 b8 05 05 19 a2 f6 74 8a 5a c7 a0 0b 89 01 00"
else
    label="registered"
    # AirTag payload 1eff4c001219006725acc77b7e7a5cb8b8050519a2f6748a5ac7a00b890100
    DATA="1f 1e ff 4c 00 12 19 00 67 25 ac c7 7b 7e 7a 5c b8 b8 05 05 19 a2 f6 74 8a 5a c7 a0 0b 89 01 00"
fi

echo "Transmitting $label AirTag beacon on $INTERFACE every ${DELAY}s. Ctrl-C to stop."

# HCI reset; pause so adapters that need settle time don't reject the next command
sudo hcitool -i "$INTERFACE" cmd 0x03 0x0003 >/dev/null
sleep 0.3

# Set advertising parameters once (interval 0x07d0 * 0.625ms = 1.25s)
sudo hcitool -i "$INTERFACE" cmd 0x08 0x0006 d0 07 d0 07 03 00 00 00 00 00 00 00 00 07 00
sleep 0.2

count=0
while :; do
    # Some adapters silently drop the advertising state; re-arming each loop is a workaround
    sudo hcitool -i "$INTERFACE" cmd 0x08 0x0008 $DATA >/dev/null
    sleep 0.1
    sudo hcitool -i "$INTERFACE" cmd 0x08 0x000a 01 >/dev/null
    count=$((count + 1))
    printf "\r  sent %d frames" "$count"
    sleep "$DELAY"
done
