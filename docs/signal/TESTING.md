# Signal — testy i izolacja

Kontrakt S00, 2026-09-20. **Syntetyczny transport nie dowodzi synchronizacji
z telefonem.** Wyniki wykonanych prób: [STATUS.md](STATUS.md).

## S12 — pakiet, zgodność i przełączenie

```sh
scripts/check
python3 -B -m unittest discover -s tests -p test_signal_release.py -v
python3 -B -m unittest discover -s tests -p test_install.py -v
scripts/install --dry-run --destination artifacts/signal-s12/destination
scripts/install --destination artifacts/signal-s12/destination
scripts/test-signal-release --package artifacts/signal-s12/destination/data/putkin/current --output docs/evidence/signal/S12/installed-runtime-final.json
scripts/test
scripts/test-wayland --nested --signal --output docs/evidence/signal/S12/wayland
```

`test_signal_release.py`: 11 prób rzeczywistych prywatnych plików/SQLite:
migracja v1→7, zgodny rollback z zachowaniem kluczy/szkicu/tombstones,
wygaśnięcie przed publikacją po restarcie, nowszy schemat zapisany tylko
w WAL, odmowa innego CLI/retencji, zajęty lease, symlinki/uszkodzenie,
sumy wszystkich plików runtime i prawa wykonania, izolacja zmiennych JVM.
Transakcja instalatora odmawia downgrade’u przed zmianą wskaźnika oraz
ponownego uruchomienia niezgodnego fallbacku po migracji nowego procesu.
Te dwie próby używają małych syntetycznych manifestów bez binarek;
integralność rzeczywistego pakietu jest osobną bramką.

`test-signal-release` uruchamia produkcyjny bridge z **gotowego wydania**
i dołączone CLI/JRE w bubblewrap: bez sieci, domu i sesji hosta. Sprawdza
idle bez konfiguracji, włączenie z pustym kontem, brak automatycznego QR,
restart, wyłączenie i brak osieroconych procesów. Następnie prawdziwy
Quickshell na prywatnym D-Bus wykonuje `signal-release-test.qml`: brak
prywatnych danych w statusie, otwarcie sekcji/parowanie, ponowne wejście,
odmowa przy blokadzie i już połączonym koncie. Sam qmltestrunner nie
udostępnia wtyczki Quickshell.Io; ten test wymaga natywnego Quickshella.

Próby instalatora w `test_install.py` obejmują osiem aktualizacji/limit
pięciu buildów, prywatny cel, dry-run i rollback. S12 wykonuje też powrót
między rzeczywistymi pakietami w prywatnym celu, porównując każdy hash
syntetycznej historii i stanu protokołu. Kontrole lokalne nie zaliczają
skanu telefonu, serwera, receipts innego rozmówcy ani ról grupowych.

Scalenie z aktualnym main wymaga pełnej regresji obu zestawów. Wyniki,
naprawione próby i zakres aktywacji: [S12](../evidence/signal/S12/README.md).
Nie zapisuj QR ani treści realnych rozmów do dowodów.

Po zmianach układu S12 celowane zestawy QML obejmują messages, retention,
interactions, media, receipts i groups. Retention otwiera kontrolkę czasu
przez Szczegóły, a test akcentów grupy używa fokusu pola zamiast ramki
okna. Natywny runner zawiera syntetyczne własne dymki z reakcją i obrazem,
zrzuty pustego i wielowierszowego composera oraz Szczegółów.
[Wyniki i zrzuty układu](../evidence/signal/S12/ui-layout/README.md).
Kolejna próba mediów otwiera obraz i dokument kliknięciem/Enter, sprawdza
metadane, właściwy identyfikator otwieranego pliku i powrót fokusu.
Runner Waylanda klika miniaturę przez prywatny virtual-pointer i pokazuje
reakcję obok statusu edycji/odczytu.
[Wyniki dopracowania](../evidence/signal/S12/ui-refinement/README.md).

## S11 — pełny odbiór i wydajność

```sh
python3 scripts/check
python3 scripts/test
python3 scripts/test-signal-acceptance --output artifacts/signal-s11/acceptance
python3 scripts/test-wayland --nested --signal --output artifacts/signal-s11/wayland
python3 scripts/test-signal-media-input
python3 scripts/test-signal-cli --executable artifacts/signal-s09/cli-final/bin/signal-cli --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre --output artifacts/signal-s11/cli-api.json
python3 scripts/test-signal-media-cli --distribution artifacts/signal-s09/cli-final --jdk artifacts/signal-s07/jdk-25.0.4.1+1
python3 scripts/test-signal-process --executable artifacts/signal-s09/cli-final/bin/signal-cli --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre --idle --output artifacts/signal-s11/jvm-process.json
```

`test_signal_reliability.py` jest częścią domyślnego unittest w scripts/test:
zmieniona tożsamość bez auto-trust/retry, prywatny błąd RPC, prawa plików,
800 odwrotnie uporządkowanych/zdublowanych eventów, revoke po śmierci CLI,
4 MiB limit outputu przy nieczytającym odbiorcy. Poprzednie testy obejmują
pełny dysk, uszkodzoną bazę, wyższy schemat, awarie/unknown i retencję.

`test-signal-acceptance` używa produkcyjnych QML/SQLite/bridge oraz atrapy
CLI. Najpierw zapisuje 10 000 wiadomości przez Store.receive i sprawdza
200 stron bez duplikatów, plan indeksu oraz czas stron. Kolejność sprawdza
dodatkowo test 800 odwrotnych/zdublowanych eventów. Potem
wykonuje połączony tekst/media → toast → reply → historia → reakcja → edycja
→ receipts → grupa → usunięcie/wygaśnięcie → hard reload. Osobna ścieżka
sent sync nie generuje toasta; zmiany mogą poprzedzać oryginał.

Pomiar idle ma 61 próbek `/proc` na przestrzeni co najmniej 60 s, bez IPC
w trakcie. Raport rozróżnia QML, bridge, syntetyczny CLI i istniejący
obserwator powiadomień. Następnie 20 cykli otwarcia/dwóch stron/zamknięcia
sprawdza zwolnienie każdego okna, stałą liczbę procesów/subskrypcji i
mediany RSS cykli 6–10 vs 16–20 (budżet regresji 16 MiB, nie obietnica
stałego zużycia pamięci). Pełne próbki są zachowane. JVM jest mierzony
oddzielnie: prawdziwy proces, puste konto, subskrypcja bez sieci, 60 s.

`--messages 120 --scenario-only` służy szybkiemu debugowaniu scenariusza;
ten wynik **nie zalicza** obowiązkowego obciążenia i pomiaru S11.

`test-wayland --signal` korzysta z istniejącej izolacji bubblewrap,
prywatnego Hyprlanda i HEADLESS. Sprawdza rzeczywiste klawisze, pasywny
toast, edycję reply, fokus, oba akcenty z FileView, małe/duże okno,
skalę 1,5, drugi monitor, hotplug, lock i hard reload. Monitor/fokus
kompozytora wybiera runner; konto, sprzęt i blokada są syntetyczne.
Zrzuty oglądamy po pełnym fade i sprawdzamy monitor rzeczywistego klienta.
`test-signal-media-input` poza drop/dialog obejmuje rzeczywiste
QInputMethodEvent preedit/commit w composerze i reply, nie sam boolean.
Silnik IME użytkownika i portal/schowek fizycznej sesji pozostają S12.

