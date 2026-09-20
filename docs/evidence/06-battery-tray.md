# Etap 06 — dowody baterii i traya

Data: 2026-09-16. Quickshell 0.3.1, Qt 6.11.2, offscreen/software.

| Sprawdzenie | Wynik |
| --- | --- |
| [Bramka QML](06-check.log) | PASS, 84 pliki; błędy importów/typów nie są wyciszane |
| [Pełny zestaw](06-tests.log) | PASS, 6 testów Python, 132 wyniki QtTest oraz wszystkie integracje etapów 01–06 |
| [Natywny D-Bus, cykle i pomiar](06-status.json) | UPower, SystemTray/SNI, DBusMenu, procesy gdbus/busctl i LazyLoader; [log](06-status.log) |
| [Końcowa regresja paneli i traya](06-final-qt.log) | 33 PASS po korekcie kotwiczenia przy powiększaniu monitora; [IPC/LazyLoader i 20 cykli](06-panels-regression.json) PASS |
| QtTest etapu 06 | 21 wyników; stany baterii, klawiatura/mysz, tooltip, overflow, podmenu, fokus, usuwanie i mały ekran |
| Zasoby menu | 20 cykli, 20 opened/closed korzenia i podmenu, zwolnione powierzchnie |
| [Pierwsza pełna regresja](06-tests-initial.log) | 129 PASS / 3 FAIL; poprawiono opóźniony fokus/czas życia oraz oczekiwanie na zakończenie wejścia w pasek |

Natywna atrapa eksportuje baterię systemową, mysz z baterią 3% oraz
16 klientów SNI na osobnych połączeniach D-Bus. Odbiór sprawdza prawdziwe
wywołania Activate/SecondaryActivate, AboutToShow/GetLayout i zdarzenia
menu. Zanik klienta to rozłączenie D-Bus. Powrót UPower i jego start po
shellu przechodzą przez produkcyjne gdbus/busctl. Testy używają prywatnego
socketa dla obu magistral i prywatnych XDG; nie korzystają ze sprzętu.

Pomiar 60,002846 s: RSS shella 105 148 → 105 276 KiB, 0 nowych ticków
CPU i odczytów baterii. Obserwator gdbus: 6008 KiB, 0 nowych ticków.
Świeży proces, 1920×1080, skala 1, 30 workspace, zegar minutowy,
13 zarejestrowanych klientów traya, panel zamknięty, audio/jasność wyłączone.
W cyklach menu RSS 127 940 → 127 668 KiB, zakres 127 412–128 152 KiB.
Dziesięć zapisanych PID-ów nie istnieje po sprzątnięciu. To ograniczony
pomiar offscreen, nie deklaracja braku wszystkich wycieków.

Sześć poniższych zrzutów otwarto i oceniono. Wymiary podano w logicznych
pikselach; PNG przy skalowaniu ma odpowiednio większy rozmiar fizyczny.

| Widok | Rozmiar / skala | Dowód |
| --- | --- | --- |
| Pasek i Quick Settings, bateria 72% | 1920×1080 / 1 | [PNG](06-status-1920.png), [log](06-status-1920.log) |
| Ostrzeżenie 12%, akcent Teal | 1366×768 / 1 | [PNG](06-battery-low.png), [log](06-battery-low.log) |
| Menu, pozycja wyłączona, separator, podmenu i checkbox | 1366×768 / 1.25 | [PNG](06-tray-menu.png), [log](06-tray-menu.log) |
| Overflow i fokus na małym ekranie | 320×220 / 2 | [PNG](06-tray-small.png), [log](06-tray-small.log) |
| Brak baterii, bez jej przycisku w pasku | 1366×768 / 1 | [PNG](06-battery-absent.png), [log](06-battery-absent.log) |
| Ładowanie i czas do pełna | 1366×768 / 1.5 | [PNG](06-battery-charging.png), [log](06-battery-charging.log) |

Bateria ma informację o stanie/czasie, a żółte ostrzeżenie pozostaje
czytelne przy turkusowym akcencie. Na małym ekranie tray zwija się do `⋯`,
pozostawiając workspace, zegar, baterię i Quick Settings. Menu ma obrys
fokusu i mieści się na ekranie; overflow przewija się do wybranej pozycji.

To dowody Item/offscreen i protokołu. Rzeczywisty Wayland/layer-shell,
HyprlandFocusGrab, zewnętrzne tooltipy, oddanie fokusu aplikacji, fizyczna
bateria, monitory/hotplug i mieszane skale pozostają niezweryfikowane.
W środowisku nadal brak `/dev/dri` i Weston/Sway/Cage. Nie uruchomiono
produkcyjnego shella na aktywnym pulpicie. [Pełny status](../status.md).
