# IPC Putkin

Rozszerzenie Klawiatura: `actions invoke(action: string): string` przyjmuje
ID z [katalogu działań](keyboard.md) i zwraca `accepted` lub błąd.
`actions status(): string` zwraca JSON: `ready`, `busy`, `applied`, `error`,
liczbę `shortcuts` i `commands`. `ui openSettings` otwiera/przywołuje osobne
natywne okno. `launcher openCommands` otwiera pusty edytor z chipem „Komenda”.

`actions invoke screenshot` otwiera wybór zakresu na bieżącym monitorze.
Jest wspólnym wejściem dla Print oraz `:screenshot`. Wybór zachowuje okno
sprzed wywołania, nie przechwytuje obrazu przed Enter/W i odrzuca kolejne
uruchomienia do zamknięcia bieżącej operacji. [Skróty i zapis](screenshot.md).

Etapy 01–09. Quickshell **0.3.1**; handlery `bar`, `ui`, `audio`, `brightness` i `notifications` są wspólne dla procesu.
Wywołanie wskazuje tę samą ścieżkę konfiguracji co uruchomiony shell:

```sh
quickshell ipc --path /ścieżka/putkin/shell.qml call bar focus
quickshell ipc --path /ścieżka/putkin/shell.qml call bar close
```

| Funkcja | Wynik | Zachowanie |
| --- | --- | --- |
| `bar focus(): string` | Nazwa monitora albo pusty napis | Rozpoczyna nawigację na monitorze skupionym przez Hyprlanda. Gdy nie ma odpowiadającego mu ekranu Qt, wybiera pierwszy ekran Qt obecny w modelu Hyprlanda. Bez dostępnego monitora niczego nie skupia. |
| `bar close(): void` | Brak | Kończy nawigację i oddaje klawiaturę compositorowi. |
| `bar status(): string` | JSON | Odczyt dostępności, monitorów z `activeId`, `focusedMonitor`, workspace’ów z `visibleOn`, `busy` i `error`; bez zmiany fokusu ani workspace’u. |

`focus` wybiera aktywny workspace danego monitora; powtórne wywołanie
ponownie ustawia ten wybór. `h`/`l` przesuwają wybór, `Enter` i Enter
numeryczny aktywują go **raz** i kończą nawigację. `Escape` zamyka ją bez
aktywacji. Dodatkowo działają strzałki, Home/End, Tab i standardowa Spacja
przycisku. Na poziomej liście `j`/`k` nie mają celu pionowego.

Normalnie pasek ma `WlrKeyboardFocus.None`. Tylko pasek wybrany przez IPC
przechodzi na `Exclusive`; po zamknięciu, przyjęciu akcji, utracie połączenia
lub usunięciu monitora wraca do `None`. Brak globalnych handlerów liter.
Obsługę realnego fokusu kompozytora należy jeszcze odebrać na Waylandzie;
testy offscreen potwierdzają wejście Qt oraz decyzje kontrolera.

Etap 04: `l` za ostatnim workspace przechodzi na audio, następnie Quick Settings;
`h` wraca w przeciwną stronę. Enter na tych przyciskach otwiera panel. Zamknięcie
Escape oddaje fokus przyciskowi. `bar focus` zamyka otwarty panel;
`bar close` kończy wyłącznie nawigację paska.

## Panele

```sh
quickshell ipc --path /ścieżka/putkin/shell.qml call ui openQuickSettings
quickshell ipc --path /ścieżka/putkin/shell.qml call ui toggleQuickSettings
quickshell ipc --path /ścieżka/putkin/shell.qml call ui openSettings
quickshell ipc --path /ścieżka/putkin/shell.qml call ui closePanels
```

| Funkcja | Wynik | Zachowanie |
| --- | --- | --- |
| `ui openNetwork(): string` | `ok` lub kod błędu | Otwiera osobny panel Wi-Fi i widoczną listę sieci. |
| `ui openBluetooth(): string` | `ok` lub kod błędu | Otwiera moduł Bluetooth i sparowane urządzenia. |
| `ui openNotifications(): string` | `ok` lub kod błędu | Otwiera centrum powiadomień z DND. |
| `ui openQuickSettings(): string` | `ok` lub kod błędu | Otwiera Quick Settings, zastępując inny interaktywny panel. |
| `ui toggleQuickSettings(): string` | `ok` lub kod błędu | Zamyka Quick Settings na wybranym ekranie; w pozostałych przypadkach otwiera go na tym ekranie. |
| `ui openSettings(): string` | `ok` lub kod błędu | Otwiera edytor akcentów i ograniczenia ruchu z podglądem i zapisem. |
| `ui openAudio(): string` | `ok` lub kod błędu | Otwiera osobny panel głośnika, mikrofonu i urządzeń. |
| `ui toggleAudio(): string` | `ok` lub kod błędu | Przełącza widoczność panelu audio na wybranym ekranie. |
| `ui closePanels(): void` | Brak | Zamyka panel, zwalnia wejście od razu i niszczy okno po fade. Bez panelu niczego nie zmienia. |