Runner receipts musi zaczekać na mapowanie/aktywację asynchronicznego
QWindow, zanim aktywuje przykrywające okno. Wcześniejsza prośba o fokus
może zostać unieważniona przez późniejsze mapowanie. Test nadal wymaga
zera receipts poza aktywnym oknem i dokładnie jednego batcha dla widocznych
wiadomości; geometria/opacity są diagnostyką bez treści rozmowy.

[Macierz, ograniczenia i minimalny live](ACCEPTANCE.md),
[polecenia, wyniki i zrzuty](../evidence/signal/S11/README.md).

## S10 — katalog, grupy i akceptacja

```sh
scripts/check
python3 -m unittest discover -s tests -p test_signal_groups.py -v
python3 -m unittest discover -s tests -p 'test_*.py' -v
scripts/test-signal-groups --output artifacts/signal-s10/groups-native.json
```

`tests/test_signal_groups.py` testuje prawdziwy bridge, SQLite i kontrolowaną
atrapę stdin/stdout: create/partial, deduplikację operationId, crash i restart,
anulowanie z late result, ręczną rekoncyliację, brak praw/niepełny snapshot,
role i ostatniego admina, join/requesting/invitation, message request bez read/
typing/reply przed akceptacją, block/unblock, profile/numery/avatar bez zmiany
ID, mute/hidden, stany left/terminated/blocked oraz pełną semantykę wiadomości
w grupie (media, cytaty, wzmianki UTF-16, edycje, reakcje, receipts, delete,
expiry). Brak fałszywego tekstowego send do testowania adresu.

`tst_signal_groups.qml` obejmuje klawiaturę, hjkl w nazwie, wybór członków,
unknown bez przycisku ponowienia, jawny cel i fokus Anuluj, utratę praw,
akceptację, lokalne preferencje, profile/odświeżanie bez zmiany wyboru,
oba akcenty i wąski ekran. Qt uruchamiany przez `isolated_environment`,
prywatny dbus-run-session i qmltestrunner, zgodnie z głównym kontraktem testów.

`scripts/test-signal-groups` uruchamia produkcyjne okno/adapter, bridge,
SQLite i jeden prywatny NotificationServer. Tworzy grupę przez API, sprawdza
otwarcie faktycznego ID, szczegóły i screenshot, zmianę nazwy bez zmiany
historii, quick reply przy zamkniętym oknie z `groupId` (bez recipient autora),
wyciszenie i telefoniczną utratę członkostwa odtworzoną syntetycznym sync.
Kontroluje nieaktywny composer/starą kartę, logi QML i koniec własnych procesów.
`signal-groups-test.qml` nie jest entrypointem produkcji.

Regresja S04 po hard reload czeka również na historię i wyrenderowany kadr,
zamiast kończyć proces po samym odtworzeniu szkicu, w trakcie inkubacji widoku.
Regresja S06 zmienia oczekiwanie dla nierozwiązanego numeru: bez akceptacji
pozostaje unread; nie jest to lokalny odczyt nieznanego nadawcy.
Fixtures wcześniejszych etapów jawnie określają zaakceptowane kontakty.

Avatar i produkcyjne sprawdzenie CLI wymagają budzenia wątków asyncio.
Sandbox agenta blokuje ten mechanizm; tak jak S07–S09 uruchamiamy te same
testy poza tym ograniczeniem, zachowując syntetyczne konta i prywatne XDG.
Nie zmieniamy testów na pozorne pominięcie pracy dekodera.

Wyniki: [S10](../evidence/signal/S10/README.md). Rzeczywisty telefon, akceptacja
zaproszenia przez drugiego rozmówcę, live role/link/block/sync i avatar
pozostają w S12. JSON fixtures nie są dowodem sukcesu tych prób.

## S09 — usuwanie, wygaśnięcie i wznowienie

Testy tylko na syntetycznych wiadomościach i prywatnych XDG/D-Bus.

```sh
scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 -B scripts/test-icons --file tst_signal_retention.qml --log artifacts/signal-s09/ui.log
python3 -B scripts/test-icons --all-qml --timeout 600 --log artifacts/signal-s09/qml.log
python3 -B scripts/test-signal-retention --output artifacts/signal-s09/native.json
python3 scripts/test-signal-media-cli --distribution artifacts/signal-s09/cli-final --jdk artifacts/signal-s07/jdk-25.0.4.1+1
```

`test_signal_retention.py`: kontrolowany zegar, wcześniejszy read sync,
start od odczytu/wysłania, actual timer wobec zmiany preflight, partial,
24 h limit i autorstwo, delete przed celem/odwrotne edycje/replay,
cytaty w wersjach i kompozycji, WAL, błędy GC i restart, współdzielone pliki,
spóźniony worker i przerwanie rzeczywistego własnego dekodera.
Rzeczywisty timerfd sprawdzany na najbliższym terminie; ECANCELED i
suspend/resume symulowane przez kontrolowany zegar/zdarzenie, bez zmiany
zegara lub usypiania hosta. Migracje v1/v2 → v6 sprawdzają stare read markers.

QtTest: rozdzielone zakresy lokalny/wszyscy, klawiatura, oba akcenty,
ustawienie czasu, zajęty edytor, cytat, podgląd obrazu i spóźnione odczyty.
Powiadomienia: dokładny messageId, zachowana nowsza karta, brak odtworzenia
centrum po spóźnionym fetch. Runner natywny łączy rzeczywisty Qt/SQLite/pipe,
sprawdza RPC remoteDelete/updateContact, widoczny odczyt, zamknięte okno,
wyłączenie shella przez deadline, startup i brak osieroconych procesów.

Java/bwrap: faktyczna metoda odbioru pomija view-once, przepuszcza zwykłe
media znikające przez ograniczony downloader; rzeczywisty serializer
zachowuje start, rzeczywista baza CLI usuwa stare resend bodies. Brak konta,
sieci, telefonu i twierdzenia o usunięciu na cudzym urządzeniu.
S12 nadal wymaga prób telefonu w obu kierunkach, grup i prawdziwego snu.
[Wykonane polecenia i wyniki](../evidence/signal/S09/README.md).

## Interakcje — S08

Nowe `tests/test_signal_interactions.py`, `tests/qml/tst_signal_interactions.qml`,
`signal-interactions-test.qml` i `scripts/test-signal-interactions`.
Runner jest częścią `scripts/test`; zwykłe unittest odkrywają testy automatycznie.

```sh
python3 scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 scripts/test-icons --all-qml --timeout 600 --log docs/evidence/signal/S08/all-qml-final.log
python3 scripts/test-signal-interactions --output docs/evidence/signal/S08/integration-final.json
```

