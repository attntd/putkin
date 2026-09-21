# S11 — odporność, odbiór i wydajność, 2026-09-21

Checkout `/home/attntd/projects/signal`, SQLite v7, IPC v1,
signal-cli 0.14.8 JVM + `putkin-retention-2`. Dane wyłącznie syntetyczne.
Nie aktywowano shella, nie sparowano konta, nie wysłano do kontaktów.
[Macierz wymagań i granice](../../../signal/ACCEPTANCE.md).
Oba rzeczywiste jary mają [potwierdzone hashe](cli-policy-pin.json);
nie przebudowywano ani nie zmieniano pinu z S09.

## Polecenia i wyniki

Polecenia wykonano z katalogu repo. Prywatne XDG/D-Bus, socketpair i GPU
wymagały wyjścia poza ograniczenie sandboxa agenta; własna izolacja runnerów
pozostała włączona. Wayland i rzeczywisty CLI mają prywatne namespace
PID/network/mount. Testy offscreen korzystają z syntetycznego CLI.

| Polecenie | Wynik / dowód |
| --- | --- |
| `python3 scripts/check` | **PASS**, 259 plików QML, 0 błędów; [log](check.log) |
| `python3 scripts/test` | **PASS**, kod 0: 202 Python, 667 Qt, 23 runnery (9 Signal); [pełny log](full-test.log), [podsumowanie](run-summary.json) |
| `python3 -m unittest discover -s tests -p test_signal_reliability.py -v` | **5 PASS**, potem ponownie w pełnym zestawie; [log](reliability-targeted.log) |
| `python3 scripts/test-icons --file tst_audio.qml --log docs/evidence/signal/S11/audio-targeted.log` | **22 PASS**, oczekiwanie na fade; [log](audio-targeted.log) |
| `python3 scripts/test-signal-acceptance --output artifacts/signal-s11/acceptance` | **PASS**, 10 000 wiadomości, 60 s, 20 cykli; [raport i próbki](acceptance/report.json), [log uruchomienia](acceptance-run.log), [runtime](acceptance/runtime.log) |
| `python3 scripts/test-wayland --nested --signal --output artifacts/signal-s11/wayland` | **PASS**, po końcowej poprawce historii; [raport](wayland/report.json), [cleanup](wayland/cleanup.json), [log](wayland-run.log) |
| `python3 scripts/test-signal-media-input` | **PASS**, prawdziwy drag/drop, FileDialog i IME obu edytorów; [log](input-targeted.log) |
| `python3 scripts/test-signal-receipts --output docs/evidence/signal/S11/receipts-final.json` | **PASS**, sześć grup kontroli po poprawce kolejności fokusu; [raport](receipts-final.json), [runtime](receipts-final.log), [zrzut](receipts-final.png) |
| `python3 scripts/test-panels-integration --output docs/evidence/signal/S11/panels-final.json` | **PASS**, 20 cykli i 0 żywych powierzchni; [raport](panels-final.json), [log](panels-final-run.log) |
| `python3 scripts/test-signal-cli --executable artifacts/signal-s09/cli-final/bin/signal-cli --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre --output docs/evidence/signal/S11/cli-api.json` | **PASS**, 16 kontroli wersji/help/RPC bez konta; [raport](cli-api.json), [log](cli-api.log) |
| `python3 scripts/test-signal-media-cli --distribution artifacts/signal-s09/cli-final --jdk artifacts/signal-s07/jdk-25.0.4.1+1` | **PASS**, rzeczywiste klasy pobierania/cache/view-once/retencji/resend log; [log](cli-policy.log) |
| `python3 scripts/test-signal-process --executable artifacts/signal-s09/cli-final/bin/signal-cli --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre --idle --output docs/evidence/signal/S11/jvm-process.json` | **PASS**, SIGTERM/SIGKILL/spawn/exec-gate, 60 s spoczynku; [raport](jvm-process.json), [log](jvm-process.log) |

Ostrzeżenie Java o native access pochodzi z SQLite JDBC przy teście klas,
nie z błędu polityki ani QML. Kompilator testu wejścia Qt wypisuje notę
z nagłówka GCC; sam test kończy się powodzeniem.
Pełna regresja zawiera oczekiwane komunikaty z wstrzykiwania awarii:
zerwane prywatne sockety Hyprlanda/PipeWire, brak praw do fixture ustawień
i brak syntetycznego brightnessctl. Runner sprawdza odpowiednie wyjątki;
tych komunikatów nie przedstawiamy jako brak jakichkolwiek ostrzeżeń.

## Wykryte problemy i poprawki

- **Odłączenie ekranu:** synchronizowanie powiadomień podczas zerowania
  QScreen odwoływało się do usuwanego obiektu. NotificationService odracza
  reakcję na zmianę geometrii przez `Qt.callLater`, aż lista ekranów będzie
  aktualna. Końcowy test usuwa wyjście z aktywnym oknem: bez ostrzeżeń QML,
  ze szkicem i działającym ekranem zastępczym.
