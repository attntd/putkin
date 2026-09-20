# Putkin

**Uruchamianie:** `qs` — domyślna konfiguracja Putkin, przez UWSM.
Aktualizacja: `scripts/install --activate`; powrót:
`scripts/install --restore --activate`. Instalacja zachowuje pięć buildów
i stałą ścieżkę autostartu. [Szczegóły instalacji](docs/install.md).

Minimalistyczny shell w **Quickshell/QML dla Hyprlanda**, budowany według czterech obrazów w katalogu głównym: ciemny Catppuccin Mocha, pastelowe akcenty, ostre narożniki i prosty górny pasek.

**Launcher:** `Super+Spacja`, wyszukiwanie aplikacji, plików i schowka.
`Super+V` otwiera Schowek; `Super+:` (Super+Shift+średnik) otwiera komendy.
Prefiksy `:a `, `:f `, `:c ` zmieniają się w filtr; puste pole pokazuje
ostatnie użycia. Enter uruchamia/kopiuje, Escape przechodzi do nawigacji
`j/k`, kolejny zamyka. [Obsługa i historia](docs/launcher.md).

Ikona głośnika otwiera osobny panel z głośnością wyjścia i mikrofonu,
wyciszaniem oraz wyborem urządzeń. [Audio](docs/audio.md).