Ekran: skupiony monitor Hyprlanda, jeśli odpowiada ekranowi Qt; następnie
pierwszy ekran Qt. Działa również przy niedostępnym adapterze workspace.
Bez ekranu funkcje otwarcia zwracają `screen-unavailable`; gdy nie ma miejsca
pod paskiem — `screen-too-small`. Kod błędu jest **tekstem wyniku metody**,
nie kodem wyjścia procesu `quickshell ipc`. Wywołania nie przyjmują dowolnego
identyfikatora powierzchni. Wewnętrzne `PanelCoordinator.open()` odrzuca
nieznane ID jako `unknown-surface`, zachowując dotychczasowy panel.

Otwieranie Quick Settings daje fokus suwakowi audio, dostępnemu wyborowi
wyjścia, następnie jasności lub jej diagnostyce przy braku audio. Ustawienia zaczynają
od „Wstecz”. Zwykłe zamknięcie
po wejściu IPC oddaje klawiaturę kompozytorowi. Jeśli wywołanie zastąpiło
panel otwarty z nawigacji paska na tym samym ekranie, zachowuje jego cel
powrotu. Zmiana monitora nie przywraca fokusu na starym. Pełne reguły:
[okna, Escape i kliknięcie poza panelem](panels.md).

## Przykład skrótu Hyprlanda

Dla konfiguracji Hyprlang, po zastąpieniu ścieżki własną:

```ini
bind = SUPER, B, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call bar focus
bind = SUPER, S, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call ui toggleQuickSettings
```

Odpowiednik w konfiguracji Lua Hyprlanda 0.56.2:

```lua
hl.bind("SUPER + B", hl.dsp.exec("quickshell ipc --path /ścieżka/putkin/shell.qml call bar focus"))
hl.bind("SUPER + S", hl.dsp.exec("quickshell ipc --path /ścieżka/putkin/shell.qml call ui toggleQuickSettings"))
```

To przykład konfiguracji użytkownika; implementacja nie zmienia hostowych
skrótów ani autostartu. Przy ścieżkach ze spacjami należy je zacytować.
API nie przyjmuje dowolnego polecenia powłoki ani prywatnego identyfikatora QML.

## Audio

| Funkcja | Wynik | Zachowanie |
| --- | --- | --- |
| `audio setVolume(percent: real): string` | `accepted` lub opis błędu | Żądanie poziomu 0–100%. |
| `audio changeVolume(points: real): string` | `accepted` lub opis błędu | Zmiana o punkty procentowe; argument −100…100, wynik ograniczony do 0…100. |
| `audio toggleMute(): string` | `accepted` lub opis błędu | Przełączenie wyciszenia bez zmiany poziomu. |
| `audio setMuted(muted: bool): string` | `accepted` lub opis błędu | Jawne wyciszenie/odciszenie. |
| `audio status(): string` | JSON | `available`, `output`, `volume` lub null, `muted`, `busy`, `error`. |

`accepted` potwierdza przyjęcie żądania, nie ukończenie operacji sprzętowej.
`status` pozwala odczytać wynik po ustaniu `busy`; błąd jest też w panelu.
Wybór wyjścia jest dostępny w Quick Settings. Poziom pochodzi z modelu
PipeWire, bez pollingu CLI. [Potwierdzanie stanu i reguły OSD](audio.md).

```sh
quickshell ipc --path /ścieżka/putkin/shell.qml call audio changeVolume 5
quickshell ipc --path /ścieżka/putkin/shell.qml call audio changeVolume -5
quickshell ipc --path /ścieżka/putkin/shell.qml call audio toggleMute
quickshell ipc --path /ścieżka/putkin/shell.qml call audio status
```

Przykładowe przypisania Hyprlang, bez zmiany konfiguracji sesji:

```ini
binde = , XF86AudioRaiseVolume, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call audio changeVolume 5
binde = , XF86AudioLowerVolume, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call audio changeVolume -5
bind = , XF86AudioMute, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call audio toggleMute
```

