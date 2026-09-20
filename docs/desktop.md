# Pulpit i Night Light — etap 11

## Synchronizacja ramek — 2026-09-20

Na polecenie użytkownika Putkin synchronizuje ramki Hyprlanda z motywem:
kwadratowe rogi, 2 px, gradient aktywnej ramki oraz neutralna nieaktywna.
Zmiana dotyczy także grup okien. Podgląd, anulowanie i zapis kolorów mają
ten sam skutek w Shellu i kompozytorze; reload przywraca aktualne wartości.
Geometria oraz akcenty pochodzą ze wspólnych tokenów Putkin.
Gaps, opacity, blur, cienie i układ okien pozostają konfiguracją Hyprlanda.
[Kontrakt](design.md#ramki-okien-hyprlanda--2026-09-20),
[adapter i geometria gradientu](architecture.md#ramki-kompozytora--2026-09-20).

2026-09-16. **Tapeta należy do Quickshella, bez hyprpaper**, zgodnie
z decyzją użytkownika w tej sesji. Opcjonalny fragment wyglądu dotyczy
Hyprlanda **0.56.2 / Lua**, a temperatura obrazu — istniejącej usługi
użytkownika **hyprsunset 0.4.0**. Podczas implementacji etapu 11 nie zmieniono
konfiguracji osobistej ani autostartu. Późniejszą aktywację backendu opisuje
[wpis lokalny](#aktywacja-lokalna-2026-09-16).
[Wyniki implementacji i ograniczenia](evidence/11-desktop.md).

## Tapeta w Quickshellu

`WallpaperService` przyjmuje `PUTKIN_WALLPAPER` ze środowiska procesu Putkin:

| Wartość | Rezultat |
| --- | --- |
| Brak albo pusty tekst | Moduł wyłączony, brak powierzchni tapety |
| `solid` | Jednolite, nieprzezroczyste Mocha `#1e1e2e` |
| Bezwzględna ścieżka do pliku | Obraz, zachowanie proporcji i centralne przycięcie do monitora |
| Niepoprawna ścieżka / błąd obrazu | Mocha; diagnostyka modelu lub błąd obrazu w logu Qt |

`WallpaperWindows` tworzy jedną powierzchnię `Background` na ekran Qt.
Nie rezerwuje miejsca, nie przyjmuje fokusu i ma pustą maskę wejścia.
Zniknięcie monitora usuwa jego obiekt przez `Variants`. `Image` ładuje
asynchronicznie, ogranicza rozmiar dekodowania do rozmiaru ekranu/skali
i zwalnia obraz po usunięciu widoku. Obsługujemy wyłącznie lokalne ścieżki,
w tym spacje, `#` i `%`; URL sieciowy nie jest pobierany. Zmiana pliku pod
tą samą ścieżką wymaga reloadu Putkin. Nie ma pollingu ani dodatkowego procesu.

Bezpieczny podgląd neutralnego tła:

```sh
scripts/preview --desktop --wallpaper solid
scripts/preview --panels --scenario closed --wallpaper /bezwzględna/ścieżka/tapeta.png
```

Przy późniejszej aktywacji ustaw `PUTKIN_WALLPAPER=solid` albo ścieżkę
w środowisku **istniejącego procesu/usługi Putkin** i uruchom go ponownie.
Nie dodawaj drugiej instancji shella. Właścicielem tła w tej sesji ma być
Putkin; jeśli dotychczas działa inny program tapety, jego autostart należy
oddzielnie wyłączyć przed świadomym przełączeniem. Putkin nie zatrzymuje go.
Rollback: usuń zmienną i uruchom Putkin ponownie, następnie przywróć
poprzedniego właściciela tła, jeżeli był używany.

Cztery referencyjne PNG zawierają pasek/okna/opisy i nie są używane jako tło.
Przy lokalnym przełączeniu zachowano osobistą tapetę
`~/.config/hypr/backgrounds/Cloudsnight.jpg`. W końcowym odbiorze obejrzano
ten plik: jest czystą ilustracją 2048×1152 bez narysowanych elementów UI;
[suma i wynik przeglądu](evidence/12-closeout.json). Nie tworzono nowej
ilustracji ani nie nakładano opcjonalnego motywu Hyprlanda na konfigurację
użytkownika. Natywną macierz UI testowano na jednolitym Mocha.

## Opcjonalny wygląd Hyprlanda

[desktop-appearance.lua](../config/desktop-appearance.lua) ustawia gaps
6/12, ramkę 2 px, aktywny gradient Mauve–Blue, nieaktywny Surface1, rogi 0,
pełną nieprzezroczystość oraz wyłącza blur/cień okien. Nie zmienia
układu tilingu, monitorów, skrótów ani uruchamianych programów.

Po własnych ustawieniach wyglądu w `hyprland.lua` można dodać:

```lua
dofile("/bezwzględna/ścieżka/putkin/config/desktop-appearance.lua")
```

Usuń ten jeden wpis i przeładuj oryginalną konfigurację, aby wycofać
fragment. Test używa lokalnego `Hyprland --verify-config --config …`
na dwóch prywatnych konfiguracjach: z dołączonym fragmentem i po usunięciu
dołączenia. `hl.get_config` sprawdza powrót wcześniejszej ramki.
To odbiór parsera i wartości; nie potwierdza renderowania/reloadu aktywnej sesji.

## Night Light: stan i własność

Właścicielem backendu jest **istniejąca jednostka `hyprsunset.service`
użytkownika**. Putkin nie uruchamia drugiego demona, nie używa `pkill`,
nie włącza/wyłącza jednostki i nie kończy jej przy zamknięciu ani reloadzie.
Instalacja samego pakietu nie oznacza uruchomionej usługi. W Quick Settings
brak backendu daje opis niedostępności i Odśwież, bez przełącznika on/off.

`NightLightService` jest wspólny dla wszystkich paneli/monitorów. Przełącznik
oraz suwak 1000–6500 K używają jednego adaptera. Niższa temperatura daje
cieplejszy obraz. Suwak zapisuje po zakończeniu przeciągania; h/l i strzałki
zmieniają o 100 K, j/k przechodzą do sąsiednich kontrolek, Enter aktywuje.
Stan zaznaczenia pochodzi wyłącznie z potwierdzonego odczytu. Podczas
operacji nie przyjmujemy drugiego zapisu. Po błędzie trzeba odświeżyć stan;
operacja nie jest automatycznie ponawiana.

Pierwsze włączenie domyślnie wybiera 4500 K. Bieżąca aktywna temperatura
w zakresie suwaka staje się następną temperaturą włączenia w tej sesji.
Wyłączenie wysyła `identity true`, zachowując gamma i temperaturę backendu.
Nie utożsamiamy 6500 K z wyłączonym filtrem. Odczyt przyjmuje również
zewnętrzne temperatury 1000–20000 K i pokazuje ich rzeczywistą wartość.

`NightLightBackend` uruchamia krótki `night_light.py` z listą argumentów.
Pomocnik łączy się tylko z `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.hyprsunset.sock`.
Sprawdza UID, `SO_PEERCRED`, executable procesu, `MainPID`/`ActiveState`
jednostki użytkownika oraz wersję zainstalowanego executable zgodnego
z procesem. **Przed jakimkolwiek IPC** odrzuca obcego właściciela,
zastąpiony pakiet i wersję inną niż 0.4.0. Starsze 0.3.3 traktuje
`identity get` jako zmianę, dlatego nie wolno nim wykrywać capabilities.

Odczyt: `identity get`, `temperature`, ponownie `identity get` dla kontroli
zmiany w trakcie próbki. Zapis ma odczyt wstępny, token PID/starttime,
jedno polecenie i odczyt potwierdzający. Zmiana właściciela unieważnia zamiar.
Każde połączenie sprawdza ten sam token. Odpowiedź strumieniowa jest zbierana
do EOF, z limitem rozmiaru i czasu. Nawet odpowiedź `ok` nie zastępuje
odczytu. Timeout może nastąpić już po zmianie w backendzie; UI wycofuje
wtedy pewność stanu i prosi o odświeżenie.

Terminy: 0,35 s na socket, 0,8 s na odczyt jednostki/wersji, 5 s na całego
pomocnika QML; następnie SIGTERM i po 150 ms SIGKILL. Procesy sprawdzające
jednostkę/wersję są związane z życiem pomocnika przez `PR_SET_PDEATHSIG`.
Bez dodatkowego stale działającego procesu i bez okresowego odpytywania.
Odczyt następuje przy starcie, otwarciu Quick Settings, ręcznym Odśwież
i operacji. Zmiany wykonane zewnętrznym programem podczas otwartego panelu
wymagają odświeżenia. Harmonogramy, geolokalizacja, gamma i nowe pola
`settings.json` są poza zakresem. Nie dodano produkcyjnego IPC.

## Przykład uruchomienia usługi i wycofanie

To procedura aktywacji w sesji Hyprlanda/uwsm. Zastosowano ją później
podczas lokalnego uruchomienia opisanego poniżej, bez włączania autostartu.

1. Sprawdź `hyprsunset --version` (wspierane 0.4.0) i
   `systemctl --user status hyprsunset.service`. Jeżeli backend uruchamia
   inny autostart, uporządkuj jego własność przed włączeniem tej jednostki.
2. Przygotuj osobny katalog `~/.config/putkin/night-light/hypr/`
   i umieść tam [przykład](../config/hyprsunset.example.conf) jako
   `hyprsunset.conf`. Nie zastępuje on osobistego `~/.config/hypr/hyprsunset.conf`.
3. Umieść [drop-in](../config/hyprsunset-putkin.example.conf) w
   `~/.config/systemd/user/hyprsunset.service.d/putkin.conf`, zachowując
   kopię wcześniejszego pliku o tej nazwie, jeżeli istnieje. Wskazuje
   osobny `XDG_CONFIG_HOME` i start z `--identity`, bez profili czasowych.
4. W docelowej sesji sprawdź środowisko managera użytkownika:
   `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR` i `HYPRLAND_INSTANCE_SIGNATURE`
   muszą wskazywać tę samą sesję co Putkin. Następnie `systemctl --user
   daemon-reload` i uruchom lub zrestartuj **tę jedną** jednostkę.
   Włączenie jej autostartu jest osobną decyzją użytkownika.
5. Odśwież Night Light w panelu i sprawdź rzeczywisty ekran.

Rollback: przywróć poprzedni drop-in (albo usuń wyłącznie dodany `putkin.conf`),
wykonaj `daemon-reload` i przywróć wcześniejszy stan jednostki. Jeżeli wcześniej
nie działała, zatrzymaj ją; jeżeli działała, uruchom ją z wcześniejszymi
ustawieniami. Oddzielny katalog przykładu można usunąć po wycofaniu drop-in.

W lokalnym 0.4.0 `--config ścieżka` nie pomija argumentu ścieżki w parserze
CLI i kończy się błędem. Przykład używa sprawdzonego wyszukiwania konfiguracji
przez XDG. Test rzeczywistym executable potwierdza wczytanie konfiguracji
i odróżnia ją od celowo niedomkniętej sekcji; potem program zgodnie
z izolacją kończy się błędem braku Waylanda. Nie jest to test zmiany kolorów.

## Aktywacja lokalna 2026-09-16

Po zgłoszeniu niedostępnego Night Light potwierdzono przyczynę: pakiet 0.4.0
był zainstalowany, lecz usługa pozostawała `inactive/dead`, bez procesu.
Adapter Putkin zwracał `absent`. Środowisko managera systemd odpowiadało
aktywnemu Hyprlandowi; nie trzeba było zmieniać jego zmiennych sesji.

Utworzono dwa wcześniej nieistniejące pliki z powyższych przykładów:

- `~/.config/putkin/night-light/hypr/hyprsunset.conf` — bez profili czasowych.
- `~/.config/systemd/user/hyprsunset.service.d/putkin.conf` — osobne XDG
  i `ExecStart=/usr/bin/hyprsunset --identity`.

Po `systemctl --user daemon-reload` i `systemctl --user start hyprsunset.service`
jednostka zaczęła działać. Początkowy odczyt produkcyjnego adaptera:
`enabled: false`, `temperature: 6000`, `error: ""`, przy autostarcie
**disabled**. Był to odbiór dostępności backendu z wyłączonym filtrem.
Ponowne otwarcie Quick Settings albo przycisk Odśwież pobiera nowy stan.

[Stan przed/po i sumy konfiguracji](evidence/12-night-light-session.json),
[log usługi](evidence/12-night-light-session.log). Oryginał potwierdzenia
jest w `~/.local/state/putkin/night-light-20260916/receipt.json`.

Później użytkownik potwierdził, że włączenie Night Light ociepla obraz,
a wyłączenie przywraca normalne kolory: **PASS wizualnego odbioru**.
[Końcowy odczyt](evidence/12-closeout-live.json), wykonany po działaniach
użytkownika, wykazał `enabled: true`, `temperature: 4500`, brak błędu
oraz jednostkę `active/running` z autostartem **enabled**.
Podczas tego odczytu nie zmieniano filtra ani stanu jednostki.
[Zgłoszenie użytkownika](evidence/12-user-acceptance.json).

Wycofanie tej aktywacji: zatrzymaj `hyprsunset.service`, usuń wyłącznie te dwa
dodane pliki (o ile nie zostały później zmienione) i wykonaj `daemon-reload`.
Przywraca to brak drop-in i zatrzymuje usługę. Usunięcie drop-in nie wyłącza
autostartu: aby wrócić także do początkowego stanu `disabled`, wykonaj
osobno `systemctl --user disable hyprsunset.service`.
Nie trzeba zmieniać ani restartować Putkin. Działania użytkownika po
początkowej aktywacji należy uwzględnić przed wycofaniem konfiguracji.

## Granice wyglądu i sprawdzone źródła

Putkin rysuje tapetę, pasek, panele, OSD i toasty. Hyprland zarządza
ramkami/gaps/tilingiem, Hyprlock blokadą, Kitty zawartością terminala,
Fish promptem, a Neovim własnym UI. Ich motywy Mocha można ustawić
niezależnie. Putkin nie tworzy pasków tytułu widocznych wewnątrz tych
aplikacji na referencjach. Od 2026-09-20 zmiana akcentów Putkin obejmuje
również ramki kompozytora; motywy zawartości aplikacji pozostają oddzielne.

Przed implementacją sprawdzono lokalne wersje i dokumentację:

- Quickshell 0.3.1: [PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
  [WlrLayershell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrLayershell/),
  [Process](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/), lokalne qmltypes.
- Qt 6.11.2: [Image](https://doc.qt.io/qt-6.11/qml-qtquick-image.html),
  [Slider](https://doc.qt.io/qt-6.11/qml-qtquick-controls-slider.html).
- Hyprland 0.56.2: [przykład Lua z tagu](https://github.com/hyprwm/Hyprland/blob/v0.56.2/example/hyprland.lua),
  lokalne `/usr/share/hypr/hyprland.lua`, `stubs/hl.meta.lua`, `--help` i natywny parser.
- hyprsunset 0.4.0: [IPC](https://github.com/hyprwm/hyprsunset/blob/v0.4.0/src/IPCSocket.cpp),
  [CLI](https://github.com/hyprwm/hyprsunset/blob/v0.4.0/src/main.cpp),
  [konfiguracja](https://github.com/hyprwm/hyprsunset/blob/v0.4.0/src/ConfigManager.cpp),
  [jednostka użytkownika](https://github.com/hyprwm/hyprsunset/blob/v0.4.0/systemd/hyprsunset.service.in).
  Kontrast API: [0.3.3](https://github.com/hyprwm/hyprsunset/blob/v0.3.3/src/IPCSocket.cpp).
- Hyprutils 0.14.2: [wyszukiwanie XDG](https://github.com/hyprwm/hyprutils/blob/v0.14.2/src/path/Path.cpp).
  Python 3.14.7: [subprocess](https://docs.python.org/3.14/library/subprocess.html);
  Linux: [PR_SET_PDEATHSIG](https://man7.org/linux/man-pages/man2/PR_SET_PDEATHSIG.2const.html).
