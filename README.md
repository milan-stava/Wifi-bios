# WiFi BIOS for eLeMeNtZX and MB03+

Current release: **2.1**, with separate `ver21/el-mb` and `ver21/zx-next` variants.

## What's New in 2.1

### EL/MB - fixes since 2.0

This is a maintenance release: it fixes driver edge cases rather than adding new WiFi commands or menu options.

- **Reading the current speed:** `get_baud_rate` no longer mistakes the end-of-table marker `FF` for a valid speed index 24.
- **Checking whether data can be sent:** `send_byte` now reports the transmitter status correctly through the carry flag and preserves register A.
- **Sending or receiving an empty block:** `rece_block` / `send_block` treat `BC=0` as zero bytes. They return success (`CY=1`) without accessing the UART, instead of starting an unintended transfer.
- **WiFi power control on eLeMeNt:** `wifi_on/off` no longer access MB-only power ports when running on eLeMeNt. Its module stays on: `wifi_on` returns NZ and `wifi_off` returns Z because power-off is unavailable.
- **Clearer programming documentation:** corrected the descriptions of Z/NZ results, registers, and the actual `send_block` timeout.
- **Existing interface retained:** entry points `+00..+22` are unchanged. Applications must still call the installation routine before using the BIOS.
- **Small code savings:** replaced two unnecessary intermediate jumps with direct relative jumps.

The complete EL/MB binary is **566 bytes**, only **22 bytes larger** than version 2.0. This driver is for MB03+/eLeMeNt; the separate ZX Next driver is described below.

### ZX Next- initial release

- Corrected baud-information queries so they no longer change UART settings.
- Explicitly selected the ESP UART and cleared stale upper prescaler bits when setting a rate.
- Corrected ESP reset handling, identification-text relocation, transmit-status reporting, and error results.
- Added proper handling of empty data blocks while retaining the public entry-table layout.
- Supports **15 baud indices (0-14)** across eight video timings.
- Binary size: **698 bytes**, 9 bytes smaller than the original Next 1.9 driver.

Each variant includes Z80 assembly sources, build scripts, tests, and ready-to-use binaries in `runable/`. Build with `assembly.bat` using SjASMPlus 1.20.3.

The original 1.8, 1.9, and 2.0 directories are preserved as historical archives, including their original documentation and build files.

This is a Z80 UART driver, not ESP firmware.

## Downloads

Direct, version-specific links suitable for use on other websites:

| Platform / package | Download | Bytes |
|---|---|---:|
| EL/MB | [WifiBios21_MB_EL.bin](https://raw.githubusercontent.com/milan-stava/Wifi-bios/v2.1/ver21/el-mb/runable/WifiBios21_MB_EL.bin) | 566 |
| ZX Next | [WifiBios21_NX.bin](https://raw.githubusercontent.com/milan-stava/Wifi-bios/v2.1/ver21/zx-next/runable/WifiBios21_NX.bin) | 698 |

[Complete v2.1 package ZIP (sources and binaries)](https://github.com/milan-stava/Wifi-bios/archive/refs/tags/v2.1.zip).

The links target the existing release tag, so later development on main does not change these downloads.