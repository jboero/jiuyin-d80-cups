# Jiuyin "NadaProtocol"

Notes on the command set used by Jiuyin portable thermal printers, worked out
for interoperability from the behaviour of the vendor's Android app
(`com.zhuhaijiuyin.print` 2.16.3) and verified against a D80. The app uses this
same protocol for the **D20, D21, D80, N12, N12A, N20, N80 and N81**; only the
D80 has been tested.

## Transport

Bluetooth Classic SPP (UUID `00001101-...`), RFCOMM channel 1, service name
`JL_SPP` (JieLi Bluetooth SoC). The printer also advertises a `0xAF30` service
and a set of audio/headset/PBAP UUIDs; none of them are used for printing.

The printer stays silent until it receives a command it recognises. Plain text
and standard ESC/POS text commands are **silently ignored**: it prints raster
images only.

## Print head

| Model | Dots | Width  | Resolution         |
|-------|------|--------|--------------------|
| D80   | 1664 | 208 mm | 8 dots/mm (203 dpi) |

The app renders an A4 page as a 1664 × 2376 bitmap (297 mm × 8).

## Host → printer

All multi-byte values are little-endian.

| Bytes                       | Meaning                                         |
|-----------------------------|-------------------------------------------------|
| `1F 11 05 35 nn`            | Data mode: `00` uncompressed, `01` compressed   |
| `1F 11 05 02 nn`            | Density 1–4                                     |
| `1D 76 30 00 wL wH hL hH …` | Raster image (`GS v 0`), see below              |
| `1F 11 05 07`               | Query firmware version                          |
| `1F 11 05 08`               | Query battery                                   |
| `1F 11 05 09`               | Query serial number                             |
| `1F 11 05 0E`               | Query auto power-off time                       |
| `1F 11 05 11`               | Query paper state                               |
| `1F 11 05 12`               | Query cover state                               |
| `1F 11 05 13`               | Query print-head temperature                    |
| `1F 11 05 16`               | Paper-sensor calibration                        |
| `1F 11 05 2F`               | Query busy state                                |
| `1B 4E 06 07 nn`            | Set auto power-off time                         |
| `1B 4E 06 0A nn`            | Set paper type                                  |

### Raster

`1D 76 30 00`, then the width in **bytes** (`(dots + 7) / 8`) and the height in
rows, then `width × height` bytes of 1-bit pixels, MSB first, **1 = black**.

In compressed mode each block of up to 4096 raw bytes is compressed by a
native vendor library and sent as `header + 3-byte length + data`. The app
never uses compression for the D80, and neither does this driver.

## Printer → host

Replies are framed `1C <type> <payload…> 0D` (leading `1A`, `1C` or `0D`
bytes may be skipped).

| Type | Payload                      | Meaning                                    |
|------|------------------------------|--------------------------------------------|
| `02` | `B9 nn`                      | Paper type error, `nn` = paper type        |
| `03` | `A8` / `A9`                  | Temperature normal / overheated            |
| `04` | `nn`                         | Battery %, or `A1`/`A2`/`A3` = 10/5/3 % low |
| `05` | `98` / `99`                  | Cover closed / open                        |
| `06` | `89` / `88`                  | Paper loaded / out of paper                |
| `07` | `a b c`                      | Firmware version a.b.c                     |
| `08` | 15 ASCII bytes               | Serial number                              |
| `09` | `nn`                         | Auto power-off minutes (`00` = never)      |
| `0A` | `55` / other                 | Firmware upgrade succeeded / failed        |
| `0B` | `B8`                         | Print cancelled                            |
| `0F` | `0C` / other                 | Print complete: success / failure          |
| `1B` | —                            | Paper-out calibration finished             |
| `38` | —                            | Idle (not busy)                            |

Example session with a D80 (firmware 1.0.1):

```
> 1F 11 05 08         < 1C 04 3C 0D        battery 60 %
> 1F 11 05 11         < 1C 06 89 0D        paper loaded
> 1F 11 05 35 00                           uncompressed mode (no reply)
> 1D 76 30 00 D0 00 40 01 <66560 bytes>    1664 × 320 image
                      < 1C 0F 0C 0D        print complete, success
```
