# Bateria i tray — etap 06

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade; ograniczony ruch
wyłącza je natychmiast. Kontrakty adapterów i potwierdzania operacji pozostają.


Quickshell 0.3.1 / Qt 6.11.2. Jeden `UPowerBackend` i `BatteryService`
oraz jeden `TrayService` są składane w `shell.qml` i przekazywane paskom
i `PanelHost`. Produkcja korzysta z UPower i natywnych klientów SNI;
atrapy należą wyłącznie do podglądu i testów.

## Bateria

Źródłem jest **DisplayDevice UPower**, czyli agregat zasilania komputera.
Nie wybieramy pierwszego elementu `devices`: może nim być mysz lub słuchawki.
Wskaźnik wymaga `ready`, `isPresent` i `isLaptopBattery` (Battery oraz
PowerSupply). Brak głównej baterii usuwa przycisk paska; Quick Settings
wyświetla brak baterii lub niedostępność usługi. UPS nie jest przedstawiany
jako bateria laptopa. Agregacja kilku baterii należy do UPower.

Quickshell 0.3.1 przelicza procent z D-Bus na zakres **0–1**. Model
normalizuje go do 0–100; niepoprawny/nieznany procent daje „—”. Zero
jest prawidłowym odczytem. Stan nieznany ma jawny tekst. Czas pochodzi
wyłącznie z `TimeToFull` podczas ładowania lub `TimeToEmpty` podczas
rozładowania. Wartości zerowe, ujemne i niefinitywne nie tworzą szacunku.

Przy rozładowaniu do 20% pojawia się ostrzeżenie, do 5% stan krytyczny.
Znacznik `!`, tekst i role Theme.warning/error są niezależne od akcentów.
Ładowanie ma znacznik `+`. Kliknięcie/Enter otwiera osobny panel baterii.

### Osobny panel i tryby — rozszerzenie 2026-09-17

Adaptacja `popups/BatteryPopup.qml` i `services/PowerService.qml` poprzednika:
procent, poziomy pasek, czas oraz Oszczędny / Zrównoważony /
Wydajność. UI korzysta z tokenów Putkina i standardowych przycisków Qt,
bez zaokrągleń i animacji geometrii. Trzy wiersze mieszczą pełne polskie
nazwy wyśrodkowane w pionie; wybrany tryb ma akcent i stan `checked` Qt,
bez widocznej etykiety „Aktywny”. Panel nie ma nagłówków „Bateria” / „Tryb
pracy”, przycisku ×, separatora nad profilami, tekstu stanu przy procencie
ani osobnego tekstu o niskim poziomie. Nieznany czas pokazuje
„Szacowanie czasu…”, pełna bateria ukrywa czas, brak baterii zachowuje
dostęp do profili przez `ui openBattery`. Bez własnego algorytmu szacowania.
Podczas przełączania profilu nie ma widocznego napisu „Zmiana…”.

`BatteryView` korzysta ze wspólnego `PanelHost`, LazyLoadera i reguły jednego
panelu. Kliknięcie ikony wybiera jej monitor; IPC skupiony monitor.
Escape/kliknięcie poza panelem zamyka; powrót z nawigacji paska przywraca
fokus ikony. j/k i strzałki wybierają wiersze, Enter aktywuje. Niedostępne
profile są pomijane, a nawigacja zapętla dostępne wiersze; zanik aktywnej
kontroli przenosi fokus na dostępny profil lub sam panel (Escape).
Na małym ekranie widok przewija się do kontrolki z fokusem.

Jeden `PowerProfileBackend` i czysty `PowerProfileService` obsługują
**power-profiles-daemon 0.30**, dostępny w tym środowisku. W poprzedniku
bezpośrednio zapisywano `PowerProfiles.profile`. Sprawdzone źródło
Quickshell 0.3.1 zmienia tę właściwość optymistycznie i nie udostępnia
gotowości, błędu zapisu ani powrotu właściciela. Dlatego mały adapter
korzysta z tego samego oficjalnego interfejsu PPD przez istniejące
gdbus/busctl. Nie dodaje demona ani zależności od poprzedniego repozytorium.