W Lua można przypisać te same polecenia do `hl.bind`/`hl.dsp.exec`, jak
w przykładzie paska powyżej. Nie dodajemy skrótów działających podczas
blokady ekranu. Przy braku wyjścia IPC zwraca opis niedostępności.

## Jasność

| Funkcja | Wynik | Zachowanie |
| --- | --- | --- |
| `brightness setPercent(percent: real): string` | `accepted` lub opis błędu | Żądanie 1–100%; 0 i wartości spoza zakresu są odrzucane. |
| `brightness change(points: real): string` | `accepted` lub opis błędu | Przyrost −100…100, wynik ograniczony do 1–100. Kolejne żądania sumują się; uwzględniany jest krok sprzętu. |
| `brightness refresh(): string` | `accepted` | Odczyt/ponowne wykrycie podświetlenia, bez OSD. |
| `brightness status(): string` | JSON | `available`, `device`, `percent` lub null, `busy`, `error`, `diagnostic`. |

`accepted` oznacza przyjęcie do kolejki. Wynik odczytaj po `busy: false`;
sukces wymaga świeżego odczytu po zapisie. Brak podświetlenia nie daje 0%.
[Wybór urządzenia, kolejka, uprawnienia i ograniczenia](brightness.md).

```sh
quickshell ipc --path /ścieżka/putkin/shell.qml call brightness change 5
quickshell ipc --path /ścieżka/putkin/shell.qml call brightness change -5
quickshell ipc --path /ścieżka/putkin/shell.qml call brightness setPercent 60
quickshell ipc --path /ścieżka/putkin/shell.qml call brightness refresh
quickshell ipc --path /ścieżka/putkin/shell.qml call brightness status
```

Przykładowe skróty Hyprlang; konfiguracja użytkownika nie jest modyfikowana:

```ini
binde = , XF86MonBrightnessUp, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call brightness change 5
binde = , XF86MonBrightnessDown, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call brightness change -5
```

Te skróty powinny zastąpić dotychczasowe komendy dla tych samych klawiszy.
Obce zmiany odświeżają się po ponownym otwarciu panelu lub `refresh`, bez
deklaracji aktualizacji live. Metoda `refresh` pozostaje punktem integracji
wznowienia sesji w etapie 10.

## Powiadomienia

| Funkcja | Wynik | Zachowanie |
| --- | --- | --- |
| `notifications focus(): string` | Nazwa monitora lub pusty napis | Otwiera centrum na skupionym monitorze, także z pustą historią; zastępuje poprzedni panel i kończy nawigację paska. |
| `notifications leave(): void` | Brak | Zamyka centrum lub nawigację toastów i zwalnia klawiaturę. Nie usuwa historii. |
| `notifications setDnd(enabled: bool): bool` | `true` po przyjęciu, `false` przy braku serwera | Włącza/wyłącza DND bez zapisu ustawień. |
| `notifications toggleDnd(): bool` | Nowy stan DND; `false` również przy braku serwera | Przełącza DND. Przełącznik znajduje się w centrum; błąd jest osobnym powiadomieniem. |

```sh
quickshell ipc --path /ścieżka/putkin/shell.qml call notifications focus
quickshell ipc --path /ścieżka/putkin/shell.qml call notifications leave
quickshell ipc --path /ścieżka/putkin/shell.qml call notifications setDnd true
quickshell ipc --path /ścieżka/putkin/shell.qml call notifications toggleDnd
```

Akcje i zamknięcie są dostępne w toastach po świadomym wejściu. Produkcyjne
IPC nie udostępnia body ani historii. `h/j/k/l`, Enter, Escape i reguły
DND/timeout/reload: [powiadomienia](notifications.md). Otwieranie panelu
lub wejście na pasek kończy nawigację powiadomień. Przykład opcjonalnego
skrótu Hyprlang, bez modyfikacji konfiguracji użytkownika:

```ini
bind = SUPER, N, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call notifications focus
```

## Sesja

| Funkcja | Wynik | Zachowanie |
| --- | --- | --- |
| `session openPower(): string` | `ok` albo błąd monitora | Otwiera menu na skupionym monitorze, z fallbackiem pierwszego ekranu. Wymaga potwierdzenia akcji kończących pracę. |
| `session lock(): string` | `accepted`, `busy` albo opis błędu | Żąda natywnej blokady w tej samej instancji Quickshell. `accepted` nie potwierdza zabezpieczenia ekranu. |
| `session status(): string` | JSON | `busy`, `phase`, `error`, `result`, capabilities oraz `lock` (locked/secure) i `idle` (ready, inhibited, sleepInhibited, dimmed, displaysOff, error). |

