AirTag-tools
=============

These are some simple scripts for automating discovery and creation of Apple AirTags BLE Beacon formats, for both unregistered and registered AirTags using a computer running Linux and a Bluetooth LE adapter.

What You Need
-------------

You need a computer capable of running Linux.  It can be a desktop or notebook PC, or any
of the various single-board computers that are popular nowadays such as the Raspberry Pi.

Your version of Linux must be compatible with the new Bluetooth 4.0 Low Energy (LE) (BLE) standard.
Currently this requires version 3.5 or greater of the Linux kernel.  You will
also need version 5.0 or greater of BlueZ, the Linux Bluetooth stack and associated
tools.

On most Linux distributions, BlueZ can be easily installed from your distribution's package
manager.  E.g., for Debian and Debian derivatives (Ubuntu, etc.):

`sudo apt-get install bluetooth bluez-utils blueman`

The optional GUI mode (`-g`/`--gui`) requires `yad`:

`sudo apt-get install yad`

Your computer must also have a Bluetooth adapter (either built-in or USB) that is compatible with
the [Bluetooth 4.0 LE][BLE] standard.  To test whether your adapter is LE-compatible, issue the
following command:

`sudo hcitool lescan`

If you see either nothing, or a list of MAC addresses (`aa:bb:cc:dd:ee:ff`) then your adapter
supports Bluetooth LE.  If, on the other hand, you see any error messages in the output, then
your adapter does not support LE.  (This command will continuously scan for devices, so to exit
it press `Control-C`.)

These scripts must be run with `root` privileges in order to configure Bluetooth adapters.  It is most convenient to run them using `sudo`.

By default, the `AirTag-create` script uses fixed keys and payloads, as opposed to rotating content (and if uncommented, fixed BD_ADDR).

Selecting a Bluetooth adapter
-----------------------------

Both scripts default to `hci0`.  If you have multiple adapters (e.g. a built-in radio plus a USB
dongle), use `-i`/`--interface` to pick which one to use.  Run `hciconfig` with no arguments to
list the adapters available on your system.

AirTag-create.sh
----------------

Transmits an AirTag advertising payload in a loop until you press `Ctrl-C`.  On exit it disables
advertising on the selected interface.

```
Usage: ./AirTag-create.sh [-r|-u] [-i hciN] [-d seconds] [-g]
  -r, --registered        Transmit registered AirTag beacon
  -u, --unregistered      Transmit unregistered AirTag beacon
  -i, --interface hciN    Bluetooth interface (default: hci0)
  -d, --delay SECONDS     Delay between re-arming advertising (default: 2)
  -g, --gui               Pick options via yad GUI
  -h, --help              Show this help
```

Examples:

```
sudo ./AirTag-create.sh -u                  # unregistered beacon on hci0
sudo ./AirTag-create.sh -r -i hci1 -d 1     # registered beacon on hci1, re-arm every 1s
sudo ./AirTag-create.sh -g                  # pick everything from a GUI
```

Notes:
- The script uses `hciconfig <iface> up` to bring the radio up; the previous `hcitool` form was
  invalid syntax on most BlueZ builds.
- Some adapters silently drop their advertising state shortly after it is enabled.  The script
  re-sends the advertising data and re-enables advertising on every loop iteration as a
  workaround.  The `--delay` flag controls how often this happens.

AirTag-scan.sh
--------------

Scans for advertising AirTag beacons on the selected adapter and prints what it finds.  Three
output modes are available.

```
Usage: ./AirTag-scan.sh [options]
  -i, --interface hciN  Bluetooth interface (default: hci0)
      --raw             Stream raw hex of matching packets
      --pretty          One readable line per beacon (default)
      --table           Live updating table of unique tags + beacon count
  -g, --gui             Pick options via yad GUI
  -h, --help            Show this help
```

Output modes:

- `--raw` — original behaviour.  Each matching packet is printed as raw hex bytes, scrolling
  past as new ones arrive.
- `--pretty` (default) — one line per beacon:
  `[HH:MM:SS] REG  AA:BB:CC:DD:EE:FF  RSSI: -67 dBm`
- `--table` — clears the screen and maintains a live-updating table of unique MAC addresses,
  beacon type, count of beacons seen from that MAC, last RSSI, and last-seen timestamp.  This
  mode needs a real terminal (it uses `tput`) — running it through a pipe or non-TTY redirect
  will not work.

Examples:

```
sudo ./AirTag-scan.sh                       # pretty mode on hci0
sudo ./AirTag-scan.sh --raw -i hci1         # raw hex on hci1
sudo ./AirTag-scan.sh --table               # live table on hci0
sudo ./AirTag-scan.sh -g                    # pick everything from a GUI
```

[BLE]: https://en.wikipedia.org/wiki/Bluetooth_Low_Energy
