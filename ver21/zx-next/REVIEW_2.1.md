# WiFi BIOS 2.1 - ZX Spectrum Next

Review and fixes, November 5, 2026. The baseline was the original 1.9 source. Its supplied binary was named WifiBios10_NX.cod despite matching version 1.9. Historical sources are preserved separately.

## Confirmed issues in the original driver

1. Baud-information queries also wrote UART hardware. The input carry flag was saved in D, then overwritten while calculating the table address; the final OUT was unconditional.
2. Reset accessed port 0002 instead of NextReg 02. Next registers require the proper selector/data interface. Readback bits 0/1 describe previous resets and must not be blindly written back as reset requests.
3. ESP UART selection was missing. Ports 133B/143B could therefore address Pi after another program selected it. Stale upper bits of the 17-bit prescaler were not cleared either.
4. The identification-text address was missing from the relocation table, leaving HL at the original virtual address.
5. TX status did not return the proper carry state. AND 2 always cleared carry even with a full FIFO. The DB 11 skip trick also changed E and therefore the returned A; DB 01 preserves the transmitted byte.
6. Empty blocks were not handled. RX could wrap BC from zero to FFFF; TX could send up to 65535 unintended bytes.
7. Error results were incomplete. get_baud_rate did not return the promised BC:E=0 and A=FF, and core-version information left DE undefined.

## Hardware details

Next TX status bit 1 means FIFO full, not a byte currently being transmitted. It is suitable for deciding whether another byte may be queued.

Status bit 2 reports RX overflow and is cleared by a status read. Bit 3 means RX almost full, unlike the MB indication for at least 256 bytes. The original batch loop was not proven to corrupt data on current Next hardware. It was removed to save space; the replacement checks every received byte. Peak throughput may be lower and needs hardware verification.

The table of 15 rates for eight video timings already had correctly rounded prescalers and is preserved. Indexing was simplified and timing is masked to 0..7. Nominal 2 Mbaud does not guarantee reliable operation with every CPU setting and ESP module.

## Version 2.1 behavior

- Public entries +00 through +22 retain their layout; BC version is 0201.
- Initial installation selects ESP and sets 8N1 without flow control, break, or a held UART reset. Repeated identification queries do not reconfigure UART.
- Baud writes explicitly select ESP and clear upper prescaler bits. Information-only calls do not write UART hardware.
- Reset writes NextReg 02=80, holds the signal for approximately 53248 T-states, then writes 00. The pulse exceeds 1 ms even at 33 MHz. Wait for ESP startup afterward. This signal also resets expansion-bus devices.
- Empty RX/TX blocks immediately report success without port access.
- get_baud_rate remains unsupported and now returns its documented error result.
- wifi_on reports NZ; wifi_off does nothing because this interface has no independent ESP power control.
- DE is a polling-iteration budget, not milliseconds. RX with DE=0 expires immediately; TX with DE=0 permits 65535 attempts. The existing distinction is preserved.

While using this driver, other code must not switch the shared UART to Pi or change its frame format.

## Size and verification

| Part | Original 1.9 | Next 2.1 | Change |
|---|---:|---:|---:|
| Distributed BIOS | 707 B | 698 B | -9 B |
| Resident part | 636 B | 613 B | -23 B |
| Installation/relocation | 71 B | 85 B | +14 B |

The baseline rebuilt with SjASMPlus 1.20.3 matches the supplied binary:
F9DD8C2B7C2D72E80F2F65E9224C9547E9075F6E6B0D6A13465F655E6E434B9C.

Version 2.1 builds without errors or warnings. test_bios21_next.ps1 executes 278 scenarios with simulated ports: relocation, repeated installation, identification, all 15 rates across eight timings in query/set modes, invalid indices, reset writes and delay, byte operations, blocks up to 1537 bytes, empty blocks, and timeouts. This is not FPGA simulation or exhaustive physical testing.

Build: assembly.bat.
Test: powershell -NoProfile -ExecutionPolicy Bypass -File test_bios21_next.ps1.

## Hardware references

- https://wiki.specnext.dev/UART_TX
- https://wiki.specnext.dev/UART_RX
- https://wiki.specnext.dev/UART_Control
- https://wiki.specnext.dev/UART_Frame
- https://wiki.specnext.dev/Reset_Register
- https://wiki.specnext.dev/Video_Timing_Register