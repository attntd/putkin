# Workspace i pasek — etap 01

## Widok

`shell.qml` tworzy jeden `HyprlandService`, jeden zegar `SystemClock.Minutes`
i `Variants` powiązane z `Quickshell.screens`. Każdy ekran otrzymuje własny
`BarWindow`: górne/lewe/prawe zakotwiczenie, wysokość i `exclusiveZone` 32
logiczne px, brak marginesów, nieprzezroczyste Mocha i kwadratowe rogi.
Widoki otrzymują usługę, datę i kontroler fokusu jawnie.

Lista jest globalna i posortowana numerycznie: **1–5 zawsze**, dodatkowo
każdy dodatni numer z oknami, pilnym oknem lub aktywny na którymś monitorze.
Puste, nieaktywne numery >5 znikają. Ujemne identyfikatory workspace nazwanych
i `special` nie należą do tej listy numerów.

| Stan | Oznaczenie oprócz koloru |
| --- | --- |
| Aktywny na tym monitorze | `▸`, pogrubiony numer i pełne tło Mauve |
| Widoczny na innym monitorze | `○`; tooltip podaje nazwę monitora |
| Zajęty | `·` za numerem |
| Pilny | `!` za numerem zamiast kropki, kolor błędu; tooltip nadal podaje zajętość |

Strefa ma najwyżej 480 px. Przy nadmiarze przed przewijaną listą pozostaje
stała informacja `▸numer` o aktywnym workspace. Przyciski `‹`/`›` przewijają
listę, można ją również przesuwać jak standardowy Qt `ListView`.
`h`/`l` i Home/End odsłaniają wybraną pozycję; Enter ją aktywuje.
Fokus ma wewnętrzny obrys 2 px, który nie jest obcinany przez listę.
Zmiany zajętości aktualizują role `ListModel`, zachowując obiekty przycisków.

Zegar jest przy prawym brzegu. Format daty i czasu pochodzi z locale Qt,
bez sekund; aktualizacja następuje raz na minutę. Poniżej 1500 px znika
dzień tygodnia, poniżej 600 px data pozostaje w tooltipie z pełną datą.
W obliczeniach szerokości pozostaje 40 px na przyszłe wejście statusu.
Quick Settings i ikony kolejnych usług nie są jeszcze tworzone.

## Akcja z kontekstem monitora

Kliknięcie / Enter wywołuje `activate(numer, nazwaMonitora)`:

1. Adapter sprawdza dostępność, istnienie numeru w modelu i monitora.
2. Jeśli trzeba, wysyła `focusmonitor ID` i czeka na zmianę natywnego
   `focusedMonitor`. Nie wysyła dwóch niezależnych dispatcherów bez oczekiwania.
3. Wysyła `focusworkspaceoncurrentmonitor numer`.
4. Stan aktywny zmienia dopiero zdarzenie Hyprlanda. Limit całej akcji to 2 s;
   brak potwierdzenia ustawia `lastError`. Podczas akcji nowe żądanie jest
   odrzucane, a utrata monitora/połączenia anuluje oczekiwanie.

Dla `Hyprland.usingLua` te same operacje używają
`hl.dsp.focus({ monitor = "ID" })` oraz
`hl.dsp.focus({ workspace = "numer", on_current_monitor = true })`.
Do dispatcherów trafiają wyłącznie numery z istniejących modeli.

Rozszerzenie launchera `:wN`/`:mwN` dopuszcza także nowy numer 1–10
(`0` na wejściu oznacza 10). Korzysta z tej samej kolejki i limitu akcji.
Przenoszenie okna nie zmienia skupionego monitora, używa jawnego adresu
obiektu zapamiętanego przed otwarciem launchera i czeka na jego zmianę
workspace. [Dokładna składnia i granice](launcher.md#komendy-workspace).

Workspace nie jest kopiowany. Hyprland **zamienia aktywne workspace dwóch
monitorów**, gdy wybrany numer jest widoczny na innym monitorze. Gdy istnieje
tam, ale nie jest widoczny, przenosi go na monitor wywołujący i aktywuje.
Nieistniejący numer 1–5 jest tworzony przez compositor. Reguły przypisania
workspace w konfiguracji Hyprlanda mogą wpływać na wynik; brak oczekiwanego
potwierdzenia nie jest prezentowany jako sukces.

Zweryfikowano oficjalne [dispatchery](https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/dispatchers.md)
i implementację **v0.56.2**:
[translator Hyprlang](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/legacy/DispatcherTranslator.cpp),
[dispatchery Lua](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsDispatchers.cpp),
[changeWorkspaceOnCurrentMonitor](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/shared/actions/ConfigActions.cpp).

## Stan połączenia i zasoby

`Quickshell.Hyprland` jest jedynym źródłem stanu monitorów, workspace,
okien i pilności. Nie ma `hyprctl`, procesów ani timerów odpytujących stan.
Wszystkie paski korzystają z tej samej instancji usługi.

Quickshell **0.3.1** nie udostępnia QML stanu połączenia IPC, a po zerwaniu
socketa zachowuje modele. Dlatego adapter ma **jeden dodatkowy pasywny
Socket** do `Hyprland.eventSocketPath`, wspólny dla monitorów. Konsumuje
linie bez interpretowania; służy wyłącznie wykryciu EOF/błędu. W sumie są
dwa połączenia z event socket: natywne Quickshella oraz ten strażnik.
Nie dodajemy kolejnych połączeń przy tworzeniu widoków.

Po rozłączeniu: `available = false`, `monitors = []`, aktywny numer = `-1`,
lista 1–5 bez zajętości/pilności, brak akcji i komunikat „Workspace —
niedostępne”. Nie ma automatycznego ponownego połączenia ze starymi modelami;
po restarcie kompozytora należy uruchomić Putkin ponownie w jego nowej sesji.

Źródła: [Hyprland 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/),
[HyprlandWorkspace](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandWorkspace/),
[Socket](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Socket/),
[źródło połączenia v0.3.1](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/wayland/hyprland/ipc/connection.cpp).

## Interfejs usługi

`WorkspaceService` zawiera model i sekwencję akcji, `HyprlandService`
dostarcza backend natywny. Testy Qt wstrzykują `MockHyprland` w tę samą
klasę; test protokołu uruchamia już pełny `HyprlandService`.

| Właściwość / metoda | Kontrakt |
| --- | --- |
| `available`, `monitors`, `focusedMonitorName` | Dostępność, rekordy `{ name, activeId }`, monitor skupiony |
| `workspaces` | `ListModel`: `workspaceId`, `occupied`, `urgent`, `visibleOn` |
| `activeId(name)` | Numer aktywny na monitorze; `-1` przy braku danych |
| `monitorAvailable(name)` | Istnienie monitora przy żywym połączeniu |
| `activate(id, name): bool` | Czy przyjęto żądanie; wynik potwierdzają stan i `lastError` |
| `activeWindow`, `windows`, `liveWindow(window)` | Natywne toplevele; walidacja tożsamości i adresu żywego okna |
| `executeCommand(request, action, id, window, monitor): bool` | `switch`/`move`, numer 1–10; wynik przez `commandFinished(request, error)` |
| `busy`, `lastError`, `updated()` | Oczekiwanie na compositor, ostatni błąd, sygnał synchronizacji modelu |

Wejście klawiaturą: [IPC](ipc.md). Rzeczywiste wyniki i ograniczenia:
[odbiór](evidence/01-bar.md), [status](status.md).