Jeden obserwator gdbus subskrybuje właściciela i `PropertiesChanged`.
`GetAll` zwraca typowane JSON dla `ActiveProfile`, `Profiles` i
`PerformanceDegraded`; brak usługi usuwa nieaktualny wybór. Po kliknięciu
busctl zapisuje string `ActiveProfile`, a nowy odczyt potwierdza wynik.
Brak potwierdzenia i odmowa trafiają do powiadomienia. Jedna operacja
w locie, timeouty 2/3 s, bez pollingu. Generacja i unikalny właściciel
chronią przed spóźnioną odpowiedzią; restart PPD i późny start są obsługiwane.
Awaria samego obserwatora/magistrali wymaga restartu shella. Wybór profilu
może zwolnić żądania profilu innych aplikacji, zgodnie z kontraktem PPD.

Sprawdzone API: [PowerProfiles 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/PowerProfiles/),
[setter w źródłach](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/upower/powerprofiles.cpp),
[PPD 0.30](https://upower.pages.freedesktop.org/power-profiles-daemon/),
[interfejs PPD](https://upower.pages.freedesktop.org/power-profiles-daemon/gdbus-org.freedesktop.UPower.PowerProfiles.html),
[ProgressBar Qt 6.11.2](https://doc.qt.io/qt-6/qml-qtquick-controls-progressbar.html).

### Brak i powrót UPower

Źródła Quickshell 0.3.1 wykazały brak obserwacji właściciela usługi:
nieudany start nie jest ponawiany, a zanik usługi pozostawia odczytane dane.
Z tego konkretnego powodu adapter ma małe uzupełnienie:

- Jeden potomny `gdbus monitor --system --dest org.freedesktop.UPower`
  obserwuje sygnały i właściciela usługi, bez pollingu ani uprawnień
  `BecomeMonitor`. Dostaje locale C; adapter rozpoznaje dokładne prefiksy,
  nie parsuje wartości z tekstowej reprezentacji GVariant.
- Zanik właściciela natychmiast unieważnia stan. Po powrocie, starcie bez
  usługi lub zastanym singletonie podczas reloadu, `busctl --json=short`
  odczytuje `GetAll` standardowego DisplayDevice. Kolejne odczyty wywołuje
  wyłącznie jego `PropertiesChanged`. Pierwszy start z gotową usługą
  korzysta bezpośrednio z natywnego UPower. Jednorazowe 500 ms oczekiwania
  pozwala przejść do odczytu awaryjnego, gdy natywny adapter nie uzyska `ready`.
- Jest najwyżej jeden odczyt w locie i jedna oczekująca aktualizacja.
  Generacja właściciela odrzuca spóźnione odpowiedzi; busctl ma timeout 2 s.
  Błąd odczytu ukrywa nieaktualny procent. Brak narzędzia/obserwatora
  pokazuje niedostępność; nie powstaje pętla restartów.

To zależność od już dostępnych `gdbus` (glib2 2.88.3) i `busctl`
(systemd 261), bez własnego demona, pluginu C++ ani zapisu do sprzętu.
Awaria samego systemowego D-Bus/obserwatora wymaga restartu Putkin;
obsługa zniknięcia i późnego startu **usługi UPower** jest automatyczna.
Natywna diagnostyka braku UPower może pozostać w logu mimo późniejszego
udanego odczytu przez ścieżkę awaryjną.

## Tray i menu

`TrayService` zachowuje natywny `SystemTray.items` i tożsamość obiektów.
Stan Passive ukrywa przycisk; NeedsAttention dodaje znacznik ostrzeżenia.
Pasek pokazuje najwyżej cztery aplikacje i przycisk `⋯`; poniżej 1000 px
dwie, poniżej 600 px tylko `⋯`. Overflow udostępnia wszystkie aktywne
aplikacje wraz z jawnym przyciskiem menu. Brak menu wyłącza ten przycisk.
Przy bardzo małej szerokości audio pozostaje dostępne w Quick Settings.
Workspace, zegar, bateria i wejście do panelu mieszczą się przy 320 px.

| Wejście | Działanie |
| --- | --- |
| Lewy klik, Enter, Enter numeryczny, Spacja | `activate()`, a dla `onlyMenu` otwarcie menu |
| Środkowy klik, Shift+Enter | `secondaryActivate()` |
| Prawy klik, klawisz Menu, Shift+F10 | Menu, jeśli aplikacja je udostępnia |
| h/l w pasku | Poprzedni/następny przycisk |
| j/k w overflow i menu | Następny/poprzedni dostępny wiersz |
| l/Enter na podmenu | Wejście do podmenu |
| h/Escape w podmenu | Powrót do rodzica; następnie overflow lub pasek |

Przyciski mają nazwy dostępności i rzeczywiste tooltipy. Długi tooltip
zawija zwykły tekst i ogranicza szerokość do okna. Puste źródło/błąd Image
pokazuje inicjał nazwy. Natywny provider Quickshell może sam dostarczyć
obraz zastępczy; dla klienta bez pixmapy loguje pojedyncze ostrzeżenie.

Menu korzysta z `QsMenuOpener` i `QsMenuEntry` przez mały
`TrayMenuAdapter`. Natywny DBusMenu odpowiada za układ, widoczność,
zmiany właściwości i zdarzenia. Putkin renderuje separatory, pozycje
wyłączone, checkbox/radio, ikony i podmenu. Akcja wywołuje `triggered()`.
W 0.3.1 DBusMenu pobiera całe drzewo przez `AboutToShow(0)`/`GetLayout`;
wejście do podmenu emituje `opened`, bez osobnego `AboutToShow` tego ID.
Nie rozszerzamy natywnego protokołu o niezależnego klienta.

Podmenu zastępuje listę wewnątrz tej samej powierzchni. Otwieracze rodziców
pozostają żywe, dopóki istnieją potomkowie; zamykanie zwalnia je od końca.
Zniknięcie klienta zamyka jego menu, usunięcie podmenu cofa do rodzica,
a usunięcie wybranej pozycji przenosi fokus do dostępnej kontroli.

`trayMenu` i `trayOverflow` uczestniczą w tej samej sesji
`PanelCoordinator` co Quick Settings i Wygląd. Otwarcie menu odrzuca
niezapisany podgląd wyglądu. Kolejne podmenu nie tworzy osobnego okna ani
graba. Panel kotwiczy się przy przycisku na jego monitorze i jest
ograniczony z obu stron oraz w wysokości; zawartość przewija się do fokusu.
Zamknięcie przez akcję aplikacji oddaje klawiaturę kompozytorowi.
Escape przywraca nawigację paska, jeśli to z niej rozpoczęto.
IPC i format ustawień pozostają bez zmian.

## Sprawdzone API

- [UPower 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/UPower/),
  [UPowerDevice](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/UPowerDevice/),
  [źródła cyklu usługi](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/upower/core.cpp),
  [przeliczanie procentu](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/upower/device.cpp).
- [SystemTrayItem](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.SystemTray/SystemTrayItem/),
  [QsMenuOpener](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsMenuOpener/),
  [QsMenuEntry](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsMenuEntry/),
  [DBusMenuHandle](https://quickshell.org/docs/v0.3.1/types/Quickshell.DBusMenu/DBusMenuHandle/).
- [gdbus GLib 2.88.3](https://github.com/GNOME/glib/blob/2.88.3/gio/gdbus-tool.c),
  [busctl systemd 261](https://github.com/systemd/systemd/blob/v261/man/busctl.xml),
  [protokół urządzenia UPower](https://upower.freedesktop.org/docs/Device.html),
  [Qt 6.11 TapHandler](https://doc.qt.io/qt-6/qml-qtquick-taphandler.html).

Testy i ograniczenia środowiskowe: [testing.md](testing.md),
[dowody](evidence/06-battery-tray.md), [status](status.md).
