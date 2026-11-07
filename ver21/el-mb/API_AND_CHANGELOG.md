# WiFi BIOS 2.1 – MB03+ / eLeMeNt ZX

Opravená samostatná varianta původního BIOSu 2.0. Není to zatím port
pro ZX Next. Původní zdroje 2.0 a BIOS používaný setupem 1.8 nebyly změněny.

## Velikost

| Část | 2.0 | 2.1 | Rozdíl |
|---|---:|---:|---:|
| Celá distribuovaná binárka | 544 B | 566 B | +22 B |
| Trvalá část (bios_len) | 469 B | 489 B | +20 B |
| Instalační/relokační část | 75 B | 77 B | +2 B |

Rozpis změn: kontrola sentinelové rychlosti +2 B, oba prázdné bloky +8 B,
stavové carry vysílače +2 B, zachování A beze změny velikosti, ochrana
MB power portů při eLeMeNtu včetně relokace +14 B, odstranění dvou
skokových mezistupňů -4 B. Celkem +22 B.

## Opravy a smlouva rozhraní

- Verze vracená v BC je 0201; vstupní tabulka +00..+22 zůstává stejná.
- Neplatná načtená rychlost FF vrací chybu: CY=1, A=FF, BC=E=0.
- send_byte při dotazu NC vrací carry podle obsazení TX. A je zachováno
  jak při úspěšném odeslání, tak při obsazeném vysílači a stavovém dotazu.
- BC=0 znamená prázdný blok, ne 65536 B. Obě blokové služby ihned vracejí
  CY=1, bez přenosu, změny HL/DE, přístupu k UARTu nebo změny DE'.
- wifi_on/off na detekovaném eLeMeNtu nepřistupují k MB power portům.
  wifi_on vrací NZ (modul stále zapnutý); wifi_off Z (nelze vypnout).
- Zapnutí/vypnutí MB nadále mění jen bit 0. Úspěšné vypnutí vrací NZ
  i pokud celý zapsaný řídicí bajt je 0.
- Popis registrů, Z/NZ a skutečného čítače send_block je upřesněn také
  přímo ve zdroji WifiBios21_MB_EL.a80, včetně seznamu změn v hlavičce.
- Inicializační vstup se stále musí volat před ostatními službami.

## Ověření

SjASMPlus 1.20.3: bez chyb a varování. 129 scénářů sestaveného Z80 kódu
se simulovanými porty: relokace na 4000/6000/C000/FD00, opakovaná
inicializace, všech 24 rychlostí a readback, neplatné rychlosti, byte RX/TX,
256B optimalizace příjmu, timeouty, prázdné bloky, registry a napájení
pro MB i eLeMeNt. Ověřeno, že původní 2.0 se nezměnil.
Testy nenahrazují ověření na skutečném MB03+/eLeMeNt hardwaru.

Sestavení:

    assembly.bat

Testy:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test_bios21.ps1

Výstup WifiBios21_MB_EL.cod se zatím automaticky nekopíruje do setupu.
Pro Next bude použit opravený základ, ale jeho UART backend vyžaduje
samostatnou úpravu podle Next hardwaru.
## Integrace 2026-11-05
Binárka 2.1 byla na výslovnou žádost uživatele vložena do WiFi Setupu 1.8 i Sáry 128. Původní 2.0 zůstává zachovaná. Sestavení samotného BIOSu stále automaticky nepřepisuje kopie v aplikacích.