**Aktualna wersja i wyniki: [status](docs/status.md).** Bieżące zmiany wyglądu
i launcher mają osobne wyniki w [statusie](docs/status.md). Etap 12 odebrano
16 września dla wcześniejszej wersji `20260916-5132708bd8f7`;
[zakres tamtych dowodów](docs/validation.md#zamknięcie-kryteriów).
Pasek 32 px na monitor,
workspace, zegar oraz Quick Settings. Strona Wygląd pozwala zmieniać dwa
akcenty, wybierać presety i ograniczać ruch, z podglądem, anulowaniem oraz
trwałym zapisem. Jeden panel na cały shell, nawigacja h/j/k/l + Enter,
przewijanie i sterowanie przez IPC. Audio ma wspólny stan paska, suwaka,
mute, listy wyjść i OSD. Testy Qt, FileView, adapterów i paneli przechodzą,
w tym restart prywatnego PipeWire z wirtualnymi wyjściami. Jasność ma suwak
1–100%, IPC i ten sam OSD; zapis przez brightnessctl wymaga odczytu
potwierdzającego, a brak urządzenia pozostawia diagnostykę. Bateria pokazuje
procent, ładowanie i czas UPower. Tray ma aktywację, menu z podmenu,
obsługę klawiatury i przewijany overflow. Sieć udostępnia wspólny status,
radio Wi-Fi, listę sieci i formularz PSK. VPN/enterprise kieruje do opcjonalnego
edytora; połączenie z AP i dostęp do internetu mają osobne stany.
Bluetooth obsługuje radio, wybór adaptera i sparowane urządzenia;
parowanie otwiera opcjonalny Blueman. Lista nie skanuje otoczenia.
Powiadomienia mają pojedynczy serwer, toasty, akcje, timeouty i DND,
bez historii; nazwa D-Bus jest sprawdzana przed startem serwera.
Menu sesji ma osobne potwierdzenia działań kończących pracę. Blokada hasłem
lub odciskiem i obsługa bezczynności działają w tej samej instancji Quickshell
co pasek. Uśpienie wymaga potwierdzenia blokady przez kompozytor.
[Kontrakt i granice odbioru nowej blokady](docs/session.md).
Opcjonalna tapeta jest renderowana przez Quickshell, bez hyprpaper:
lokalny obraz albo jednolite Mocha. Światło nocne w Quick Settings
steruje istniejącą usługą użytkownika hyprsunset 0.4.0, z potwierdzeniem
stanu i temperaturą. Dołączono osobny fragment wyglądu Hyprlanda w Lua
oraz instrukcje włączenia i wycofania. [Kontrakt pulpitu](docs/desktop.md).
Natywne okna, fokus i grab, skale oraz hotplug sprawdzono w prywatnym
Hyprlandzie, z atrapami sprzętu i sesji. Naprawiono zamykanie panelu
kliknięciem poza nim i fokus aktywnych powiadomień. Użytkownik potwierdził
działanie regulacji jasności/audio, Wi-Fi, Bluetooth, baterii i monitorów
na sprzęcie oraz działanie poprzedniej blokady Hyprlock, uśpienia i wybudzenia.
Ten odbiór nie obejmuje nowego uwierzytelniania Quickshell.
Potwierdził też wizualne włączenie i wyłączenie Night Light.
Końcowa regresja: 137 QML bez błędów, 17 testów Python, 235 wyników QtTest
i wszystkie 12 integracji PASS. Natywny odbiór obejmuje 18 zrzutów,
60 s spoczynku i 20 cykli paneli; dodatkowo wykonano 60 cykli offscreen.
Wyniki testów, renderów, pomiarów i granice potwierdzonego zakresu:
[odbiór etapu 12](docs/validation.md). Na polecenie użytkownika przełączono
lokalną sesję i autostart na Putkin; [wynik i powrót](docs/install.md).
Instalator użytkownika obsługuje staging, dry-run, prywatny cel, powrót
i retencję pięciu buildów. Konfigurację pierwszego autostartu opisuje
[instrukcja instalacji](docs/install.md).

## Dokumenty

- [Roadmapa i gotowe prompty](ROADMAP.md) — kolejność pracy, zależności i kryteria ukończenia.
- [Audyt poprzedniego shella](docs/audit.md) — ocena `../putpuccin`, dowody, wyniki testów i decyzje o ponownym użyciu kodu.
- [Wygląd i zakres](docs/design.md) — interpretacja referencji, paleta i ustawienia akcentów.
- [Architektura](docs/architecture.md) — granice modułów, konfiguracja, integracje i testowanie.
- [Status etapów](docs/status.md) — miejsce na wyniki kolejnych sesji.
- [Środowisko i rozwój](docs/development.md) — faktyczne wersje i struktura fundamentu.
- [Testowanie](docs/testing.md) — izolacja, kontrola QML i pomiar spoczynku.
- [Zrzut i wyniki etapu 00](docs/evidence/00-foundation.md).
- [Reguły workspace](docs/workspaces.md), [IPC i skrót klawiatury](docs/ipc.md).
- [Zrzuty i wyniki etapu 01](docs/evidence/01-bar.md).
- [Reguły paneli i fokusu](docs/panels.md), [zrzuty i wyniki etapu 02](docs/evidence/02-panels.md).
- [Ustawienia i format pliku](docs/settings.md), [zrzuty i wyniki etapu 03](docs/evidence/03-appearance.md).
- [Audio, OSD i polityka zdarzeń](docs/audio.md), [zrzuty i wyniki etapu 04](docs/evidence/04-audio.md).
- [Jasność, backend i ograniczenia](docs/brightness.md), [dowody etapu 05](docs/evidence/05-brightness.md).
- [Bateria i tray](docs/battery-tray.md), [dowody etapu 06](docs/evidence/06-battery-tray.md).
- [Sieć i Wi-Fi](docs/network.md), [dowody etapu 07](docs/evidence/07-network.md).
- [Bluetooth](docs/bluetooth.md), [dowody etapu 08](docs/evidence/08-bluetooth.md).
- [Powiadomienia, DND i migracja](docs/notifications.md), [dowody etapu 09](docs/evidence/09-notifications.md).
- [Sesja, blokada Quickshell i bezczynność](docs/session.md), [dowody etapu 10](docs/evidence/10-session.md).
- [Tapeta Quickshell, wygląd Hyprlanda i Night Light](docs/desktop.md), [dowody etapu 11](docs/evidence/11-desktop.md).
- [Odbiór funkcjonalny, wygląd i wydajność — etap 12](docs/validation.md).
- [Lokalna instalacja, przełączenie i powrót](docs/install.md).

## Podgląd i sprawdzenie

```sh
scripts/check
scripts/test
scripts/preview
scripts/preview --bar --size 1366x768 --scenario overflow --screenshot artifacts/bar.png
scripts/preview --panels --scenario settings --screenshot artifacts/settings.png
scripts/preview --panels --scenario settings --accent '#94e2d5' --secondary '#fab387' --screenshot artifacts/teal.png
scripts/test-settings-integration
scripts/preview --audio --screenshot artifacts/audio.png
scripts/preview --audio --scenario osd --screenshot artifacts/osd.png
scripts/test-audio-integration
scripts/preview --brightness --screenshot artifacts/brightness.png
scripts/preview --brightness --scenario brightnessOsd --screenshot artifacts/brightness-osd.png
scripts/test-brightness-integration
scripts/preview --status --scenario trayMenu --screenshot artifacts/tray.png
scripts/test-status-integration --idle
scripts/preview --network --scenario networkPassword --screenshot artifacts/wifi.png
scripts/test-network-integration --idle
scripts/preview --bluetooth --scenario bluetoothMultiple --screenshot artifacts/bluetooth.png
scripts/test-bluetooth-integration --idle
scripts/preview --notifications --screenshot artifacts/notification.png
scripts/test-notifications-integration --idle
scripts/preview --desktop --wallpaper solid --screenshot artifacts/desktop.png
scripts/test-desktop-integration --idle
scripts/test-validation-integration --idle
scripts/validate-visuals --output artifacts/validation-visuals
```

Podgląd zapisuje `artifacts/foundation.png` w trybie offscreen, z własnymi
katalogami XDG i prywatnym D-Bus. Nie uruchamia usług systemowych ani paneli
na aktywnym pulpicie. Wymaga Quickshell, Qt Quick/Controls/Test, Qt SVG,
Pythona i `dbus-run-session`; szczegóły w dokumentacji środowiska.
Test natywnego audio wymaga też PipeWire, `pw-cli` i `pw-metadata`.
Uruchamia odizolowany serwer wyłącznie z wirtualnymi wyjściami.
Produkcyjna regulacja jasności wymaga `brightnessctl`; jej testy podają
atrapę executable i nie dotykają prawdziwego podświetlenia.
Bateria korzysta z UPower oraz gdbus/busctl (glib2/systemd) do obsługi
zaniku usługi w Quickshell 0.3.1. Integracja baterii/traya wymaga testowych
pakietów python-dbus i python-gobject; używa fikcyjnych usług na prywatnym D-Bus.
Sieć używa Quickshell.Networking oraz gdbus/busctl do potwierdzania radia
i wykrywania utraty NM. Jej testy mają te same zależności Python i własną
atrapę NetworkManagera. Nie zmieniają sieci hosta. `nm-connection-editor`
jest opcjonalny; restart NM w Quickshell 0.3.1 wymaga restartu procesu Putkin.

Bluetooth korzysta z Quickshell.Bluetooth i tych samych narzędzi D-Bus.
Restart BlueZ wymaga restartu procesu Putkin w wersji Quickshell 0.3.1.
Test natywny ma prywatną atrapę BlueZ i nie paruje prawdziwych urządzeń.

Powiadomienia wymagają produkcyjnych python-dbus i python-gobject oraz
busctl do preflight. Jeden pasywny obserwator uzupełnia luki zastąpień
Quickshell 0.3.1; nie przekazuje obrazów ani body do strumienia JSON.
Testy używają natywnego serwera i rzeczywistych klientów na prywatnym D-Bus.
Nie przełączają serwera aktywnego pulpitu.

## Kolejne etapy

Wymagania [etapu 12](docs/prompts/12-validation.md) są spełnione;
[status](docs/status.md) i [raport](docs/validation.md) zawierają dowody
oraz ograniczenia. Putkin jest aktywnym shellem. Etap 13 obejmuje już lokalne
przełączenie i rollback oraz instalator ze stałą konfiguracją domyślną
i limitem pięciu buildów.
Każdy prompt zawiera własny
kontekst, zależności, zadanie i warunki odbioru; nie wymaga historii rozmowy.

Rekomendacja z audytu: nowy, mały korzeń aplikacji i nowe widoki; selektywnie adaptowane usługi, mechanizmy konfiguracji i testy z poprzedniego projektu.

Obrazy PNG są materiałami referencyjnymi, nie gotowymi tapetami ani elementami interfejsu. Poprzedni projekt nie został zmieniony.
