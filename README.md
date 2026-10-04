# jiuyin-d80-cups

A CUPS driver for the **Jiuyin D80** portable A4/Letter thermal printer over
Bluetooth, so it works as a normal Linux printer from any application.

The D80 is sold under several names as an "inkless" portable printer. It
ships with only phone and Windows apps, and despite the name it is **not** an
80 mm receipt printer: it prints 208 mm wide on A4/Letter thermal paper, cut
sheets or fanfold. It ignores plain text and standard ESC/POS text commands,
so generic receipt-printer drivers silently print nothing.

## Status

| | |
|---|---|
| Tested | D80, firmware 1.0.1, fanfold US Letter, Fedora 44, CUPS 2.4, BlueZ 5.87 |
| Likely to work | D20, D21, N12, N12A, N20, N80, N81: the vendor app drives them with the same protocol, but print width and paper handling may differ |
| Untested | Density setting, A4 output, compressed transfer (not implemented) |

Reports from owners of other models are very welcome. Open an issue with the
output of `d80-status` and what printed.

## How it works

```
any app ──► CUPS ──► gstoraster ──► rastertod80 ──► bluetooth:// backend ──► printer
                    (1-bit, 203 dpi)  (NadaProtocol)  (bluez-cups, SPP)
```

`rastertod80` turns CUPS raster into the printer's own commands: uncompressed
mode, then one `GS v 0` image per page. Every page is padded to the exact
physical page length (2235 rows for Letter, 2376 for A4), so multi-page jobs
stay aligned with fanfold perforations. The protocol is documented in
[PROTOCOL.md](PROTOCOL.md).

## Install

Requirements: CUPS with cups-filters (Ghostscript), BlueZ with the CUPS
backend (`bluez-cups` on Fedora, `bluez-cups` on Debian/Ubuntu), Python 3.

1. **Pair the printer** (it appears as `D80`):

   ```sh
   bluetoothctl
   [bluetooth]# scan on
   [bluetooth]# pair AA:BB:CC:DD:EE:FF
   [bluetooth]# quit
   ```

   Don't mark it as trusted. The printer advertises fake headset/audio
   profiles, and a trusted device makes BlueZ keep trying to connect audio
   to it.

2. **Check it answers**:

   ```sh
   ./d80-status AA:BB:CC:DD:EE:FF
   ```

   ```
   firmware     v1.0.1
   battery      60%
   paper        loaded
   cover        closed
   ...
   ```

3. **Install the driver**:

   ```sh
   sudo make install
   ```

4. **Fedora / RHEL only: allow CUPS to use Bluetooth.** Fedora ships
   `bluez-cups`, but its SELinux policy blocks the backend from creating a
   Bluetooth socket (`avc: denied { create } ... comm="bluetooth" ...
   tclass=bluetooth_socket`), and no boolean covers it. This small module
   allows exactly that:

   ```sh
   sudo make selinux        # remove later with: sudo make selinux-remove
   ```

5. **Create the queue.** The URI is the MAC address without colons:

   ```sh
   sudo lpadmin -p D80 -E -v bluetooth://AABBCCDDEEFF \
       -P /usr/share/cups/model/jiuyin-d80.ppd -D "Jiuyin D80"
   lp -d D80 /usr/share/cups/data/testprint
   ```

   `lpadmin` will warn that printer drivers are deprecated. PPD drivers still
   work in CUPS 2.x.

## Options

| Option | Values | Default |
|---|---|---|
| `PageSize` | `Letter`, `A4` | `Letter` |
| `Darkness` | `Default`, `1`–`4` | `Default` (leave the printer's setting alone) |

```sh
lp -d D80 -o PageSize=A4 -o Darkness=3 document.pdf
lpoptions -p D80 -o Darkness=3      # make it the default
```

## Troubleshooting

- **Red power LED, nothing prints.** The paper isn't seated. Push it in
  until the printer grabs it; the LED turns green when it's ready.
- **Job held, "Can't open Bluetooth connection".** On Fedora/RHEL this is
  SELinux; see step 4. Elsewhere, check the printer is on and that
  `d80-status` can reach it.
- **"Host is down" / disconnects after a few seconds.** Normal when idle.
  The backend connects for each job.
- **Bluetooth adapter keeps resetting** (`hciN: command 0x.... tx timeout`
  in `dmesg`). This is a USB autosuspend problem with some dongles, not the
  printer. `options btusb enable_autosuspend=0` in
  `/etc/modprobe.d/btusb.conf` fixes it.

## Uninstall

```sh
sudo lpadmin -x D80
sudo make uninstall
sudo make selinux-remove   # Fedora/RHEL, if installed
```

## Legal

Not affiliated with Zhuhai Jiuyin or any printer vendor; names are used only
to identify compatible hardware. The protocol was worked out for
interoperability by observing the vendor app's behaviour. No vendor code is
included.

Licensed under the GNU General Public License v3.0; see [LICENSE](LICENSE).
