AirTag-tools
=============

These are some simple scripts for automating discovery and creation of Apple AirTags BLE Beacon formats, for both unregistered and registered AiTags using a computer running Linux and a Bluetooth LE adapter.

What You Need
-------------

You need a computer capable of running Linux.  It can be a desktop or notebook PC, or any
of the various single-board computers that are popular nowadays such as the [Raspberry Pi][PI].  

Your version of Linux must be compatible with the new [Bluetooth 4.0 Low Energy (LE)][BLE] standard.
Currently this requires version 3.5 or greater of the Linux kernel.  You will
also need version 5.0 or greater of [BlueZ][BLUEZ], the Linux Bluetooth stack and associated
tools.

On most Linux distributions, BlueZ can be easily installed from your distribution's package
manager.  E.g., for Debian and Debian derivatives (Ubuntu, etc.):

`sudo apt-get install bluetooth bluez-utils blueman`

Your computer must also have a Bluetooth adapter (either built-in or USB) that is compatible with
the [Bluetooth 4.0 LE][BLE] standard.  To test whether your adapter is LE-compatible, issue the
following command:

`sudo hcitool lescan`

If you see either nothing, or a list of MAC addresses (`aa:bb:cc:dd:ee:ff`) then your adapter
supports Bluetooth LE.  If, on the other hand, you see any error messages in the output, then
your adapter does not support LE.  (This command will continuously scan for devices, so to exit
it press `Control-C.)

This scripts must be run with `root` privileges in order to configure Bluetooth adapters.  It is most convenient to run it using `sudo.`

By default, the `AirTag-create` script uses fixed keys and payloads, as opposed to rotating content (and if uncommented, fixed BD_ADDR).

