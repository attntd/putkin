# Etap 05 — dowody odbioru

2026-09-16, Quickshell 0.3.1 / Qt 6.11.2 / brightnessctl 0.5.1-3.
Podgląd offscreen/software, skala 1, własne XDG i D-Bus. Monitory, audio
i podświetlenie są atrapami. Nie uruchamiano drugiego pełnego shella
na aktywnym pulpicie i nie regulowano fizycznego podświetlenia.

## Widok

Wszystkie pięć obrazów otwarto i oceniono:

| Zrzut | Ocena |
| --- | --- |
| [Quick Settings 1920×1080](05-brightness-1920.png) | Jasność 60% pod audio; niebieski drugi akcent, ostre rogi, szczegóły i poprawna szerokość panelu. |
| [OSD 1366×768](05-osd-1366.png) | Ikona słońca, etykieta „Jasność · 65%”, niestandardowy drugi akcent Teal, dotychczasowa geometria OSD. |
| [Mały panel 320×220](05-brightness-small.png) | Widok przewinięty do jasności; cały skupiony suwak i obrys widoczne. Audio pozostaje osiągalne przewijaniem/klawiaturą. |
| [Brak backlight](05-brightness-unavailable.png) | Bez fikcyjnego procentu i suwaka; pozostaje wejście do diagnostyki. |
| [Odmowa zapisu](05-brightness-denied.png) | Po błędzie uprawnień nadal 60%, widoczny komunikat i suwak na odczytanej wartości. |

Logi renderu znajdują się obok PNG. Jedyna diagnostyka to znana maska
okna na offscreen; nie wyciszano błędów importów.

## Zachowanie

- [Bramka](05-check.log): 68 plików QML, 0 błędów.
- [Pełne testy](05-tests.log): 6 regresji Python, 111 wyników QtTest,
  integracje Hyprland (Hyprlang/Lua), panele, FileView, audio i jasność PASS.
- [Końcowa integracja audio](05-audio-regression.json): prywatny PipeWire,
  rzeczywisty tracker/IPC i 20 cykli wspólnego loadera po doprecyzowaniu
  oczekiwania na `Component.onDestruction`.
- [Integracja jasności i pomiar](05-brightness.json), [log](05-brightness.log):
  prawdziwy Process/IPC/LazyLoader z atrapą executable, zapis/odczyt,
  błędy, timeout z SIGKILL, brak programu, reload, 20 cykli i 60 s spoczynku.

Pierwszy pełny przebieg miał 111 zielonych wyników Qt, lecz
[test audio przegapił krótką widoczność OSD](05-tests-initial.log).
Timeout testowych cykli zwiększono ze 100 do 400 ms; produkcja nadal 1500 ms.
Osobny przebieg wykrył odstęp między wyłączeniem loadera a destrukcją
obiektu (12 utworzonych / 11 zniszczonych w tej samej próbce). Test czeka
teraz na rzeczywiste zrównanie liczników przed następnym cyklem.
Nie usunięto żadnego kryterium zasobów ani nie wyciszono diagnostyk.

## Pomiar i zasoby

Końcowa integracja: **20 utworzonych / 20 zniszczonych OSD**, 0 żywych
widoków, brak dziecka adaptera. RSS w cyklach: 132 784 → 127 552 KiB,
minimum 122 944 KiB, ostatnie sześć próbek 127 552 KiB. Wystąpiły spadki
i ponowny skok; nie opisujemy tego jako stałej pamięci ani pełnego dowodu
braku wycieków.

Świeży proces po 2 s rozgrzewki, 60,000102 s bez interakcji, 1920×1080,
30 workspace, zegar minutowy, zamknięty panel i OSD:

| Miara | Wynik |
| --- | --- |
| Komendy brightnessctl podczas pomiaru | **0** |
| Ticki CPU shella | **0 przyrostu**, rozdzielczość licznika 10 ms |
| RSS | **96 532 → 97 684 KiB**, minimum/maksimum jak wartości skrajne |
| Procesy środowiska | **3**: dbus-run-session, dbus-daemon, quickshell |
| Dzieci shella | **0** |

Raport [JSON](05-brightness.json) zawiera wszystkie próbki i PID-y.
Po zakończeniu procesy shella, D-Bus i atrap nie istnieją. Audio i monitory
są atrapami, dlatego RSS nie jest bezpośrednio porównywalny z pomiarem 04
z natywnym PipeWire. Podczas minuty RSS wzrósł o 1152 KiB.

## Granice

Podgląd nie potwierdza layer-shell, kliknięć przez OSD, przekazania
fokusu innej aplikacji, fizycznych monitorów, skal ani pracy sterownika
backlight/logind. Brak `/dev/dri` i Westona/Sway/Cage nadal uniemożliwia
prywatny odbiór Waylanda w tym środowisku. Sprzętowa jasność i poprawność
heurystyki przy kilku podświetleniach pozostają do sprawdzenia.
Nie deklarujemy live dla zewnętrznych zmian. Szczegóły:
[kontrakt](../brightness.md), [status](../status.md).