- **Zmiana rozmowy podczas inkubacji widoku:** Qt zgłaszało
  `DelegateModel::cancel: index out range 0 0` przy create grupy tuż po
  otwarciu okna. MessageHistory odpina model przed resetem i przypina go po
  zakończeniu zmiany. Paginacja i zwykłe aktualizacje nadal zachowują kotwicę.
- **Niestabilny Audio z S10:** test klikał dropdown przed zakończeniem
  prezentacji. Oczekuje teraz na opacity 1; zachowanie produkcji bez zmiany.
- **Fixture wejścia mediów:** uzupełniono adapter o kontrakt composera z S08,
  zachowując rzeczywisty drop/dialog. Dodano QInputMethodEvent preedit/commit
  do composera i reply: Return podczas preedit nie wysyła, Shift+Enter
  tworzy nową linię, zwykły Return po commit wysyła raz.
- **Wyścig próby odczytu S06:** pierwszy pełny przebieg miał 202/667 PASS
  i jeden nieudany runner receipts. Test przenosił fokus do innego okna
  przed asynchronicznym mapowaniem okna rozmowy; późniejsze mapowanie
  aktywowało rozmowę, więc prawidłowo następował widoczny odczyt.
  Runner czeka teraz na rzeczywistą aktywację nowego/odminimalizowanego
  QWindow, następnie przykrywa go przed debounce i sprawdza brak odczytu.
  Zachowano wszystkie asercje liczby/zakresu receipts. Dodano diagnostykę
  geometrii bez treści. [Pierwszy pełny przebieg](full-test-before-receipts.log)
  pozostaje oznaczony jako nieudany; końcowy przebieg jest osobny.
- **Odroczone niszczenie paneli:** drugi pełny przebieg ujawnił snapshot
  `loaded=false, created=21, destroyed=20` tuż przed zdarzeniem zniszczenia.
  Runner paneli czeka teraz jednocześnie na nieaktywny loader i równość
  liczników, tak jak istniejące runnery audio/jasności/walidacji. Limit
  oczekiwania pozostaje 6 s; pozostawiony obiekt nadal powoduje FAIL.
  [Drugi przebieg](full-test-before-panels.log) zachowano osobno.
  scripts/test raportuje teraz kod zakończenia każdego z 23 runnerów,
  aby nie ukrywać niepowodzenia pomiędzy kolejnymi JSON-ami.
- Dodano brakujące prawa wykonywania helperów ze shebang, używanych
  przez polecenia repo; [dokładna lista](executable-modes.json). Nie zmieniano instalacji.

Wstępne próby nowego runnera poprawiały błędne założenia fixture:
powiadomienia są scalane per rozmowa, istnieje proces notification watcher,
redakcja może zmniejszyć stronę 50 do 49 w UI, a media ID nie jest nazwą
pliku. Zrzuty muszą czekać na fade i właściwy monitor po reloadzie.
[Próba przed poprawką resetu](acceptance-before-reset.log) nie jest PASS.
Krótkie próby ze 120 rekordami służyły diagnozie i nie zaliczają 10 000.

## Natywne UI — przegląd rzeczywistych zrzutów

Końcowe osiem PNG obejrzano po ostatniej zmianie produkcyjnej. Zrzuty
pochodzą z prywatnych wyjść HEADLESS kompozytora Hyprland 0.56.2, z GPU;
nie są makietą ani obrazem wygenerowanym. Warstwa konta/lock/monitor service
pozostaje testowa. Runner wybiera także rzeczywisty fokus kompozytora.

- [Podgląd](wayland/reply-preview.png) i [zapis](wayland/reply-saved.png):
  różne pary akcentów, Unicode, dosłowne `<b>`, dwa wiersze szkicu,
  kwadratowe ramki i widoczna akcja Wyślij. Anulowanie zweryfikowane stanem.
- [Duże](wayland/messages-large.png) i [małe](wayland/messages-small.png)
  okno 420×520: composer, akcje i nawigacja mieszczą się w powierzchni;
  historia ma własny przewijany zakres.
- [Skala 1,5](wayland/messages-scale-1.5.png): okno ponownie otwarto po
  zmianie skali, cały klient mieści się na logicznym wyjściu. To nie jest
  dowód automatycznego przesuwania istniejącego pływającego okna przy zmianie
  konfiguracji fizycznego monitora.
- [Drugi monitor](wayland/messages-second-output.png): właściwy klient
  i zachowany szkic, następnie usunięcie wyjścia potwierdzone automatycznie.
- [Blokada](wayland/locked-redacted.png): brak okna wiadomości i prywatnej
  treści na powierzchni; tekst historii powiadomień jest zredagowany.
  Tło to syntetyczne inne okno, a nie ekran blokady użytkownika.
- [Po reloadzie](wayland/messages-after-reload.png): odtworzony szkic,
  historia i zapisane akcenty. Widoczny marker lock jest wyłącznie
  syntetyczną wiadomością pokazaną już po odblokowaniu.

