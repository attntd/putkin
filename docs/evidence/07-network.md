# Etap 07 — sieć i Wi-Fi

Renderer offscreen/software, prywatne XDG i D-Bus. Podglądy używają
wyłącznie atrap. Obrazy otwarto i oceniono: Mocha, ostre rogi, wspólne
tokeny, widoczny fokus, literalny tekst SSID i przewijanie małego panelu.

| Obraz | Scenariusz |
| --- | --- |
| [1920×1080, skala 1](07-network-1920.png) | Rozwinięta lista z sygnałem/zabezpieczeniem, wspólny status paska, audio i jasność |
| [1366×768, skala 1](07-network-password.png) | Formularz PSK, nazwa zawierająca `<b>` pozostaje tekstem, brak jawnego hasła |
| [1366×768, skala 1,25](07-network-portal.png) | Ethernet i Wi-Fi równocześnie, osobny komunikat portalu |
| [320×220, skala 2](07-network-small.png) | Przewinięcie do pola hasła, widoczny cały fokus i dolna krawędź kontrolki |
| [1366×768, skala 1,5](07-network-blocked.png) | Blokada sprzętowa i brak listy sieci |
| [1366×768, skala 1](07-network-unavailable.png) | Brak NetworkManagera, niedostępne akcje radia |
| [1366×768, skala 1](07-network-empty.png) | Pusta lista bez fikcyjnych sieci |

Polecenia: `scripts/preview --network --scenario <scenariusz> --size <rozmiar>
--scale <skala> --screenshot docs/evidence/<plik>.png`. Scenariusze w kolejności
tabeli: `basic`, `networkPassword`, `networkPortal`, `networkPassword`,
`networkBlocked`, `networkUnavailable`, `networkEmpty`. Każdemu PNG odpowiada
plik `.log`. Skala dotyczy Qt; rozmiar zapisanego obrazu jest odpowiednio większy.

[Bramka](07-check.log), [pełna regresja](07-tests.log),
[końcowy QtTest sieci](07-qt.log),
[pierwszy limit czasu całego zestawu Qt](07-tests-initial.log),
[test natywnego adaptera i pomiar](07-network.json), [log integracji](07-network.log).

Wynik końcowy: 93 pliki QML bez błędów, 159 wyników QtTest i wszystkie
integracje PASS; po korekcie rfkill/dostępności także 27 wyników Qt sieci PASS.
Integracja natywna potwierdziła 9 grup scenariuszy i 20 cykli panelu.
RSS podczas cykli: 128 432 → 128 728 KiB (zakres 128 236–128 984 KiB).

Przy zamkniętym panelu przez 60,001370 s: 0 nowych odczytów i skanów,
0 dodatkowych ticków CPU shella i obserwatora. RSS shella wzrosło
z 108 996 do 109 132 KiB, `gdbus` utrzymał 5 904 KiB. Drzewo zawierało
shell i jednego obserwatora; wszystkie 14 PID-ów z całego testu zwolniono.
Pomiar używa natywnego adaptera sieci, atrap pozostałych usług oraz
renderera offscreen; nie należy porównywać RSS wprost z innymi entrypointami.

Szczegółowe wyniki i otwarte kryteria znajdują się w [statusie](../status.md).
Atrapa protokołu sprawdza prawdziwe Quickshell.Networking i jawne wywołania
D-Bus; nie jest testem kart radiowych, prawdziwego NetworkManagera,
uwierzytelnienia z AP ani portalu HTTP. Offscreen nie potwierdza Waylanda,
HyprlandFocusGrab i mieszanych skal fizycznych monitorów.
