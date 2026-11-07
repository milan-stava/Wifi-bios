# Wi-Fi BIOS 2.1 pro ZX Spectrum Next

Kontrola a opravy 5. 11. 2026. Výchozí zdroj je `../WifiBios19_NX.a80`,
verze uvnitř je 1.9. Nové soubory jsou oddělené ve složce `bios21`.
Původní soubory zůstaly nezměněné. WiFi Setup 1.8 se tímto ještě neportuje.

## Potvrzené chyby původního kódu

1. **Dotaz na rychlost mění UART.** `set_baud_rate` ukládá vstupní CY do D,
   ale vzápětí D přepíše při výpočtu adresy tabulky. Před OUT není žádná
   podmínka: také volání s CY=0 skutečně zapíše nový dělič.
2. **Reset používá port 0002 místo NextReg 02.** `LD BC,2 / IN / OUT` neosloví
   Next registr. Správná obsluha musí použít NextReg instrukci nebo porty
   243B/253B. Navíc nelze slepě zapsat přečtenou hodnotu NextReg 02 zpět:
   čtené bity 0/1 popisují minulý reset, zápis spouští reset počítače.
3. **Chybí výběr ESP UART.** Porty 133B/143B obsluhují vybraný UART.
   Při předchozím výběru Pi by BIOS komunikoval s Pi. Dále se nevymažou
   horní tři bity 17bitového děliče, pokud je předchozí program změnil.
4. **Adresa identifikačního textu není v relokační tabulce.** Vrácené HL
   ukazuje na původní virtuální adresu FFE6, nikoli na nahraný text.
5. **TX dotaz nevrací správně CY.** `AND 2` vždy CY vynuluje, i při plném
   vysílacím FIFO. Úspěšné odeslání navíc přes trik `DB 11` mění E a tím A
   na E6; nahrazení `DB 01` obnoví přeskočení bez změny vráceného bajtu.
6. **Nulová délka bloků není ošetřena.** RX může přejít z BC=0 na FFFF a
   zapisovat nepožadovaná data; TX může odeslat až 65535 bajtů.
7. **Neúplné chybové výstupy.** `get_baud_rate` pouze nastaví CY, ale nevrací
   slíbené BC:E=0 a A=FF. Informace o verzi core také nechá DE neurčené.

## Rozdíly hardwaru, které nejsou samy o sobě chybou přenosu

Next bit 1 statusu znamená plné TX FIFO, nikoli právě vysílaný bajt.
Pro rozhodnutí, zda lze vložit další bajt, je jeho použití správné.
Bit 2 značí zaznamenané přetečení RX a při čtení statusu se maže.
Bit 3 znamená RX téměř plné, nikoli údaj „alespoň 256 bajtů“ jako v MB.
Původní 256bajtová smyčka z toho přesto na současném Nextu nečte za konec
FIFO: téměř plné FIFO obsahuje alespoň 256 bajtů. Tato část tedy nebyla
prokázána jako příčina poškození dat. V 2.1 byla odstraněna pro úsporu místa;
příjem nyní ověřuje dostupnost každého bajtu. Špičková propustnost bude nižší
než u původní dávkové smyčky; rychlé přenosy je třeba ověřit na Nextu.

Samotná tabulka 15 rychlostí pro osm časování má správné zaokrouhlené děliče.
Zůstává zachovaná. Kód indexování se zjednodušil a časování maskuje na 0..7.
Nejde o záruku spolehlivosti 2 Mbaud na libovolné rychlosti CPU a ESP.

## Implementace 2.1

- Veřejné vstupy +00 až +22 a jejich rozestupy zůstaly zachované, BC verze=0201.
- První instalace vybere ESP a nastaví 8N1 bez flow control, breaku a UART resetu.
  Opakovaný dotaz na verzi už UART nemění. Jiný program nesmí během používání
  BIOSu přepínat sdílený UART na Pi nebo změnit rámec.
- Zápis rychlosti explicitně vybere ESP a vynuluje horní část děliče.
  Informační volání nepíše do UART; jen vybere NextReg 11 pro čtení časování.
- Reset zapíše pouze NextReg 02=80, podrží signál přibližně 53248 T,
  potom zapíše 00. I při 33MHz jde přes 1 ms. Po návratu je nutné vyčkat
  na start ESP. Tento signál současně resetuje zařízení na expansion busu.
- Příjem/odeslání prázdného bloku ihned vrací úspěch bez přístupu k portům.
- `get_baud_rate` nadále není implementováno; nyní vrací přesný chybový výsledek.
- `wifi_on` pouze hlásí NZ, `wifi_off` je prázdné. To odpovídá chybějícímu
  samostatnému vypínání napájení ESP tímto rozhraním.
- DE je rozpočet průchodů smyčkou, nikoli čas v ms. RX DE=0 ihned vyprší;
  TX DE=0 dává 65535 pokusů. Dosavadní rozdíl je zachovaný a zdokumentovaný.

## Velikost a ověření

| | Původní 1.9 | Next 2.1 | Rozdíl |
|---|---:|---:|---:|
| Celý distribuovaný BIOS | 707 B | 698 B | −9 B |
| Rezidentní část `bios_len` | 636 B | 613 B | −23 B |
| Instalační/relokační část | 71 B | 85 B | +14 B |

Výchozí zdroj sestavený SjASMPlus 1.20.3 je bajtově shodný s dodaným
`WifiBios10_NX.cod` (název binárky je zavádějící, obsah odpovídá zdroji 1.9).
SHA256: F9DD8C2B7C2D72E80F2F65E9224C9547E9075F6E6B0D6A13465F655E6E434B9C.

Sestavení 2.1: bez chyb a varování. `test_bios21_next.ps1` provádí skutečné
instrukce sestaveného BIOSu v jednoduchém CPU modelu se simulovanými porty.
278 scénářů: relokace na 4000/6000/C000/FD00, opakovaná instalace, identifikace,
15 rychlostí × 8 časování × dotaz/zápis, neplatné indexy, resetové zápisy a
čekací smyčka, jednotlivé bajty, bloky do 1537 B, nulové bloky a timeouty.
Nejde o FPGA simulaci ani zkoušku fyzického Nextu; ta zatím neproběhla.

Sestavení: `assembly.bat` (lokální cesta k SjASMPlus je uvedena uvnitř).
Test: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test_bios21_next.ps1`.

## Dokumentace hardwaru

- https://wiki.specnext.dev/UART_TX
- https://wiki.specnext.dev/UART_RX
- https://wiki.specnext.dev/UART_Control
- https://wiki.specnext.dev/UART_Frame
- https://wiki.specnext.dev/Reset_Register
- https://wiki.specnext.dev/Video_Timing_Register
