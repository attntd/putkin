# Odbiór etapu 11 — tapeta Quickshell i Night Light

2026-09-16. Quickshell 0.3.1, Qt 6.11.2, Hyprland 0.56.2,
hyprsunset 0.4.0-3, Hyprutils 0.14.2, systemd 261.3.
Status: **gotowy do odbioru środowiskowego**.

## Wynik

Tapeta jest opcjonalną warstwą Quickshella. Nie wymaga hyprpaper.
Brak czystego obrazu użytkownika oznacza neutralne Mocha, bez używania
referencyjnych screenshotów jako tapety. Night Light w Quick Settings
steruje istniejącą usługą użytkownika; przełącznik i temperatura mają
odczyt potwierdzający, a niedostępność opis i Odśwież.
[Kontrakt i uruchomienie/rollback](../desktop.md).

## Sprawdzenia

| Polecenie | Wynik |
| --- | --- |
| `scripts/check` | PASS, 133 pliki QML, 0 błędów; [log](11-check.log) |
| `scripts/test` | PASS, kod 0: 14 Python, 222 QtTest (62,887 s), wszystkie integracje etapów 01–11; [log](11-tests.log) |
| QtTest etapu 11 | PASS, 18 wyników: 16 przypadków + init/cleanup; [log](11-qt.log) |
| `scripts/test-desktop-integration --output docs/evidence/11-desktop.json` | PASS, 10 grup integracji, 20 cykli; [JSON](11-desktop.json), [log](11-desktop.log) |
| `scripts/test-desktop-integration --idle --output docs/evidence/11-desktop-idle.json` | PASS, ponowna integracja, 20 cykli i pomiar 60 s; [JSON](11-desktop-idle.json), [log](11-desktop-idle.log) |
| `systemd-analyze --user --man=no --generators=no verify …` | PASS, kod 0 dla prywatnej kopii zainstalowanej jednostki i drop-in; bez uruchamiania usługi; [log](11-systemd.log) |
| Python AST i lokalne linki | Sprawdzone dla dodanych/zmienionych skryptów i dokumentów |

Integracja obejmuje stan już aktywny bez zapisu, on/off i temperaturę,
fragmentację odpowiedzi, odmowę, niepotwierdzony/spóźniony zapis, timeout,
błędny odczyt, brak/powrót usługi, zmianę PID i odrzucenie starego zamiaru.
Kod produkcyjny odrzuca atrapę przed jakimkolwiek IPC; jawna podklasa
testowa zastępuje tylko kontrolę właściciela. Badamy rzeczywisty transport
i QML Process. Reload zachowuje zewnętrzny proces, a timeout/reload
kończy własnego pomocnika i jego dziecko.

Lokalny Hyprland wczytał Lua i potwierdził wartości przez `hl.get_config`;
kontrola po usunięciu fragmentu przywróciła wcześniejszą ramkę.
Rzeczywisty hyprsunset przeczytał przykład z prywatnego XDG i wykrył
celowo niedomkniętą kategorię w próbie ujemnej. Oba procesy zakończyły
się kodem 1 przy braku Waylanda, zgodnie z izolacją. To test parsera,
nie działającego CTM. Pełne wyjścia znajdują się w `configs` w JSON.

Po 20 cyklach Quick Settings: 20 widoków utworzonych i 20 zniszczonych,
brak aktywnego panelu i pomocnika. RSS: 125 804 → 125 444 KiB;
minimum 125 420, maksimum 126 188 KiB. To krótka obserwacja procesu
offscreen, bez twierdzenia o braku wycieków w wielogodzinnej sesji.