Backend: łańcuchy edycji przed bazą, stare/zdublowane wersje, autorstwo,
1:1/grupa/Notatka, własny sent sync, receipts starej wersji i osobna lista
odbiorców nowej, reakcje wielu autorów/zmiana/cofnięcie/ZWJ, brak oryginału
cytatu, UTF-16, szkic po restarcie, cancel, definitywna odmowa/retry/unknown,
niezmieniony deadline i brak przywrócenia usuniętego tekstu. Testy bridge
sprawdzają faktyczne metody/parametry RPC z atrapą po rzeczywistych pipe.

Qt: standardowe hjkl, Shift+Enter/Escape, zachowanie zwykłego szkicu podczas
edycji i błędu, wybór reakcji/cytatu/wzmianki, formatowanie z escapowaniem,
żywe akcenty, aktywny fokus i STOP przy blur/lock/send. Pełny runner sprawdza
rzeczywiste okno, aktualizację istniejącej karty bez nowego toasta, SQLite,
15 sekund rzeczywistego typing expiry, hard reload i brak duplikacji wysłań.
Zrzuty są offscreen, syntetyczne. D-Bus i socketpair wymagają dopuszczenia
poza ograniczeniem sandboxa; izolacja XDG i danych pozostaje bez zmian.

Odbiór z telefonem oraz potwierdzenie limitów/semantyki przez drugie konto
pozostają S12. Nie nazywamy testu atrapy dowodem synchronizacji urządzeń.
[Szczegółowe wyniki](../evidence/signal/S08/README.md).


## Media — po S07

```sh
python3 scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 -B -m unittest discover -s tests -p test_signal_media.py -v
python3 scripts/test-icons --file tst_signal_media.qml --log artifacts/signal-s07/controls.log
python3 scripts/test-signal-media-input
python3 scripts/test-signal-media --output artifacts/signal-s07/media.json
python3 scripts/test-signal-media-cli --distribution artifacts/signal-s07/signal-cli-0.14.8-putkin-media-1 --jdk artifacts/signal-s07/jdk-25.0.4.1+1
```

[Dowody S07](../evidence/signal/S07/README.md). Python używa rzeczywistych
plików/workerów/SQLite/pipe i syntetycznego CLI. Zestaw sprawdza tekst z
czterema mediami, sam załącznik, incoming i sent sync, restart i usunięcie
źródła, zero/limit/MIME/skrypt/symlink/hardlink/traversal, 20 MP, zepsuty
format, brak uprawnień, zmianę podczas kopiowania, pełny dysk/quota,
anulowanie, known failure/retry, unknown, shared refs i cleanup.
Schowek testuje syntetyczny executable wl-paste emitujący prawdziwy PNG.
Nie czyta schowka użytkownika.

QtTest sprawdza usuwanie załącznika klawiaturą, attachment-only send,
Ctrl+Shift+V, spóźnione odpowiedzi przy zmianie rozmowy, blokadę send
podczas przygotowania, fokus/Escape oraz preview/save/cancel obu akcentów.
Qt Multimedia odtwarza syntetyczny film H.264 i odczytuje PCM/WAV;
fizyczne audio nie jest inicjalizowane w teście. AudioOutput powstaje
przy świadomym uruchomieniu pliku z audio, nie przy samym obrazie.

`test-signal-media-input` buduje mały klient C++ (Qt6Quick/Qt6Test,
pkg-config, c++) i wysyła prawdziwe QDragEnterEvent/QDropEvent z dwoma URL
w offscreen. Osobno ustawia selectedFile rzeczywistego FileDialog i
wywołuje accepted; to kontrola callbacku, nie odbiór portalu pulpitu.
Wybór natywnym menedżerem plików i prawdziwy schowek Waylanda pozostają
macierzą środowiskową S11/S12.

`test-signal-media-cli` uruchamia faktycznie poprawioną metodę Java z
tripwire przed downloaderem: incoming/sent sync oraz obie wartości ignore.
View-once i expiring pomijają ją, ordinary dochodzi do niej. Dodatkowo
rozmiary, quota prawdziwego katalogu i wroga nazwa pliku. Bubblewrap bez
sieci, konta i home. Osobny `test-signal-cli` sprawdza wersję/help/RPC/EOF.
To nie jest dowód przesłania pliku z telefonem ani stresstest serwera.

Testy asyncio z workerami wymagają dopuszczenia lokalnego socketpair:
sandbox sieciowy potrafi zatrzymać call_soon_threadsafe mimo zakończenia
pracy wątku. Pierwszy wynik timeout nie jest PASS. Poprawne próby zachowują
prywatne XDG i atrapy, a QML dodatkowo prywatny D-Bus i offscreen.

## Raporty i odczyt — po S06

```sh
scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal_*.py' -v
PYTHONPATH=tests python3 -B -m unittest test_signal_receipts test_signal_pairing.PairingTests.test_disable_persists_and_history_deletion_is_separate -v
python3 -B scripts/test-icons --file tst_signal_receipts.qml --log artifacts/signal-s06/receipts-qml.log
python3 -B scripts/test-icons --file tst_signal_notifications.qml --log artifacts/signal-s06/notifications-qml.log
python3 -B scripts/test-icons --all-qml --timeout 600 --log artifacts/signal-s06/qml.log
python3 -B scripts/test-signal-receipts --output artifacts/signal-s06/receipts.json
python3 -B scripts/test-signal-integration --idle --output artifacts/signal-s06/integration.json
python3 -B scripts/test-signal-messages --output artifacts/signal-s06/messages.json
python3 -B scripts/test-signal-notifications --output artifacts/signal-s06/notifications.json
python3 -B scripts/test-notifications-integration --output artifacts/signal-s06/external.json
python3 -B -m unittest discover -s tests -p test_install.py -v
```

`scripts/test-signal-receipts` jest częścią scripts/test. Nowy zestaw Python
używa prawdziwego SQLite/bridge: receipt przed sent sync/RPC, wiele timestampów,
duplikaty, monotoniczność, kierunek i tożsamość konta/autora/odbiorcy,
niepełny ACI, read sync przed incoming, częściowa grupa/partial send,
nieznana lista odbiorców telefonu, trwałość, migracja 2→3, retencja pending,
transakcyjna walidacja ID i grupowanie 103 odczytów po autorze w batchach ≤100.
Test procesowy potwierdza parametry sendReceipt dla obu syntetycznych
wyników prywatności (SUCCESS i pusta lista), bez message.send. Nie dowodzi
wykonania self-sync przez serwer. Test kasowania historii S03 obejmuje
markery/kolejkę/raporty v3, a test S05 zachowuje rollback migracji 1→2→3.

QtTest sprawdza rzeczywiste delegaty/viewport, odroczenie 250 ms,
utratę warunku przed timerem, listę na małej szerokości, tworzenie rozmowy,
zamknięcie, scroll, brak powtórzenia oraz licznik MessageHub. Sprawdza też
tekst statusu z częściowymi licznikami i Accessible.name. Rozszerzony S05
renderuje karty: read starszego ID nie wygasza nowszego, read podczas
odczytu IPC nie odtwarza toasta, centrum/reply nie wywołują messages.read.

