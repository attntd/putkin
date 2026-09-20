# Etap 02 — dowody odbioru

2026-09-16, Quickshell 0.3.1 / Qt 6.11.2. Izolowane XDG i D-Bus,
offscreen/software, bez usług hosta, sprzętu i PAM.

- `scripts/check`: **PASS**, 42 pliki QML.
- `scripts/test`: **PASS**, 6 regresji Python, 32 wyniki QtTest,
  natywny adapter Hyprlanda (Hyprlang/Lua), rzeczywiste IPC i LazyLoader.
- 20 cykli Qt oraz osobno 20 cykli rzeczywistego Quickshella: po zamknięciu
  brak żywego widoku; open/close/open nie niszczy ponownie otwartego panelu.
- QtTest potwierdza mysz, h/j/k/l, Enter i Enter numeryczny, pomijanie
  wyłączonych kontrolek, Tab/Shift+Tab, wpisywanie tekstu, Escape, zmianę
  strony/monitora, hotplug atrap oraz przewijanie do fokusu.

## Zrzuty

Zapisano przez `scripts/preview --panels --size … --scenario … --screenshot …`.
Obrazy obejrzano: panel przy prawym brzegu, kwadratowe rogi, aktywny przycisk,
widoczny obrys fokusu, prawdziwy opis palety. Mały ekran pokazuje dolną
część przewijalnej strony i skupiony przycisk „Wstecz”.

| Scenariusz | PNG | Log |
| --- | --- | --- |
| Quick Settings, 1920×1080 | [zrzut](02-quick-settings-1920.png) | [log](02-quick-settings-1920.log) |
| Ustawienia, 1366×768 | [zrzut](02-settings-1366.png) | [log](02-settings-1366.log) |
| Ustawienia, 320×220 | [zrzut](02-settings-small.png) | [log](02-settings-small.log) |

## Pomiary

`scripts/measure-idle --panels --output docs/evidence/02-idle-60s.json`:
60 s po rozgrzewce, 30 workspace, zegar minutowy i niezaładowany host paneli.
RSS **87 772 KiB** przez cały pomiar; CPU **0 zarejestrowanych ticków**;
3 procesy środowiska, 0 dzieci shella. [Raport](02-idle-60s.json),
[log](02-idle-60s.log). Rozdzielczość licznika CPU wynosi 10 ms.

Ostatni `scripts/test` wywołał `scripts/test-panels-integration`; jego
raport i log skopiowano z `artifacts/` do [raportu 20 cykli](02-panels-cycles.json)
i [logu](02-panels-cycles.log). RSS **95 376 → 99 472 KiB**, maksimum
**99 732 KiB**. Skok wystąpił w cyklu 2, a od cyklu 13 do 20 RSS pozostawał
stały. Po każdym zamknięciu liczniki utworzenia/zniszczenia były równe;
na końcu 0 żywych powierzchni i 0 dzieci shella. To nie jest pomiar natywnych
okien Waylanda ani dowód braku wszystkich rodzajów wycieku.

## Granica dowodu

QtTest używa prawdziwego koordynatora, hosta i widoków z jawnym adapterem
`QtQuick.Loader`. Test IPC uruchamia rzeczywisty `LazyLoader` Quickshella.
Oba używają atrapy monitorów i wejścia poza panelem. Odbiór natywnego
`PanelWindow`, graba, maski, tooltipów poza paskiem, powrotu do innej
aplikacji, fizycznego hotplug i skalowania pozostaje otwarty.
[Pełny status](../status.md), [reguły paneli](../panels.md).