Osobny pomiar po serii 20 cykli, 1920×1080, 30 workspace, zegar minutowy,
zamknięty panel, neutralna tapeta: **60,000962 s**, przyrost **1 tick CPU**,
RSS **122 260 → 119 276 KiB** (zarazem maksimum/minimum), brak dzieci shella
w końcowej próbce. Liczba wywołań IPC do backendu nie wzrosła w czasie
pomiaru. Backend był prywatną atrapą; nie jest to pomiar natywnego
layer-shell ani działającego hyprsunset. Wszystkie próbki i PID są w JSON.
W początkowej części pomiaru kończył się również osobny pełny QtTest
na własnym D-Bus; CPU/RSS powyżej dotyczą wyłącznie wskazanego procesu shella.

Pełny QtTest ma także osobny [zapis 222 PASS](11-all-qt.log), 62,943 s.
Uruchomiono go, gdy wyjście QtTest nie było jeszcze widoczne w buforowanym
logu pełnej regresji; końcowo oba przebiegi potwierdziły ten sam wynik.

## Podglądy

Wszystkie obejrzane obrazy pochodzą z offscreen/software z prywatnymi
XDG i D-Bus. Dane są atrapami, a tło jednolitym Mocha.

```sh
scripts/preview --desktop --size 1920x1080 --screenshot docs/evidence/11-night-light.png
scripts/preview --desktop --scenario nightLightAbsent --size 1366x768 --scale 1.25 --screenshot docs/evidence/11-night-light-absent.png
scripts/preview --desktop --scenario nightLightOff --size 1366x768 --scale 1.5 --screenshot docs/evidence/11-night-light-off.png
scripts/preview --desktop --scenario nightLightDenied --size 320x220 --scale 2 --screenshot docs/evidence/11-night-light-small.png
```

- [Włączone, 1920×1080](11-night-light.png), [log](11-night-light.log).
- [Backend niedostępny, skala 1,25](11-night-light-absent.png), [log](11-night-light-absent.log).
- [Wyłączone, skala 1,5](11-night-light-off.png), [log](11-night-light-off.log).
- [Odmowa, mały panel, skala 2](11-night-light-small.png), [log](11-night-light-small.log).

QtTest potwierdził również prawdziwe ładowanie lokalnego SVG i zwolnienie
obrazu, brak pobierania sieciowego, fallback po błędzie oraz przechodzenie
kliknięć przez nieinteraktywny widok. To nie jest dowód natywnej maski
wejścia `PanelWindow` ani renderowania tła na fizycznych monitorach.

## Historia korekt i ograniczenia

Pierwsza bramka znalazła niezgodność QVariantMap/QVariantHash dla
`Process.environment`; zastosowano istniejący wzorzec właściwości `var`.
Pierwszy QtTest miał 17 PASS / 1 FAIL, ponieważ oczekiwane ostrzeżenie
brakującego obrazu nazywa typ `QQuickImage`, a nie `Image`;
[zapis początkowy](11-qt-initial.log). Poprawiono wyłącznie dokładny
wzorzec tego celowego błędu obrazu, bez wyciszania importów i innych ostrzeżeń.

Natywne sprawdzenie ujawniło błąd `--config` w hyprsunset 0.4.0;
przykład korzysta z XDG. Próba ujemna parsera używa niedomkniętej sekcji,
ponieważ nieznana opcja nie została zgłoszona jako błąd przez lokalny parser.
Pierwszy test jednostkowy socketu i start prywatnego D-Bus w sandboxie
były blokowane. Testy wymagające socketów i sprawdzenie systemd wykonano
po ich dopuszczeniu, zachowując prywatne środowisko.

Nie aktywowano tapety, fragmentu Hyprlanda, drop-in ani backendu Night Light
na pulpicie. Nie potwierdzono CTM/gamma rzeczywistego monitora, prawdziwego
właściciela `hyprsunset.service`, natywnego layer-shell, hotplug,
mieszanych skal ani fokusu obcej aplikacji. Czystej tapety nie dostarczono,
więc pełne porównanie pulpitu z referencją pozostaje niewykonane.
Kitty, Fish, Neovim i Hyprlock mają osobne konfiguracje; akcenty Putkin
nie synchronizują ich automatycznie. Nie rozpoczęto etapów 12–13.