Natywny `signal-receipts-test.qml` używa produkcyjnego MessagesWindow,
NotificationService/SignalNotifications oraz realnego bridge/SQLite.
Prawdziwy Qt Window.active przełącza się między dwoma oknami **offscreen**;
test używa też minimized i produkcyjnego controller.blocked.
Potwierdza: zamknięte okno/centrum, telefoniczny read sync, widoczny zakres
z jednym zbiorczym RPC, brak odczytu za innym aktywnym oknem i przy lock,
scroll poza nadejście, sent→delivered→read→viewed, reload i cleanup.
To test natywnych obiektów Qt, nie odbiór Hyprlanda/DPMS ani telefonu.
Zrzut jest wyłącznie syntetyczny.

Macierz live S12 — **wszystkie poniższe próby jeszcze niewykonane**:

| Kierunek / scenariusz | Wymagany wynik | Dostępny dowód lokalny |
| --- | --- | --- |
| Telefon → Putkin, raporty zewnętrzne włączone | Odczyt telefonu usuwa tylko odpowiednie unread/toasty | Atrapa readMessages + realna DB/UI |
| Telefon → Putkin, raporty zewnętrzne wyłączone | Własny read sync nadal aktualizuje unread | Ten sam reducer; transmisja zależy od telefonu, do sprawdzenia live |
| Putkin → telefon, raporty włączone | Widoczny zakres synchronizuje się z telefonem; rozmówca dostaje dozwolony read | Audyt ManagerImpl/SyncHelper + dokładny RPC do atrapy |
| Putkin → telefon, raporty wyłączone | Własny sync działa bez zewnętrznego read | Audyt kodu + prawidłowa odpowiedź results:[] z atrapy; bez deklaracji odebrania przez telefon |
| Rozmówca ma wyłączone receipts | Brak raportu pozostaje brakiem informacji | Model nie generuje read z braku zdarzeń |
| Grupa, część członków czyta | Liczby per odbiorca, pierwszy receipt nie oznacza wszystkich | Realna DB i QtTest licznika |
| Wiadomość wysłana na telefonie | Zapis faktycznie eksportowanych raportów; brak obietnicy identycznych statusów | Direct destination ACI; group total=null w 0.14.8 |
| Hyprland: inna aplikacja/workspace, minimalizacja, lock/DPMS | Bez read dla niewidocznej/nieaktywnej rozmowy | Qt offscreen potwierdza warunki, fizyczna sesja pozostaje S11/S12 |

Próby muszą używać wskazanego rozmówcy/grupy; Notatka nie zastępuje
zewnętrznych receipts. Nie zmieniać prywatności telefonu dla wymuszenia
zielonego wyniku. Unknown w kolejce read zachowuje marker lokalny,
ale nie dowodzi synchronizacji telefonu; test nie wymyśla ACK self-sync.
Pełne wyniki, w tym początkowe nieudane próby: [S06](../evidence/signal/S06/README.md).

## Powiadomienia i quick reply — po S05

```sh
scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 -B scripts/test-icons --file tst_signal_notifications.qml --log artifacts/signal-s05/ui.log
python3 -B scripts/test-icons --file tst_notifications.qml --log artifacts/signal-s05/notifications.log
python3 -B scripts/test-icons --all-qml --timeout 600 --log artifacts/signal-s05/qml.log
python3 -B scripts/test-signal-notifications --output artifacts/signal-s05/notifications.json
python3 -B scripts/test-notifications-integration --output artifacts/signal-s05/external.json
python3 -B scripts/test-signal-messages --output artifacts/signal-s05/messages.json
python3 -B -m unittest discover -s tests -p test_install.py -v
```

Runner S05 jest częścią scripts/test. QML testuje prawdziwe karty/centrum,
NotificationFocus i SignalReplySession z jawnym MockMessagingBackend.
Rzeczywiste klawisze obejmują hjkl, Enter, Shift+Enter oraz blokadę
podwójnego send. Test handlera sprawdza composing/preedit; nie zastępuje
sesji z rzeczywistym silnikiem IME. Test obejmuje replacement przy edycji,
timeout, hotplug, DND, wyciszenie, lock, brak konta/rozmowy, zmiany/usunięcia,
catch-up i podgląd/zapis/anulowanie obu akcentów. Routing kontrolera
okna w QtTest ma atrapę, a runner natywny używa prawdziwego S04.

`test_signal_notifications.py` używa rzeczywistego SQLite: COMMIT przed
eventem, deduplikacja i brak toastów sent sync, osobne szkice, CAS,
atomowy enqueue i identyczne UUID, failed/safeRetry, unknown po restarcie,
retencja wszystkich kopii oraz migracja 1→2 z rollbackiem awarii.
Test kasowania historii S03 obejmuje także nowy szkic i wyciszenie.

`signal-notifications-test.qml` tworzy produkcyjny bridge/SignalService,
outbox/SQLite, jeden NotificationBackend na **prywatnym D-Bus** i natywne
FloatingWindow offscreen. CLI jest atrapą, treści i konto są syntetyczne.
Scenariusz: incoming→toast→S04 open, reply przy zamkniętym oknie, karta
archiwum, replacement, lock, DND, kolejne hard reloady i unknown po
błędzie RPC. Odczyt DB potwierdza liczbę operacji; prywatny D-Bus sprawdza
brak globalnego inline-reply. Zrzuty pokazują reply i unknown.
Pozostawione procesy i nieoczekiwane ostrzeżenia powodują FAIL.

Sesja kompozytora (OnDemand/grab, focus aplikacji, fizyczny hotplug),
prawdziwy IME, serwer i telefon pozostają odbiorem S11/S12.
Nie uruchamiać tego entrypointu na D-Bus użytkownika ani na koncie live.

## Okno wiadomości — po S04

```sh
scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 scripts/test-icons --file tst_messages.qml --log artifacts/signal-s04/ui.log
python3 scripts/test-icons --file tst_messages_controller.qml --log artifacts/signal-s04/controller.log
python3 scripts/test-icons --all-qml --timeout 600 --log artifacts/signal-s04/qml.log
python3 scripts/test-signal-messages --output artifacts/signal-s04/messages.json
python3 scripts/test-signal-integration --output artifacts/signal-s04/integration.json
python3 scripts/test-signal-pairing --output artifacts/signal-s04/pairing.json
python3 -B -m unittest discover -s tests -p test_install.py -v
```

Wyniki: **238 QML, 56 testów backendu, 616 wyników pełnej regresji QML,
15 końcowych wyników UI/kontrolera, 15 instalatora — PASS**.
[Dowody i ograniczenia S04](../evidence/signal/S04/README.md).
Nowy runner jest dołączony do scripts/test (limit QtTest 600 s).

