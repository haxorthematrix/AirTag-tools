#!/bin/bash
# based off of iBeacon Scan by Radius Networks
# Modified by Larry Pesce (@haxorthematrix) to hunt for both types of AirTag beacons

INTERFACE="hci0"
MODE="pretty"   # raw | pretty | table
GUI=0

usage() {
    cat <<EOF
Usage: $0 [options]
  -i, --interface hciN  Bluetooth interface (default: hci0)
      --raw             Stream raw hex of matching packets
      --pretty          One readable line per beacon (default)
      --table           Live updating table of unique tags + beacon count
  -g, --gui             Pick options via yad GUI
  -h, --help            Show this help
EOF
}

# Internal entry: when invoked recursively (./script parse <mode>) we just
# read hcidump output on stdin and dispatch by mode. Kept for backwards
# compatibility with the original recursion pattern.
if [[ "$1" == "parse" ]]; then
    MODE="${2:-pretty}"
    INTERFACE="${3:-hci0}"
    PARSE_ONLY=1
fi

if [[ "$PARSE_ONLY" != "1" ]]; then
    while [[ $# -gt 0 ]]; do
      case $1 in
        -i|--interface) INTERFACE="$2"; shift 2 ;;
        --raw)          MODE="raw"; shift ;;
        --pretty)       MODE="pretty"; shift ;;
        --table)        MODE="table"; shift ;;
        -g|--gui)       GUI=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        -*|--*)         echo "Unknown option $1"; usage; exit 1 ;;
        *) shift ;;
      esac
    done
fi

if [[ $GUI -eq 1 ]]; then
    command -v yad >/dev/null 2>&1 || { echo "yad not installed: sudo apt install yad"; exit 1; }
    ifaces=$(hciconfig 2>/dev/null | awk '/^hci/ {sub(":",""); print $1}' | paste -sd '!' -)
    [[ -z "$ifaces" ]] && ifaces="hci0"
    out=$(yad --title="AirTag Scanner" --form --width=360 \
        --field="Interface:CB" "$ifaces" \
        --field="Output Mode:CB" "pretty!raw!table") || exit 0
    INTERFACE=$(echo "$out" | cut -d'|' -f1)
    MODE=$(echo "$out" | cut -d'|' -f2)
fi

# ---- parsing helpers ----

is_registered()   { [[ "$1" =~ ^04\ 3E\ .{2}\ 02\ 01\ .{26}\ 1E\ FF\ 4C\ 00\ 12\ 19 ]]; }
is_unregistered() { [[ "$1" =~ ^04\ 3E\ .{2}\ 02\ 01\ .{26}\ 1E\ FF\ 4C\ 00\ 07\ 19 ]]; }

extract_mac() {
    # BD_ADDR in the LE Advertising Report is little-endian at byte offsets 7..12
    local -a arr
    read -ra arr <<< "$1"
    printf '%s:%s:%s:%s:%s:%s' \
        "${arr[12]}" "${arr[11]}" "${arr[10]}" "${arr[9]}" "${arr[8]}" "${arr[7]}"
}

extract_rssi() {
    # RSSI is the last byte of the report; index = 14 + data_len
    local -a arr
    read -ra arr <<< "$1"
    local dlen=$((16#${arr[13]:-0}))
    local idx=$((14 + dlen))
    local b="${arr[$idx]:-}"
    [[ -z "$b" ]] && return
    local v=$((16#$b))
    (( v > 127 )) && v=$((v - 256))
    printf '%d' "$v"
}

emit_raw() {
    if is_registered "$1" || is_unregistered "$1"; then
        echo "${1:0:138}"
    fi
}

emit_pretty() {
    local kind=""
    if is_registered "$1"; then kind="REG"
    elif is_unregistered "$1"; then kind="UNREG"
    else return; fi
    local mac rssi ts
    mac=$(extract_mac "$1")
    rssi=$(extract_rssi "$1")
    ts=$(date +%H:%M:%S)
    printf "[%s] %-5s  %s  RSSI: %4s dBm\n" "$ts" "$kind" "$mac" "${rssi:-?}"
}

# ---- table mode state ----
declare -A T_TYPE T_COUNT T_RSSI T_SEEN

redraw_table() {
    tput cup 0 0
    tput ed
    printf "  AirTag scanner on %s — %d unique tag(s) — Ctrl-C to exit\n\n" \
        "$INTERFACE" "${#T_COUNT[@]}"
    printf "  %-19s  %-6s  %7s  %6s  %-10s\n" "MAC" "TYPE" "COUNT" "RSSI" "LAST SEEN"
    printf "  %-19s  %-6s  %7s  %6s  %-10s\n" \
        "-------------------" "------" "-------" "------" "----------"
    for mac in "${!T_COUNT[@]}"; do
        printf "  %-19s  %-6s  %7s  %6s  %-10s\n" \
            "$mac" "${T_TYPE[$mac]}" "${T_COUNT[$mac]}" "${T_RSSI[$mac]:-?}" "${T_SEEN[$mac]}"
    done
}

emit_table() {
    local kind=""
    if is_registered "$1"; then kind="REG"
    elif is_unregistered "$1"; then kind="UNREG"
    else return; fi
    local mac rssi
    mac=$(extract_mac "$1")
    rssi=$(extract_rssi "$1")
    T_TYPE[$mac]="$kind"
    T_COUNT[$mac]=$(( ${T_COUNT[$mac]:-0} + 1 ))
    T_RSSI[$mac]="${rssi:-?}"
    T_SEEN[$mac]="$(date +%H:%M:%S)"
    redraw_table
}

parse_stream() {
    local packet=""
    local capturing=""
    if [[ "$MODE" == "table" ]]; then
        tput civis 2>/dev/null
        tput clear
        redraw_table
    fi
    while read -r line; do
        if [[ -n "$capturing" ]]; then
            if [[ $line =~ ^[0-9a-fA-F]{2}\ [0-9a-fA-F] ]]; then
                packet="$packet $line"
                continue
            fi
            case "$MODE" in
                raw)    emit_raw    "$packet" ;;
                pretty) emit_pretty "$packet" ;;
                table)  emit_table  "$packet" ;;
            esac
            capturing=""
            packet=""
        fi
        if [[ -z "$capturing" && $line =~ ^\> ]]; then
            packet=$(echo "$line" | sed 's/^>.\(.*$\)/\1/')
            capturing=1
        fi
    done
}

# ---- main ----

if [[ "$PARSE_ONLY" == "1" ]]; then
    parse_stream
    exit 0
fi

cleanup() {
    [[ "$MODE" == "table" ]] && tput cnorm 2>/dev/null
    sudo pkill -f "hcitool -i $INTERFACE lescan" 2>/dev/null
    sudo pkill -f "hcidump -i $INTERFACE"       2>/dev/null
    exit 0
}
trap cleanup INT TERM

sudo hciconfig "$INTERFACE" up || { echo "Failed to bring up $INTERFACE"; exit 1; }

sudo hcitool -i "$INTERFACE" lescan --duplicates >/dev/null &
sleep 1

if ! pgrep -f "hcitool -i $INTERFACE lescan" >/dev/null; then
    echo "hcitool lescan failed to start on $INTERFACE"
    exit 1
fi

sudo hcidump -i "$INTERFACE" --raw | parse_stream