Rzeczywiste klawisze dostarcza wtype. Hjkl pozostają tekstem, Shift+Enter
nie wysyła, Escape najpierw zwija reply, następny zwraca fokus do innego
okna. IME sprawdzono osobno rzeczywistymi zdarzeniami Qt; fizyczny silnik
IME, portal, schowek i odtwarzanie przez sprzęt pozostają S12.
Dodatkowo obejrzano offscreen [historię mediów](acceptance/conversation-media.png)
i [szczegóły grupy](acceptance/group-details.png): poprawne akcje plików,
status wysłania, role i pola administracyjne.
Obejrzano też [raport odczytu](receipts-final.png): rzeczywisty wiersz
„Wyświetlono” z ikoną i zachowaną liczbą nieprzeczytanych poza viewportem.
Runner używa aktualnych [dispatchers Lua Hyprlanda](https://wiki.hypr.land/configuring/core/dispatchers/).

## Pomiary

[Końcowy raport](acceptance/report.json): **10 000 wiadomości**, 200 stron
bez duplikatów; mediana **10,04 ms**, p95 **13,11 ms**, max **15,82 ms**.
Seed i wszystkie strony: 61,925 s. Plan używa indeksu `messages_page`.
E2E dodaje obraz, wideo, audio i plik, quick reply, reakcję/edycję, grupę,
odwrotne receipts i zdarzenia, delete/expiry oraz hard reload bez replay.

Idle: **60,00016 s**, 61 próbek; QML CPU **0,05 s**, RSS
**159 508 → 133 352 KiB**; bridge CPU **0,00 s**, RSS **37 224 KiB**;
obserwator powiadomień **0,00 s / 27 584 KiB**, atrapa CLI
**0,00 s / 22 960 KiB**. Stale cztery procesy i jeden receiver.
Timery kontrolowane przez aplikację: QML 0, typing 0, najbliższa retencja 1;
RPC/late result/output bytes 0, workery mediów/katalogu nieaktywne.

**20/20** otwarć/zamknięć niszczy swoje okno. UI ma **49/99** rekordów
(jeden odfiltrowany po redakcji) i **8/8** delegatów. Mediana pełnego cyklu
z drugą stroną i fade **1452,25 ms** (min 1315,64 / max 1566,91).
RSS po cyklach **168 304–173 088 KiB**, różnica median 6–10 / 16–20
**2352 KiB** przy budżecie 16 384 KiB. Widać zwalnianie i ponowne użycie
pamięci, nie nieprzerwany przyrost po każdym oknie. To ograniczony test
regresji, nie dowód braku dowolnego długotrwałego wycieku.
Dwie subskrypcje w całym E2E (reload), tylko jedna naraz;
`qmlErrors=[]`, `remainingOwnedProcesses=[]`.

Próbki CPU to przyrost `/proc` w sekundach procesu, RSS w KiB; nie jest to
benchmark na wyłącznym, bezczynnym hoście. Inne testy mogły działać równolegle.

**Rzeczywisty JVM:** 61 próbek przez **60,00016 s**, CPU **0,01 s**,
RSS **158 952 → 158 952 KiB** (155,23 MiB), jedna subskrypcja.
Po każdej z czterech prób lifecycle brak pozostałego CLI.
Puste konto i wyłączona sieć: to koszt procesu JVM, nie pełnej synchronizacji
konta. Nie sumujemy go z kosztami atrapy jako rzekomego pomiaru live.

## Granice i następny krok

Brak telefonu, wskazanego rozmówcy/grupy i fizycznego suspend/IME/DPMS.
ACK CLI nie zależy od COMMIT bridge, nie ma dowolnego replay ani importu
wcześniejszej historii. Unknown nie jest sukcesem i nie powoduje resend.
View-once niedostępny, resend log wyłączony, delete-for-me lokalne;
retencja po wyłączeniu procesu jest wykonywana przed historią na starcie.
Brak obietnicy forensic erase i usunięcia cudzych eksportów.

S12 ma spakować oba przypięte jary, przygotować instalację/rollback i
wykonać [minimalny scenariusz live](../../../signal/ACCEPTANCE.md#minimalny-odbiór-live-s12--jeszcze-niewykonany).
S11 nie uruchamia aktywacji. Nie wykonano commita.

## Prywatność dowodów i wynik końcowy

[Skan zapisanych logów/JSON](privacy.json): brak URI parowania i sześciu
kontrolowanych kategorii wycieku (URI oraz znaczniki treści/błędów).
To kontrola konkretnych wzorców wraz z audytem źródeł danych, nie uniwersalny
wykrywacz sekretów. Produkcyjne runtime nie wypisują body. Historyczny
błąd fixture receipts zawiera jedynie sztuczną wiadomość; nowy runner
ogranicza diagnostykę do stanu i geometrii. PNG celowo pokazują syntetyczny UI.

Końcowy pełny zestaw zakończył się **kodem 0**: 202 Python, 667 Qt,
23 runnery integracyjne (w tym 9 Signal), bez FAIL/SKIP w Qt.
Pierwszy pełny przebieg miał kod 1 z wyścigiem fixture receipts, drugi
z wyścigiem odroczonej destrukcji panelu. Zachowano oba nieudane wyniki.
Celowane poprawki i trzeci pełny zestaw PASS. Lokalny kandydat S11 gotowy; S12 nie rozpoczęto.