`test_signal_messages.py` sprawdza rozwiązanie numeru/nazwy do tej samej
pustej rozmowy, brak próbnego send, walidację i obce konto, nazwy/unread,
blokadę kontaktu, admin-only grupy, wyłączone konto oraz atomiczny szkic/send.
QtTest sprawdza stale replies, szkic podczas zmiany rozmowy, paginację
180 wiadomości, kotwicę przy nowym wpisie, kolejkę 40 zdarzeń, hjkl,
Shift+Enter i zabezpieczenie IME, mały widok, autorów grup i oba akcenty.
Osobny kontroler testuje dwa syntetyczne monitory, PID/fokus, hotplug,
blokadę, przycisk paska i migrację komend bez zabrania istniejącego skrótu.

`signal-messages-test.qml` tworzy rzeczywiste MessagesWindow, SignalBackend,
SQLite i produkcyjny adapter, ale **jawnie podłącza tylko atrapę CLI**.
Runner zapewnia private XDG/D-Bus i offscreen; nie uruchamia shella hosta.
Otwiera pustą rozmowę po lookup, wysyła jedną syntetyczną wiadomość,
odbiera 65 przy zamkniętym oknie, sprawdza jedną subskrypcję, IPC i drugą
drogę wejścia do tej samej instancji, strony 50+16 oraz szkic po hard reloadzie.
Zrzuty rzeczywistego widoku: 776×720 i 320×300; resize testu używa QWindow.

Brak testu z fizycznym kompozytorem, telefonem i rzeczywistym silnikiem IME.
Kompozycja jest sprawdzona przez gałąź handlera z aktywnym preedit, standardowe
klawisze przez realny QtTest. Lokalny zestaw fontów nie zawiera japońskich
glifów; brakujące znaki w PNG nie oznaczają utraty treści w SQLite.

## Parowanie i ustawienia po S03

```sh
python3 scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 scripts/test-icons --file tst_signal_settings.qml --log artifacts/signal-s03/ui.log
python3 scripts/test-icons --all-qml --timeout 600 --log artifacts/signal-s03/qml.log
python3 scripts/test-signal-pairing --output artifacts/signal-s03/pairing.json
python3 scripts/test-signal-integration --idle --output artifacts/signal-s03/integration.json
python3 -B -m unittest discover -s tests -p test_install.py -v
```

Nowe zależności: libqrencode (produkcja, lokalnie 4.1.1/SONAME 4), ZXing
(tylko niezależny dekoder testowy, lokalnie 3.1.1/SONAME 4). Nie ma pobierania
ani instalowania pakietów w testach. Poza tym Python korzysta ze stdlib.
Kontrolki są testowane przez QtTest, rzeczywiste okno przez Quickshell.

`test_signal_pairing.py` sprawdza prawdziwy bridge, procesy i pliki:
QR zakodowany libqrencode i odczytany niezależnym ZXing, brak biblioteki,
walidację URI; podwójny start; sukces i odtworzenie po restarcie; kontakty,
nazwy profili i grupy bez fikcyjnej historii; utraconą odpowiedź finishLink;
cancel ze starym attemptId; timeout; restart w trakcie próby; stop/resume
i osobne potwierdzone usunięcie historii wraz z WAL; cofnięcie powiązania
wykryte przez refresh kontra utrata transportu; walidację konfiguracji,
0600 i odmowę zapisu przez symlink. Każdy test sprząta własne PID-y.
Tylko test timeout skraca LINK_SECONDS w osobnym procesie testowym;
produkcyjny termin wynosi 120 s i nie jest opcją konfiguracji.

Atrapa generuje syntetyczny URI dopiero w pamięci procesu. `linkGate`
zastępuje skan telefonu, `linkedFile` reprezentuje zapisanie konta,
`linkCrash` przerywa proces po zapisie, przed odpowiedzią. `revokedFile`
usuwa manager z listAccounts. Pliki te zawierają tylko znaczniki, nie URI.
Rejestr zapisuje rodzaj operacji i PID, nie parametry RPC. Test skanuje
pliki tymczasowe pod kątem niezamierzonego utrwalenia URI.

`tst_signal_settings.qml` składa prawdziwy serwis QML i stronę ustawień
z MockSignalBackend. Sprawdza h/j/k/l w polu nazwy, Tab/Enter, anulowanie,
quiet zone i moduł QR na obrazie w pamięci, odrzucenie starej próby,
brak przekazania QR do changed, expiry, zwalnianie strony, etykiety stanów,
osobne potwierdzenie historii z fokusem na Anuluj oraz piksele obu akcentów
przy preview/save/cancel. Nie zapisuje obrazu z kodem do pliku.

`scripts/test-signal-pairing` jest też odtwarzalnym podglądem na atrapach.
Otwiera rzeczywisty SettingsWindow przez PanelHost/PanelSurface i istniejący
routing, uruchamia produkcyjny bridge z jawną atrapą CLI. Przechodzi przez
QR, zamknięcie strony, SIGKILL bridge podczas QR i ponowny start z UI,
ponowienie, sukces, zamknięcie okna, hard reload oraz
wyłączenie odbioru. Zrzut jest dozwolony dopiero poza próbą; wynik PNG
pokazuje ustawienia bez QR. Zakończenie kontroluje brak własnych procesów.
Runner jest częścią scripts/test. Prywatne XDG/D-Bus i offscreen są
obowiązkowe; nie uruchamia usług sprzętu, PAM ani serwera powiadomień.

Pełny QML przekroczył dotychczasowy limit 240 s bez porażki asercji;
runner test-icons dostał opcjonalny dodatni --timeout, użyty z 600 s.
Timeout pierwszej próby pozostaje w dowodach, nie jest liczony jako PASS.
Skan rzeczywistego telefonu, cofnięcie powiązania live i serwerowa
dostępność pozostają odbiorem S12. W 0.14.8 brak eventu websocket/auth;
brak konta jest sprawdzany przy wejściu na stronę, jawnej akcji, wysyłaniu
i restarcie, nie przez cykliczny polling.

## Testy historii i outboxu po S02

```sh
python3 scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 scripts/test-signal-integration --idle --output artifacts/signal-s02/qml.json
python3 -B -m unittest discover -s tests -p test_install.py -v
```

**S02: 42 testy Signala, 220 QML, 15 testów instalatora oraz natywna
integracja QML: PASS.** [Dowody](../evidence/signal/S02/).
Python używa prywatnych baz SQLite i procesów CLI-atrap, bez sieci/konta.
Jedna próba celowo czeka na pełny produkcyjny timeout 60 s i późną
odpowiedź; cały zestaw Signala zajmuje około dwóch minut.

Nowe `test_signal_history.py` i `signal_store_crash.py` sprawdzają:

- Commit przed publikacją — drugi connection SQLite widzi rekord już
  w callbacku UI. Telefonowe sent sync, incoming i lokalna odpowiedź,
  UTF-8, strony wiadomości, stabilny messageId i trwały szkic/outbox.
- Sent sync przed i po wyniku RPC, retransmisje kopert, zmiana sourceDevice,
  różne konta/autorzy/grupy o tych samych czasach, legalne identyczne teksty,
  Notatka, nierozstrzygnięty adres, konflikt payloadu bez nadpisania.
- Keyset pagination, remis daty lokalnej, kontrola scope kursora, limit
  bajtów, >32-bit timestamps, odmowa wartości spoza bezpiecznych liczb JS.
