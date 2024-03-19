# downgr8

This is a tool for launching the "expert mode" update UI on LG webOS TVs. It
works on firmware versions where the [easier method](#old-method) of
accessing expert mode has been removed. So far, little to no provision has been
made for novice users.

**Note that this tool requires you to already have root access on your TV.**


## Warning

**Use this tool at your own risk.** It has not been thoroughly tested&mdash;or,
in some cases, tested at all. It's intended for people who already know what
they're doing. I will probably not provide any support.

The C part is pretty reliable, and the service seems to mostly work. However,
the app, which consists of a script that makes a series of requests to the
service, may or may not work. I recommend using it primarily as an example of
the order in which to call the service's methods.


### General downgrade warning

Be aware that firmware downgrades have never really been supported by LG. I have
not personally encountered any issues, but it's possible that you could get your
TV into an unrecoverable state (i.e., "brick" it). Be especially careful on
webOS 4+ TVs, as it's easier to get those into a state where
[recovery](#recovery) is impossible.

I would suggest using USB rather than NSU images whenever possible. Because they
are intended to update a TV from one mostly known state to another, NSU images
often do not contain data for all of the TV's partitions. In some situations,
NSU updates are intended to be applied in a certain order, and I don't know if
or how this could affect downgrading. USB images, which are the kind you can
download from LG's support site, seem to always contain all partitions.

Make sure you are using the right firmware image for your TV. In particular,
ensure you have the correct:

  1. **Version** &ndash; Keep in mind exactly what version you intend to install.
  2. **Region** &ndash; Through webOS 5, there are separate firmware images for
   each tuner type (`atsc`, `dvb`, `arib`). Starting with webOS 6, there should
   only be universal (`global`) images.
  3. **SoC** &ndash; I'm not sure whether `update` will let you install firmware
   for the wrong SoC, but I'd rather not find out.

Every TV and firmware image have an identifier called an OTAID that encodes the
SoC and tuner type. Don't try to install any firmware that doesn't match your
TV's OTAID. You can get your TV's OTAID by running this command from a root
shell:

```sh
luna-send -q 'model_name' -n 1 'luna://com.webos.service.update/getCurrentSWInformation' '{}'
```

The OTAID of a firmware image is displayed when extracting it using
[`epk2extract`](https://github.com/openlgtv/epk2extract).


## Requirements

1. TV running LG webOS 3.0+ and firmware that has the [old method](#old-method)
   of accessing expert mode patched.
2. Root access to your TV.
3. [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
   installed and elevated (i.e., showing "root status: ok") on your TV.

Homebrew Channel is not strictly necessary as long as you can make sure the
`lol.downgr8.service` service is running as root.


## Details

In order to install older firmware versions (downgrade) or install firmware
images with a type other than "USB" (e.g., NSU images), the webOS `update`
service needs to be in "expert mode".

Prior to early 2022, this could be accomplished [relatively simply](#old-method)
without root access. However, around the same time LG patched the
vulnerabilities used by
[RootMyTV](https://github.com/RootMyTV/RootMyTV.github.io/), they also changed
`update` to no longer rely on an easily modifiable external file to control
expert mode.

Since this patch, `update` keeps track of the state of expert mode internally
and refuses to enable it unless one of LG's "Access USB" devices is connected
and authenticated. Obtaining or emulating Access USB hardware is not feasible,
but with root access it is not necessary. We can simply convince `update` that
an Access USB device is present and authenticated regardless of reality.

There are multiple ways to accomplish this, and the method I chose was inspired
by [David Buchanan's](https://github.com/DavidBuchanan314)
[`sampatcher.py`](https://github.com/webosbrew/webos-homebrew-channel/blob/main/services/bin/sampatcher.py).

By editing a Luna URI in `update`'s memory, we can redirect future Access USB
requests to our own service. We then trigger `update` to recheck the current
Access USB status and reply that it is authenticated. Now we can successfully make
a request to enable expert mode.

All that remains is launching the update UI app with the correct parameters.


## Old Method <a id="old-method"></a>

For older firmware, this tool is not necessary because the following still
works:  

```sh
touch /tmp/usb-expertmode
luna-send -n 1 'luna://com.webos.applicationManager/launch' '{"id":"com.webos.app.softwareupdate","params":{"mode":"expert","flagUpdate":true}}'
```

This method was also never removed on webOS 1 and 2.

It works because the `update` service uses the existence of the file
`/tmp/usb-expertmode` to track whether expert mode is enabled. Since it's
located in `/tmp`, which is writable by anyone, root access is not required to
create it.

You can check whether this has been patched on your TV by running the following
as root:

```sh
strings /usr/sbin/update | fgrep -e /tmp/usb-expertmode
```

If you get any output, this method should still work on your TV.


## Recovery from failed downgrade/upgrade <a id="recovery"></a>

It *may* be possible to recover a non-booting TV if you can get into the
bootloader (U-Boot or lxboot). Bootloader access requires that the TV be in
DEBUG mode.

On webOS 3.x and earlier (i.e., 2015‒2017 models), you can enable DEBUG by
[directly modifying the setting in
NVM](https://gist.github.com/throwaway96/827ff726981cc2cbc46a22a2ad7337a1).
While the process is relatively straightforward, it does require certain
hardware tools and physical access to a chip on the TV's main board. On webOS 4
and newer, you will not be able to enable DEBUG if the system does not boot.

From the bootloader, you can manually rewrite the contents of each corrupted
partition on the eMMC. Partition data files can be extracted from firmware
images using [`epk2extract`](https://github.com/openlgtv/epk2extract).
Potential methods for transferring these files to the TV include USB drives,
TFTP over Ethernet, and Xmodem.

If you have webOS 4 or later and did not previously enable DEBUG, the only
option for recovery is directly reprogramming the eMMC. That would involve
either soldering wires to the board on the necessary signals (if you can find
them; accessing them may involve scraping away soldermask) or desoldering and
resoldering the eMMC IC.


## License

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.

See `LICENSE` for details.
