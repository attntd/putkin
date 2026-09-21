# S12 — wydanie, zgodność i odbiór

2026-09-21, checkout `/home/attntd/projects/signal`. Pliki testowe i zrzuty
z tego katalogu zawierają wyłącznie dane syntetyczne. Wyniki pulpitu
zapisują tylko stan, PID, wersje i sumy; bez konta, wiadomości i QR.
Status aktywacji i telefonu: [STATUS.md](../../../signal/STATUS.md).

Poprawki układu po uwagach użytkownika, testy i kolejne wdrożenie:
[ui-layout/README.md](ui-layout/README.md).
Kolejne dopracowanie kropek, reakcji i otwierania miniatur:
[ui-refinement/README.md](ui-refinement/README.md).

## Pakiet i instalator

- `package.json`, `package-rebuilt.json`: sprawdzenie oraz ponowne zbudowanie
  pakietu z pobranych oficjalnych, przypiętych archiwów. SHA-256 całego
  drzewa CLI/JRE: `bcfcebef74761e3c69690d0be6836303c7d7edbd1675395361da765f266f116f`.
- `dry-run.json`, `staging*.log`: prywatny cel, kompletne wydania bez
  `tests/preview`, konta i fake CLI. Końcowy pakiet: 357 plików źródeł
  runtime i 348 plików CLI/JRE. Dane poza wydaniami.
- `staging-rollback.json`: dry-run, powrót do zgodnego poprzedniego pakietu
  i powrót do nowego; każde wywołanie kod 0. Każdy hash syntetycznej bazy
  i pliku protokołu pozostał bez zmian.
- `install-tests.log`: 17 PASS, w tym osiem aktualizacji, pięć buildów,
  zachowanie plików użytkownika, prywatne XDG/D-Bus, awaria publikacji
  i gotowość serwera powiadomień. Bez aktywacji hosta.
- `release-tests.log`: 11 PASS — SQLite v1→7, WAL, zgodny rollback,
  brak wskrzeszenia usunięć/wygaśnięć, blokada downgrade’u/niezgodnego CLI,
  zajęty receiver, odmowa niezgodnego fallbacku po migracji, symlinki,
  uszkodzenie, pełne sumy i prawa wykonania narzędzi.
- `installed-runtime-final.json`: produkcyjny bridge **z gotowego wydania**,
  prawdziwe CLI/JRE, puste konto, sieć wyłączona. Idle bez konfiguracji,
  włączenie, listAccounts, restart, wyłączenie, prywatny kontrakt danych,
  brak pozostawionego bridge/JVM. Natywne IPC sprawdza redakcję statusu,
  parowanie/ustawienia i odmowę przy blokadzie lub istniejącym powiązaniu.
- `cli-api.json`: 16 kontroli rzeczywistego przypiętego API, bez konta/sieci.
  `jvm-process.json`: cztery próby EOF/TERM/KILL i dziedziczenia lease,
  bez pozostawionych PID.

Polecenia pakowania, instalacji i powrotu:
[OPERATIONS.md](../../../signal/OPERATIONS.md). Testy:
[TESTING.md](../../../signal/TESTING.md).

## Scalenie i regresja

`main-integration.json` dokumentuje trójstronne połączenie źródeł z
`main` 311edb8, którego funkcje były już na aktywnym pulpicie. Zachowano
uwierzytelnianie, zmiany launchera, komendy sesji, rozwijane karty oraz
wspólne przewijanie powiadomień. Nie zmieniono Git index ani `main`.

- `source-sha256.json`: dokładne źródła runtime końcowego pakietu.
- `check-final.log`: 272 QML, 0 błędów.
- `notifications-qt.log`: 14 PASS; `keyboard-qt.log`: 36 PASS.
- `full-test.log`: pełny przebieg Python → Qt → integracje; końcowy wynik
  i kod wyjścia zapisuje `run-summary.json` po zakończeniu.
- `wayland/report.json`: PASS, rzeczywisty prywatny Hyprland/GPU, keyboard,
  Unicode/Shift+Enter/Escape, aktywne quick reply, dwa akcenty
  preview/cancel/save, powrót fokusu, małe/duże okno, skala 1,5,
  drugi monitor/hotplug, redakcja po lock i hard reload. Konta/sprzęt
  są syntetyczne. Zrzuty `reply-saved.png` i `messages-small.png`
  obejrzane; czytelny edytor i brak obcięcia composera. Sprzątanie: brak PID.

## Zachowane próby diagnostyczne

Pierwszy przebieg w ograniczonym sandboxie (`signal-tests.log`,
`install-initial.log`) nie zaliczył testów wymagających prywatnego D-Bus
lub izolacji workerów; zachowano błędy. Rzeczywiste późniejsze próby mają
własne logi i kody wyjścia. Poprawiono też liczenie plików w dry-run
przywracanego małego buildu oraz klasyfikację błędu uszkodzonej bazy.

`merge-check.log` wykrył podwójne przypisanie po scaleniu karty; usunięte.
`check-merged.log` wykrył dwa stare parametry fixture po przeniesieniu
przewijania centrum; testowe okna mają właściwy ScrollView.
`ipc-qt.log` dokumentuje brak Quickshell.Io w qmltestrunnerze; test IPC
przeniesiono do prawdziwego Quickshella w `test-signal-release`.
`check.log` wykrył statyczne typowanie metod IPC w tej fixture;
`ipc-check.log` i końcowa bramka przechodzą po poprawce.

