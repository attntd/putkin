# Audio i OSD — etap 04

## Quick Menu i krótkie nazwy — 2026-09-19

Quick Menu ma jeden przystanek klawiatury na całym wierszu dźwięku.
`h/l` zmieniają głośność, `Enter/i` rozwijają lub zwijają wyjścia, `j/k`
przechodzą między wierszami. Tab pomija osobną strzałkę i ikonę wyciszenia;
mysz zachowuje ich osobne działania. Ramka obejmuje cały wiersz i jest
widoczna tylko po wejściu klawiaturą. Osobny panel audio zachowuje pełne
sterowanie wyjściem i mikrofonem.

Etykiety pochodzą z `name`, `nickname`, `description` PwNode bez nowego
trackera ani odpytywania sprzętu. Wbudowane wyjście Speaker to
„Wbudowane głośniki”, Headphones to „Słuchawki”, a HDMI ma numer złącza.
Równe etykiety są rozróżniane numerem w stabilnej kolejności nazw węzłów.
Zmiana wyjścia domyślnego nie zmienia nazw urządzeń. Sprawdzono
[PwNode 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwNode/)
oraz [Slider Qt 6.11.2](https://doc.qt.io/qt-6.11/qml-qtquick-controls-slider.html).

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade; ograniczony ruch
wyłącza je natychmiast. Kontrakty adapterów i potwierdzania operacji pozostają.


Jeden `AudioService` jest współdzielony przez wszystkie paski, panel audio,
Quick Settings i IPC. Produkcyjny `PipewireBackend` używa Quickshell.Services.Pipewire;
widoki dostają usługę przez właściwości i nie uruchamiają poleceń.
Rozszerzenie 2026-09-17 dodaje mikrofon i wybór wejścia; nie ma miksera aplikacji. Od etapu 05 panel i OSD
współdzielą miejsce z osobną usługą [jasności](brightness.md).

`AudioChannelService` obsługuje wspólny kontrakt jednego kierunku audio:
`devices`, `defaultDevice`, `deviceName`, `available`, `volume`, `muted`,
`busy`, `lastError`, `selectDevice` i operacje poziomu/wyciszania.
`AudioService` zachowuje dotychczasowe nazwy wyjścia oraz zawiera
`microphone` z tym samym kontraktem, własnym potwierdzeniem i timeoutem.
`PipewireChannel` współdzieli implementację trackerów dla obu kierunków;
`PipewireBackend.input` wybiera źródła przez `!isSink && !isStream && audio`,
`defaultAudioSource` i `preferredDefaultAudioSource`. Dwa trackery obserwują
tylko domyślne urządzenia. Błędy wejścia mają osobny toast „Mikrofon”,
bez zmiany stanu operacji wyjścia i bez OSD głośnika.

## Stan i operacje

`available`, `defaultOutput`, `outputName`, `volume` (procenty), `muted`,
`outputs`, `busy`, `lastError` i `statusText` stanowią kontrakt widoku.
Niedostępne audio ma `volume = -1`, a IPC zwraca `volume: null`.
Brak PipeWire, brak domyślnego wyjścia i oczekiwanie na odczyt mają osobne
etykiety; pasek pokazuje kreskę zamiast fikcyjnego 0%.

`setVolume(percent, monitor)`, `changeVolume(points, monitor)`,
`setMuted(bool, monitor)`, `toggleMute(monitor)` i
`selectOutput(node, monitor)` przyjmują tylko poprawne dane. Zadany poziom
jest ograniczony do 0–100%; zmiana względna zatrzymuje się na granicach.
NaN, Infinity, wartości poza zakresem, konwersje z tekstu i nieaktualne
urządzenia są odrzucane. Regulacja poziomu nie zmienia wyciszenia.
Zewnętrzny poziom powyżej 100% jest widoczny liczbowo, a pasek/suwak kończy
się na 100%; samo jego odczytanie nie zmienia urządzenia.

Lista zawiera natywne obiekty `isSink && !isStream && audio`. Identyfikatory
i nazwy innych wyjść nie wymagają trackera. Jeden `PwObjectTracker` śledzi
domyślne wyjście. Po `Pipewire.ready`, `PwNode.ready` i odczycie kanałów
publikowana jest spójna próbka `{node, volume, muted}`. Zwykłe zmiany modelu
aktualizują ją zdarzeniowo, bez cyklicznego `wpctl` i bez procesu pomocniczego.

Quickshell 0.3.1 ustawia poziom/mute optymistycznie i nie wystawia QML
potwierdzenia ani błędu zapisu. Adapter pomija te lokalne sygnały. Po 100 ms
od ostatniej komendy zwalnia i ponownie wiąże tracker, wymuszając świeży
odczyt Props serwera. W czasie odczytu następne komendy są kolejkowane.
Pasek, etykieta panelu i OSD pokazują próbkę backendu; przesuwany uchwyt
może wskazywać żądany poziom, bez komunikatu postępu. Po odmowie lub
timeout wraca do stanu odczytanego. Kolejne przyrosty sumują się także
przed potwierdzeniem wcześniejszej komendy.

Operacja ma limit 1800 ms. Poziom uznaje się za potwierdzony przy różnicy
mniejszej niż 0,5 punktu procentowego; mute wymaga zgodności bool.
Wybranie urządzenia ustawia `preferredDefaultAudioSink`, ale UI uznaje
wybór dopiero po zmianie rzeczywistego `defaultAudioSink` i odczycie.
Preferencja sama nie gwarantuje zmiany przez menedżer polityki, np.
WirePlumber. Brak potwierdzenia, zanik wyjścia i odmowa są widocznym błędem.

`shell.qml` ustawia `QS_PIPEWIRE_IMMEDIATE_RECONNECT=1` przez pragmę Env.
Pozwala to Quickshellowi czekać na start PipeWire również po początkowym
braku serwera. Po awarii natywna biblioteka czyści modele i obserwuje katalog
runtime, żeby połączyć się ponownie. W 0.3.1 mechanizm ten działa dla
domyślnego socketa `pipewire-0`; ustawienie `PIPEWIRE_REMOTE` wyłącza watcher
i wymaga restartu shella po powrocie takiego niestandardowego serwera.

## Wejście i fokus

Ikona audio otwiera osobny panel `audio`: od razu widoczne suwaki głośnika
i mikrofonu, wyciszanie i obie listy wyboru urządzeń. Brak nagłówka
i instrukcji; krótkie etykiety „Wyjście” i „Wejście” rozróżniają listy.
Kółko myszy na ikonie zmienia poziom wyjścia
o 5 punktów, z kontekstem jej monitora. `h/l` przechodzą między przyciskami paska;
Enter otwiera panel, Escape wraca do wywołującego przycisku.

Osobny panel audio zaczyna od suwaka, jeśli wyjście jest dostępne. `h/l` oraz strzałki
zmieniają poziom; `j/k` przenoszą fokus pionowo. Enter potwierdza bieżący
poziom; na przyciskach aktywuje mute, listę lub wybór wyjścia. Tab/Shift+Tab
i Spacja zachowują standardowe wejście Qt. Escape zamyka osobny panel audio;
w Quick Settings nadal najpierw zwija listę wyjść. Obie listy mieszczą się
w przewijanej powierzchni; zniknięcie urządzenia nie pozostawia fokusu
na martwym elemencie, a brak obu kierunków nadal pozwala zamknąć panel.

## OSD

Jeden `OsdService` i `OsdHost` sterują jednym `LazyLoader`. Widok pojawia się
na dole, pośrodku monitora, 24 px od krawędzi. `PanelWindow` ma warstwę
Overlay, `WlrKeyboardFocus.None`, pustą maskę wejścia, `exclusiveZone: 0`
i `ExclusionMode.Ignore`. Nie ma graba, klikalnych kontrolek ani wywołania
przejmującego fokus. To konfiguracja okna; potwierdzenie zachowania
kompozytora wymaga osobnego odbioru Waylanda.

- Własna potwierdzona komenda pokazuje OSD, także na granicy 0/100%.
- Zewnętrzna zmiana poziomu lub mute bieżącego wyjścia również je pokazuje.
- Pierwsza próbka, nowy domyślny sink, powrót backendu i reload ustanawiają
  stan początkowy bez OSD. Własny potwierdzony wybór wyjścia może je pokazać.
- Panel Quick Settings załadowany i interaktywny na dowolnym monitorze
  ukrywa OSD audio/jasności i pomija nowe żądania. Strona Wygląd go nie blokuje.
- Osobny panel audio ukrywa OSD głośności; OSD jasności pozostaje dostępne.
- Komenda z paska/panelu wskazuje swój monitor. IPC i zmiany zewnętrzne
  wybierają monitor skupiony w Hyprlandzie, następnie pierwszy ekran Qt.
  Brak ekranu lub zbyt mały ekran pomija OSD. Usunięcie aktywnego ekranu,
  zanik audio i zmiana domyślnego urządzenia chowają bieżące OSD audio.
- Każde kolejne zdarzenie odnawia 1500 ms. Po timeout loader jest zwalniany
  od razu; brak okresowego timera, animacji i niewidocznego okna w spoczynku.
  Wypełnienie korzysta z reaktywnego `Theme.accent`.

Od etapu 05 `OsdService.kind` wybiera audio/jasność, a `LevelOsd` otrzymuje
neutralne `level`, `label`, `symbol` i `fillColor`. Potwierdzona akcja
drugiej usługi zmienia zawartość istniejącego loadera i odnawia timeout.
Jasność używa `Theme.accentSecondary`; błąd drugiej domeny nie chowa
niezwiązanego z nim OSD.

## Zweryfikowane API

Wersje lokalne: Quickshell 0.3.1, Qt 6.11.2, PipeWire 1.6.8,
WirePlumber 0.5.17 (nieuruchamiany w testach).

- [Pipewire 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/Pipewire/),
  [PwNode](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwNode/),
  [PwNodeAudio](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwNodeAudio/),
  [PwObjectTracker](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwObjectTracker/).
- [Settery i odczyt 0.3.1](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/pipewire/node.cpp),
  [restart połączenia](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/pipewire/connection.cpp),
  [pragmy Env](https://quickshell.org/docs/v0.3.1/guide/advanced/).
- [Slider Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-controls-slider.html),
  [PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
  [Region](https://quickshell.org/docs/v0.3.1/types/Quickshell/Region/),
  [WlrLayershell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrLayershell/).
- [Konfiguracja PipeWire 1.6.8](https://docs.pipewire.org/page_man_pipewire_conf_5.html)
  i jej lokalny przykład `/usr/share/pipewire/pipewire.conf`; test korzysta
  z własnego pliku bez modułów wykrywających urządzenia.

Polecenia testów i granice izolacji: [testing.md](testing.md).
Publiczne metody i przykłady skrótów: [ipc.md](ipc.md).