- Idempotencja operationId i odmowa odmiennej treści, compare-and-swap
  szkicu, anulowanie queued, wynik per odbiorca i częściowy sukces,
  błąd RPC, niekompletny/obcy wynik, NETWORK_FAILURE oraz bezpieczny retry.
- Restart sending → unknown; brak zgadywania korelacji po treści;
  awaria CLI po dispatch i reconnect bez drugiej próby. Timeout 60 s,
  unknown i spóźniony wynik tego samego żądania, nadal jedno send.
- Faktyczne przerwanie procesu przed COMMIT, po COMMIT i po trwałym
  oznaczeniu sending. WAL recovery zachowuje odpowiednio brak operacji,
  queued albo unknown, z integrity_check=ok.
- SQL migration 0→1, rollback po odmowie CREATE TABLE w połowie migracji,
  nowszy schemat bez modyfikacji, uszkodzoną bazę i złośliwy symlink WAL.
- Rzeczywiste SQLITE_FULL przez max_page_count oraz odmowę transakcji
  przez query_only. Brak niezatwierdzonych wpisów i eventów UI.
  Próba przez bridge odbiera trzy koperty; po błędzie zapisu drugiej
  zostaje tylko pierwsza, CLI kończy pracę i nie subskrybuje ponownie.
- Unsupported expiring/view-once bez tekstu w SQL/plikach DB/WAL;
  zwykłe media jako referencje; brak raw unknown eventów i raw errors.
  Delete/edit przed celem, restart i brak odtworzenia starej treści.
- Usuwanie treści z DB i WAL, blokadę publikacji przy zajętym checkpoint,
  dokończenie cleanup po restarcie, TTL metadanych i treści roboczej.
  Osobny subprocess testowy skraca tylko TTL stagingu i potwierdza
  czyszczenie przez jednorazowy termin, bez kolejnego IPC ani pollingu.
- Preflight aktywnego timera rozmowy odmawia send, usuwa tekst stagingu
  i pokazuje retention_unsupported; żadna mutacja nie trafia do atrapy.

Runner QML teraz sprawdza rzeczywiste metody SignalService (strony,
sendText, operation, szkic), a także ich trwałość i deduplikację po każdym
reloadzie. Wersja schematu jest 1. Testowy test.receive jest już tylko
znacznikiem commit, bez kopii koperty. 60 s idle nadal daje 0 ticków CPU
obu pomocników, 0 nowych procesów/RPC i brak osieroconych PID.

S01 `storage_not_ready` został zastąpiony testem produkcyjnej gałęzi
konfiguracji: zdrowa baza pozwala na jedną subskrypcję, uszkodzona baza
zatrzymuje start przed CLI. Stare wyniki S01 pozostają historycznym dowodem.
`signal_cli_fake.py` dodaje jawne scenariusze receiveEvents,
beforeSendReply/afterSendReply, sendDelay/sendCrash/sendError/sendResult,
contacts/groups/expiration. Nie podłącza prawdziwego executable/konta.

Pierwsze uruchomienie QML w sandboxie odmówiło utworzenia prywatnego
socketu D-Bus. Ten sam runner przeszedł poza tym ograniczeniem, zachowując
izolowane XDG/D-Bus i offscreen. Instalator także testowano wyłącznie
w prywatnych katalogach, bez aktywacji pulpitu. Realnego JVM z kontem,
telefonu i pełnej regresji sprzętu w S02 nie uruchamiano.

## Testy procesu i transportu po S01

```sh
python3 scripts/check
python3 -m unittest discover -s tests -p 'test_signal*.py' -v
python3 scripts/test-signal-integration --idle --output artifacts/signal-s01/qml.json
python3 scripts/test-signal-process \
  --executable artifacts/signal-s00/tool/signal-cli-0.14.8/bin/signal-cli \
  --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre \
  --output artifacts/signal-s01/jvm.json
```

**Wyniki S01:** 19 testów Python (5 S00 + 14 S01), 220 QML bez błędów,
integracja natywnego adaptera PASS, cztery próby JVM PASS.
[Dowody](../evidence/signal/S01/). Testy instalatora: 15 PASS.
Nie uruchamiano pełnej regresji sprzętu i wszystkich widoków; S01 nie
zmienia ich logiki. `scripts/test` odkrywa testy Python i uruchamia nowy
runner QML; próba rzeczywistego JVM pozostaje osobną, jawną komendą.

`tests/test_signal_lifecycle.py` używa rzeczywistych procesów, pipes,
blokad i sygnałów, a syntetycznego executable. Sprawdza:

- rozdzielone bajty UTF-8, sklejone ramki, event przed odpowiedzią,
  odpowiedzi poza kolejnością, deadline, anulowanie i późną odpowiedź;
- maksymalnie osiem odczytów i jedną mutację, burst IPC, brak sukcesu
  przy stop/awarii w trakcie operacji i brak kolejnej mutacji przed
  rozstrzygnięciem poprzedniego RPC;
- dwa równoczesne starty, zachowanie inode `owner.lock`, nieistotność
  wpisanego PID, retry po zwolnieniu blokady, generacje transportu;
- EOF/TERM/KILL bridge i nadrzędnego procesu poza UWSM, reap potomków,
  eskalację dla CLI ignorującego EOF/TERM, blokadę do zakończenia CLI;
- brak CLI w nieskonfigurowanym idle, disabled, brak executable,
  złą wersję, wiele kont, za duże/uszkodzone ramki oraz niebezpieczne ścieżki;
- produkcyjną bramkę storage_not_ready: nawet skonfigurowane linked
  na syntetycznym executable nie wywołuje subscribeReceive;
- rzeczywiste opóźnienia 1/2/4/8/16 s: sześć startów łącznie, potem
  skończony failed; dopiero jawne retry odtwarza transport.

`signal_cli_fake.py --lifecycle-scenario <plik>` rozszerza peer S00;
plik wymaga `format:1, synthetic:true`. Pola version/accounts/fault,
crashAfterSubscribe, ignoreEof/ignoreTerm, chunkBytes/chunkDelay i record
umożliwiają kontrolowane awarie i liczenie startów/subskrypcji. `record`
zapisuje tylko typ akcji i PID syntetycznego procesu. Ten tryb nie ma
połączenia z Signal ani dostępu do rzeczywistego konta.

`scripts/test-signal-integration` tworzy prywatny D-Bus, XDG i offscreen
Quickshell z samym SignalService/Backend. Sprawdza utworzenie i zniszczenie
FloatingWindow, dwa soft reloady i hard reload, RPC Unicode, awarię bridge,
jawne retry i normalny/TERM/KILL koniec faktycznego Quickshella. `--idle`
mierzy 60 s zamiast 2 s: w S01 oba procesy miały **0 ticków CPU**,
bez nowych procesów i RPC. Kontroluje logi QML i brak osieroconych PID.
Nie inicjalizuje adapterów sprzętu, sesji ani serwera powiadomień.