Oczekiwane błędy symulowanych odłączeń, brakującego executable czy odmowy
zapisu w runnerach sprzętu nie są ukrywane; wynik ustalają ich asercje.
Żadna z prób lokalnych nie zalicza telefonu, innego rozmówcy ani grupy.


## Aktywacja pulpitu i pierwszy odbiór telefonu

`activation.log`: aktywacja `20260921-090336-8f92f3b0b020`. `live-shell.json`:
otwarcie/zamknięcie Wiadomości zachowuje bridge; stop kończy proces, start
przywraca w tym samym cgroup UWSM, jeden shell, zachowane ustawienia i
Caffeinate `presentation`. Pierwsza próba harnessu (`live-shell-before-lua.log`)
używała starego dispatchera zamknięcia okna; poprawiona na bieżące Lua API
Hyprlanda. Nie wymagało to zmiany produktu.

Użytkownik potwierdził skan QR. Konto ma `linked`, a wysłana przez użytkownika
wiadomość ma lokalny stan `sent`. Następnie zgłoszono utratę połączenia;
redagowane IPC potwierdziło `invalid_event`. Nie zapisano treści, adresów,
identyfikatora konta ani zdarzenia protokołu.

Audyt [JsonTypingMessage 0.14.8](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonTypingMessage.java)
i `MessageEnvelope.Typing.Type` wykazał błąd parsera: rzeczywiste wartości to
`STARTED`/`STOPPED`; wcześniejsza syntetyczna fixture miała `START`/`STOP`.
Parser i fixture poprawione. `SignalEventContractTest.java` sprawdza wartości
przez wywołanie prawdziwego serializatora w przypiętych jarach; nie odtwarza
własnego modelu protokołu. `event-cli-contract.log`: PASS w izolacji bez
sieci/konta, wraz z wcześniejszymi kontrolami mediów i retencji.

`event-fix-tests.log`: 71 PASS dla historii, receipts, interakcji i wydania;
nowa kontrola obu akcji pisania oraz prywatności diagnostyki także PASS.
`event-fix-check.log`: kontrola QML. `event-fix-activation.log`: instalacja
poprawki. Bezpieczny `eventErrorLocation` wskazuje wyłącznie stałą lokalizację
kodu lub `account_binding`, bez treści wyjątku, wartości ani kluczy upstream.
Błąd `invalid_event` ma własny komunikat UI. Wynik osobnego odbioru live
po poprawce opisano poniżej; źródłowy wadliwy event nie został zachowany.


`linked-update.json`: poprawiony build `20260921-091350-39f9ddda75b4`
wrócił do `ready/linked` bez ponownego QR. `source-event-fix-sha256.json`
zawiera źródła tego buildu; wszystkie porównane z aktywnym wydaniem.
`event-fix-installed.json`: PASS gotowego poprawionego pakietu, rzeczywisty
CLI/JRE i natywne IPC w izolacji bez konta/sieci; brak pozostawionych procesów.
`event-regressions.log`: dwa nowe przypadki regresji PASS.

## Potwierdzony odbiór live

`note-text.json`: własna Notatka dotarła z telefonu, następnie agent wysłał
jawnie testowy tekst z natywnego composera do tej samej własnej rozmowy.
Przed wysłaniem sprawdzono `kind=note`, cel równy własnemu ACI oraz dokładny
szkic w tej rozmowie. Outbox ma `sent`, usługa pozostała `ready/linked` bez błędu.
Użytkownik potwierdził widoczność wiadomości po obu stronach.

`user-acceptance.json`: użytkownik potwierdził również reakcje i załączniki
w rozmowie z drugą osobą. To potwierdzenie funkcji live; nie podano wszystkich
formatów mediów/kierunków, więc nie zalicza całej macierzy audio/wideo/portal.
Osobnego syntetycznego pliku do Notatki nie powtarzano po tym potwierdzeniu.
Agent nie wysyłał prób do kontaktów ani grup. Nie zapisano prywatnych treści,
adresów, QR ani identyfikatorów rozmowy.

Po aktualizacji odebrano także nowe wiadomości przychodzące i własny sent sync.
Użytkownik potwierdził następnie edycję widoczną na obu urządzeniach oraz
oba działania powiadomienia: otwarcie właściwej rozmowy i odpowiedź bez
otwierania okna. Potwierdził także potwierdzenia odczytu przez obserwowane
zmiany statusu wiadomości, usuwanie wiadomości oraz rozmowy grupowe.
Te wyniki pochodzą z relacji użytkownika, bez przechowywania danych rozmów.
**Podstawowy odbiór live PASS.** Szczegółowe role/zaproszenia/uprawnienia
grupowe, warianty prywatności receipts/read sync, wszystkie tryby usuwania,
znikanie, osobna zmiana akcentów w live reply i pozostała fizyczna macierz
nadal nie są odebrane live.

## Commit i scalenie do main

Integracja S00–S12 oraz oba dopracowania UI: commit `83a191a`.
`merge-main.json` dokumentuje zachowanie wcześniejszego main, ponowne
użycie 13 przetestowanych rozwiązań konfliktów oraz identyczność wszystkich
357 plików runtime z aktywnym wydaniem. `merge-main-check.log`: 272 QML,
0 błędów. Zgodnie z AGENTS.md włączono istniejące instrukcje i 27 promptów
do wersjonowania, bez zmian ich treści. Aktywne wydanie bez przełączenia.