Nie ma IPC do potwierdzania blokady, wylogowania, restartu, wyłączenia ani
bezpośredniego suspend. Stan sukcesu blokady pochodzi z `WlSessionLock.secure`, a odświeżenie jasności z pary sygnałów login1.
[Kontrakt sesji i wymagania konfiguracji](session.md).

```sh
quickshell ipc --path /ścieżka/putkin/shell.qml call session openPower
quickshell ipc --path /ścieżka/putkin/shell.qml call session lock
quickshell ipc --path /ścieżka/putkin/shell.qml call session status
```

Opcjonalne skróty Hyprlang, bez automatycznej edycji plików:

```ini
bind = SUPER, L, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call session lock
bind = SUPER SHIFT, E, exec, quickshell ipc --path /ścieżka/putkin/shell.qml call session openPower
```

Dla lokalnego Hyprlanda 0.56.2 z Lua:

```lua
hl.bind("SUPER + L", hl.dsp.exec_cmd("quickshell ipc --path /ścieżka/putkin/shell.qml call session lock"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("quickshell ipc --path /ścieżka/putkin/shell.qml call session openPower"))
```

Zastąp ścieżkę rzeczywistą lokalizacją; ścieżki ze spacjami wymagają
cytowania zgodnego ze składnią polecenia kompozytora. Nie dodano skrótów
aktywnych podczas blokady.

## Testowanie

`scripts/test` obejmuje wywołania **rzeczywistego** `quickshell ipc` do
produkcyjnego `BarIpc`. Skrypt `scripts/test-bar-integration` uruchamia
testowy entrypoint `bar-test.qml` w prywatnych XDG/D-Bus i łączy adapter
wyłącznie z atrapą socketów Hyprlanda. Handler `probe` istnieje tylko w tym
entrypoincie i nie jest częścią produkcyjnego API. Podgląd `bar-preview.qml`
ma ten sam handler `bar` i dane demonstracyjne.

Etap 05 dodaje `scripts/test-brightness-integration`: produkcyjne
`BrightnessBackend`, `BrightnessService` i `BrightnessIpc`, rzeczywisty
Process/LazyLoader oraz jawnie wstrzyknięta atrapa executable. Odczytuje
wyłącznie prywatny plik JSON. Testowy `probe` w `brightness-test.qml`
nie należy do produkcyjnego IPC.

Etap 02 dodaje `scripts/test-panels-integration`, również wywoływany przez
`scripts/test`. Uruchamia `panels-test.qml` z prawdziwym `PanelIpc`,
`LazyLoader` i produkcyjnymi widokami w oknie offscreen. Monitory i grab
są jawnie zastąpione atrapami; `probe` nie jest częścią produkcji.
`panels-preview.qml` wystawia `bar` i `ui`, bez `probe`.

Źródło kontraktu typów i CLI: [IpcHandler 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/)
oraz lokalne `quickshell ipc --help`. Reguły numerów i przenoszenia:
[workspace](workspaces.md).

## Launcher — rozszerzenie

| Cel | Metoda | Wynik |
| --- | --- | --- |
| `launcher` | `toggle()` | `ok` lub błąd koordynatora; Super+Spacja |
| `launcher` | `open()` | Otwarcie na skupionym monitorze, `ok` lub błąd |
| `launcher` | `openClipboard()` | Otwarcie lub zmiana trybu na Schowek; `ok` lub błąd; Super+V |
| `launcher` | `openCommands()` | Otwarcie lub zmiana trybu na komendy z `:` w polu; `ok` lub błąd; Super+: |
| `launcher` | `close()` | Zamknięcie tylko aktywnego launchera |

Przykład: `quickshell ipc --path /absolutna/instalacja/shell.qml call launcher toggle`.
Nie wywołuj bez ścieżki przy kilku konfiguracjach Quickshell.
[Filtry, historia i schowek](launcher.md).

## Panel baterii — rozszerzenie

`ui openBattery` otwiera panel na skupionym monitorze; `ui toggleBattery`
przełącza widoczność, `ui closePanels` zamyka tak jak pozostałe panele.
Zwracane `ok` / błąd koordynatora oraz reguła jednego panelu pozostają wspólne.
Tryb pracy wybiera się w panelu; otwarcie nie przełącza profilu.
