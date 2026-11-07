# WiFi BIOS 2.1 - MB03+ / eLeMeNt ZX

This release fixes the original 2.0 driver without changing the public entry-table layout. The original 2.0 files remain in the historical archive.

## Size

| Part | 2.0 | 2.1 | Change |
|---|---:|---:|---:|
| Distributed binary | 544 B | 566 B | +22 B |
| Resident part, bios_len | 469 B | 489 B | +20 B |
| Installation/relocation | 75 B | 77 B | +2 B |

Changes: baud-table sentinel check +2 B; empty-block handling +8 B; TX status carry +2 B; preserving A costs no extra bytes; MB power-port protection on eLeMeNt, including relocation, +14 B; removing two intermediate jumps saves 4 B.

## Interface and fixes

- Version in BC is 0201. Public entries +00 through +22 retain their layout.
- An invalid hardware baud code returns CY=1, A=FF, and BC:E=0. FF is a table sentinel, not baud index 24.
- send_byte status queries return carry according to TX availability. A is preserved after successful transmission, a busy transmitter, and a status-only query.
- BC=0 means an empty block, not 65536 bytes. Both block services immediately return CY=1 without transferring data, changing HL/DE, accessing UART ports, or changing alternate DE.
- On eLeMeNt, wifi_on/off do not access MB power-control ports. wifi_on returns NZ because the module remains powered; wifi_off returns Z because power-off is unsupported.
- On MB, power operations change bit 0 only. Successful power-off returns NZ even when the written control byte becomes zero.
- Register, Z/NZ, and send_block counter contracts are documented in the source header.
- Call the installation entry before using other services.

## Verification and integration

SjASMPlus 1.20.3 builds the driver without errors or warnings. The test script executes 129 scenarios on assembled Z80 code with simulated ports: relocation at 4000/6000/C000/FD00, repeated installation, all 24 baud indices and readback, invalid rates, byte RX/TX, optimized 256-byte reception, timeouts, empty blocks, registers, and power handling.

These tests do not replace real-hardware testing.

Build: assembly.bat.
Test: powershell -NoProfile -ExecutionPolicy Bypass -File test_bios21.ps1.

The 566-byte driver is integrated into WiFi Setup 1.8 and the separate work-in-progress Sara 128 project. Building this driver does not automatically update those applications.