`scripts/test-signal-process` wymaga bubblewrap; brak fallbacku bez izolacji.
Używa rzeczywistego wrappera signal-cli i JRE, pustego katalogu CLI oraz
wyłącznie listAccounts. Potwierdza ten sam PID po exec, dziedziczenie FD
i odmowę flock, gdy trzyma go już tylko JVM. Sprawdza TERM/KILL właściciela,
śmierć zaraz po spawn oraz kontrolowaną bramkę przed exec Java. Bramka
jest wyłącznie testowym executable w prywatnym JAVA_HOME, które zatrzymuje
proces po przejściu oryginalnego wrappera. Zwykłe próby ready używają
bezpośrednio prawdziwego JRE. Wszystkie cztery próby kończą się bez CLI.

W sandboxie agenta prywatne sockety D-Bus i NETLINK_ROUTE bubblewrap są
zabronione. Próby QML/JVM i test instalatora wymagający D-Bus wykonano
po dopuszczeniu tych samych izolowanych runnerów poza tym ograniczeniem;
nie zdejmowano izolacji konta/sieci ani nie aktywowano shella.

## Testy dostępne po S00

```sh
scripts/check
python3 -m unittest discover -s tests -p test_signal_contract.py -v
python3 scripts/test-signal-cli \
  --executable artifacts/signal-s00/tool/signal-cli-0.14.8/bin/signal-cli \
  --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre \
  --output artifacts/signal-s00/cli-jvm-probe.json
```

Testy Python używają wyłącznie stdlib. Są też automatycznie odkrywane
przez istniejące `scripts/test`. W S00 pełny zestaw sprzętu/UI nie jest
potrzebny: produkcyjne QML, backendy i instalator nie zmieniły się.
`scripts/check` nadal obejmuje cały projekt.

`tests/signal_cli_fake.py --scenario <plik> [--chunk-bytes N]` wymaga jawnego
scenariusza z `synthetic:true` i `format:1`. Nie uruchamia CLI, nie używa
sieci, bazy ani konta. Czyta rzeczywiste stdin i zapisuje NDJSON stdout.
Każda wymiana określa `method`, dokładne `params`, `result` albo `error`
oraz nazwy zdarzeń przed/po odpowiedzi. ID odpowiedzi pochodzi z żądania.
Niezgodne żądanie, nadmiarowe żądanie, ucięta/za duża ramka oraz EOF
przed końcem scenariusza kończą test błędem, zamiast zwracać pozorny sukces.
Dzielenie na pojedyncze bajty umożliwia test ramek i UTF-8; sam OS może
scalić kilka zapisów przy odczycie, dlatego osobny test kontroluje zapisy.

[session.json](../../tests/fixtures/signal/v0.14.8/session.json) zawiera:

- przychodzący tekst z emoji, polskimi znakami i nową linią;
- sent sync, osobną edycję, reakcję, remote delete, delivery/read receipt;
- read sync telefonu, grupę, metadane mediów, wiadomość znikającą i view-once;
- telefonowe edit/delete sync oraz celowo nieznaną metodę przyszłego eventu;
- sekwencję listAccounts → subscribeReceive → udane send → send z wynikiem
  RATE_LIMIT_FAILURE → unsubscribeReceive. Pierwszy event wyprzedza
  odpowiedź subscribeReceive.

To metadane i treści syntetyczne. W fixture nie ma rzeczywistego pliku
mediów, QR, sekretów ani dowodu realnych operacji. `synthetic-attachment.png`
jest fikcyjnym ID; współdzielenie go przez przykłady przypomina o refcount
podczas retencji. Docelowe testy mediów wygenerują własny plik w prywatnym
stagingu. Tryb replay S00 nie implementuje domeny, subskrypcji serwera
ani deduplikacji. S01 sprawdza backoff i sprzątanie produkcyjnego bridge
przez osobny tryb lifecycle opisany powyżej.

Pięć testów zachowania sprawdza pipe/EOF/korelację ID, możliwość eventu
przed odpowiedzią, UTF-8 dzielone na bajty, brak eventów przed subskrypcją,
odmowę sukcesu przy zmienionym odbiorcy oraz niepoprawne ramki.
Fixtures odtwarzają eksport serializerów wskazanych w API.md. Nie
dopisujemy brakujących pól `expirationStartTimestamp` czy viewOnceOpen
do raw eventów 0.14.8 w celu „zaliczenia” przyszłych wymagań.

## Odtworzenie narzędzia bez instalacji systemowej

Archiwa są pobierane wyłącznie z oficjalnych wydań, w katalogu ignorowanym
przez Git. Poniższe komendy dotyczą Linux x86_64/glibc; innych platform
nie zweryfikowano. Pakiety systemowe, autostart i katalog konta użytkownika
nie są modyfikowane.

```sh
mkdir -p artifacts/signal-s00/downloads artifacts/signal-s00/tool
curl --fail --location \
  https://github.com/AsamK/signal-cli/releases/download/v0.14.8/signal-cli-0.14.8.tar.gz \
  -o artifacts/signal-s00/downloads/signal-cli.tar.gz
curl --fail --location \
  'https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz' \
  -o artifacts/signal-s00/downloads/jre.tar.gz
python3 - <<'PY'
import hashlib
from pathlib import Path
import tarfile

archives = {
    'signal-cli.tar.gz': 'ccd408e831eff7e41ebaaf309704840bb00d78a7869f35ad700dbae5b5a5bb65',
    'jre.tar.gz': '1731a34baadec5479258ea0202e4d5d865d2efeee60cb0c7d7eb056fe96ca219',
}
for name, expected in archives.items():
    path = Path('artifacts/signal-s00/downloads') / name
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise SystemExit('Nieprawidłowy SHA-256: ' + name)
    with tarfile.open(path) as archive:
        archive.extractall('artifacts/signal-s00/tool', filter='data')
PY
```

Następnie uruchomić `python3 scripts/test-signal-cli` z pierwszego bloku.
Runner wymaga bubblewrap i działających user namespaces, izoluje sieć,
PID, mount, XDG i urządzenia. Montuje read-only `/usr`, dystrybucję CLI
i JRE; nie montuje katalogu domowego ani hostowego `/run`. Tymczasowe
dane konta są wyłącznie w nowym `/tmp` sandboxa. Nie ma fallbacku bez
izolacji. Pierwsza próba wewnątrz sandboxa agenta odmówiła utworzenia
NETLINK_ROUTE; uruchomiono ten sam izolowany runner z uprawnieniami
pozwalającymi na bwrap. Sieć wewnątrz próby pozostała wyłączona.

Probe pyta o wersję/help oraz sprawdza pusty magazyn przez RPC. Nie
wywołuje `startLink`, `register`, wysłania na koncie ani odbioru konta.
`finishLink` dostaje puste parametry i musi odmówić przed siecią.
Metody konta bez konta mają zwrócić -32602. Wynik zapisuje stdout/stderr
**tylko dlatego**, że nie ma dostępu do prywatnych danych. Tej praktyki
nie przenosić do produkcji ani testów z telefonem.

Wariant native można zbadać tym samym runnerem bez `--java-home`, z
`--executable artifacts/signal-s00/tool/signal-cli`. Znany negatywny
wynik zamykania jest w dowodach S00. Nie jest akceptowanym zamiennikiem
wariantu JVM na podstawie samego `--version`.

## Macierz kolejnych etapów

Poniższe scenariusze są **wymaganiami przyszłych testów**, nie wynikami S00.
Obejmują także negatywne przypadki i granice uprawnień.

| ID / etap | Obowiązkowy test lokalny | Osobny odbiór live |
| --- | --- | --- |
| T01 / S01 | Jeden odbiorca przy dwóch startach, soft/hard reload, zamknięcie okna bez zatrzymania usługi; EOF/TERM/KILL shella i bridge poza UWSM, brak osieroconego CLI/JVM; blokada dziedziczona przez exec, PID reuse, wyjście w czasie RPC. Fragmenty/coalescing/Unicode, odpowiedzi poza kolejnością, timeout, późna odpowiedź, generacje, nieznana wersja, backoff i przeciążenie. | S12 cgroup prawdziwego putkin.service i restart. |
| T02 / S02 | Commit przed UI, restart z trwałym outbox, przerwanie przed/po commit i wysłaniu; duplikaty incoming/sent sync, grupa i Notatka, event przed subskrypcją, pending mutations, szkice, migracje, paginacja, >32-bit timestamps. Unknown bez automatycznego ponowienia. Dysk pełny/read-only i uszkodzona baza. | Wiadomości telefon ↔ komputer od sparowania; przerwa/reconnect, bez obietnicy starej historii. |
| T03 / S03 | Link start/expiry/cancel/retry, brak zapisu QR do logów, listAccounts po utracie odpowiedzi finishLink, brak konta/brak CLI, więcej niż jedno konto, odłączenie urządzenia oddzielone od offline. | Skan QR, tożsamość urządzenia połączonego, Note to Self. |
| T04 / S04 | Jeden FloatingWindow, właściwy monitor/routing, zamknięcie/ponowne otwarcie i szkic, odrzucone obce ID, mały ekran; hjkl, Shift+Enter i IME. Żadnych procesów w widokach. | Wskazany rozmówca, inicjowanie rozmowy i tekst w obu kierunkach. |
| T05 / S05 | Otwórz i reply tej samej karty/centrum po wygaśnięciu toasta; wspólny outbox i operationId, DND, timeout wstrzymany podczas edycji, błąd/unknown ze szkicem, fokus/monitory/blokada; read centrum nie wywołuje Signal read, sent sync bez toasta. Żywe oba akcenty przy preview/save/cancel. | Przychodząca wiadomość z drugiego konta, quick reply i odpowiedź na telefonie; brak drugiego serwera powiadomień. |
| T06 / S06 | Rozdzielenie delivery/read/viewed, wielu odbiorców grupy, późne i zdublowane receipt/read sync, receipt przed wiadomością, brak ACI, widoczne w aktywnym oknie kontra samo zaznaczenie/centrum. Nie emitować read dla blokady/ukrytego okna. | Read sync w obu kierunkach przy włączonych/wyłączonych zewnętrznych receipts; Notatka niewystarczająca. |
| T07 / S07 | Media wysyłane/odebrane, zero bytes/zły MIME/błędna ścieżka/za duży plik; streaming poza QML, cancel/failure, restart, staging i cleanup, symlinki/path traversal, odrzucony executable. Refcount wspólnych plików. View-once bez zwykłego podglądu/cache. | Foto/wideo/audio/plik w obu kierunkach; nie obiecywać getAttachment jako pobierania z serwera. |
| T08 / S08 | Reakcje/cofnięcie, edycje/wersje, autorstwo, cytaty, UTF-16 w mentions, typing expiry; event przed celem, read receipt starej wersji, sent sync edycji/reakcji, retry bez duplikowania. | Zmiana na telefonie i komputerze, zgodność odmów/limitów. |
| T09 / S09 | Delete przed/po message/edit/retry, tombstone, usunięcie wszystkich kontrolowanych kopii z powiadomień i mediów, wygaśnięcie po restarcie/suspend, skoki zegara, błąd cleanup/WAL; lokalne delete bez remoteDelete. Test rzeczywistego serializera `expirationStartTimestamp` i `send.expiresInSeconds` w przypiętym buildzie putkin-retention-2. Test view-once niedostępnego. | Właściwy start timera na obu urządzeniach, opóźniony sent/read sync i zniknięcie powiadomień; zdalne usunięcie. |
| T10 / S10 | Tworzenie/aktualizacja/join/quit, zaproszenia, role, terminated/blocked, rename i zmiana numeru bez zmiany ID, brak praw i niepełne listy, partial send do grupy, unknown tworzenia bez ślepego retry. | Wskazana grupa/rozmówca, admin i członek, przyjęcie/odrzucenie zaproszenia. |
| T11 / S11 | Pełna regresja, długie listy i burst eventów, idle bez pollingu, ograniczona pamięć/ramki, chaos transportu/dysku, wersje/rollback i kontrola danych w logach. | Próby środowiskowe nie zastępują kontroli danych syntetycznych. |
| T12 / S12 | Staging/dry-run/rollback/prywatny cel, dane poza wydaniami, rollback nie cofa kluczy/retencji, zależności i zgodność wersji. | Aktywacja, telefon, wskazana rozmowa/grupa, sprzęt i końcowy protokół odbioru. |

Każdy runner UI używa prywatnych XDG i D-Bus z wzorców
[testowania Putkina](../testing.md), offscreen lub osobnego Hyprlanda.
Nie uruchamia się drugiego pełnego shella na D-Bus hosta. Do fixtures nie
podłącza się rzeczywistego executable automatycznie. Zwykłe unittest nie
pobierają narzędzi ani nie potrzebują połączenia sieciowego.

## Dowody i kryterium zamknięcia

W `docs/evidence/signal/SXX/` zapisujemy komendy, wersje, kody wyjścia,
logi wyłącznie syntetyczne i kontrolę cleanup. Nie zapisujemy numerów
realnego konta, treści prywatnych wiadomości, URI parowania, tokenów,
załączników ani plików protokołu. Użycie prawdziwego executable z pustym
magazynem opisujemy oddzielnie od atrapy i od telefonu.

S00 kończy się kontraktami, przypiętym i uruchomionym narzędziem,
mapą luk oraz szkieletem testowego transportu. S01 zaczyna implementację
produkcji. S12 pozostaje nieodebrane, dopóki próby z telefonem i wskazaną
rozmową/grupą nie mają własnego potwierdzenia.


S12 dodaje `SignalEventContractTest.java` do `scripts/test-signal-media-cli`.
Sprawdza rzeczywisty `JsonTypingMessage.from` w przypiętych jarach i wartości
`STARTED`/`STOPPED`; nie wymaga konta/sieci. Regresja `test_signal_interactions`
sprawdza oba zdarzenia bez tworzenia historii, a `test_signal_history` kontroluje,
że diagnostyka `invalid_event` zawiera tylko lokalizację kodu bez danych zdarzenia.
