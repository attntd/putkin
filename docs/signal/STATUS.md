# Signal — status i przekazanie prac

## Bieżący stan — 2026-09-21

**S12: wdrożony i sparowany; podstawowy odbiór live PASS. Rozszerzona macierz otwarta.**
Aktywny build: `20260921-110638-03f24e35e2b4`, z zachowanymi zmianami
`main` 311edb8. SQLite v7, IPC v1, CLI 0.14.8 JVM + putkin-retention-2,
przypięty JRE 25.0.4.1+1. Testy lokalne i lifecycle na pulpicie PASS.
Użytkownik potwierdził skan i wysłał wiadomość (`sent`). Naprawiono parser
zdarzeń pisania; konto wróciło do `ready/linked` bez ponownego skanu.
Notatka z tekstem działa w obie strony; użytkownik potwierdził widoczność
na telefonie i w Putkinie oraz reakcje i załączniki z drugą osobą.
Edycja oraz Otwórz/odpowiedź z powiadomienia także potwierdzone.
Użytkownik potwierdził również zmiany statusu odczytu w rozmowie,
usuwanie wiadomości i działanie rozmów grupowych.
Pozostałe rozszerzone scenariusze live są jawnie niewykonane.
Po uwagach wizualnych wdrożono nowy układ opisany poniżej; Signal
pozostaje `ready/linked`, bez ponownego parowania.
[Obsługa i rollback](OPERATIONS.md), [dowody S12](../evidence/signal/S12/README.md).

Praca w `/home/attntd/projects/signal`, gałąź `signal`, bazowy commit
`f16840763eb030efea9eb21585c3b7b9aa5e8bc6`. To checkout źródeł Putkina;
historyczne ścieżki w promptach nie oznaczają edycji opublikowanego shella.
Przeczytaj [roadmapę](ROADMAP.md), [kontrakty](CONTRACTS.md),
[API](API.md) i [testowanie](TESTING.md), potem
[macierz odbioru](ACCEPTANCE.md) i [prompt S12](../prompts/signal/12-release-activation.md).

| Etap | Stan |
| --- | --- |
| S00 — Audyt integracji i kontrakty | Ukończony; dowody poniżej |
| S01 — Proces usługi i transport | Ukończony; dowody poniżej |
| S02 — Historia, synchronizacja i kolejka wysyłania | Ukończony; dowody poniżej |
| S03 — Parowanie konta i ustawienia | Ukończony lokalnie; skan telefonu PASS w S12 |
| S04 — Okno rozmów, tekst i nowa rozmowa | Ukończony lokalnie; Qt/Wayland odebrane w S11; telefon/fizyczny IME w S12 |
| S05 — Powiadomienia: otwórz rozmowę i quick reply | Ukończony lokalnie; prywatny Wayland w S11; fizyczny IME/telefon w S12 |
| S06 — Dostarczenie, odczyt i stan między urządzeniami | Lokalnie PASS; status odczytu live potwierdzony; pełna macierz prywatności/read sync otwarta |
| S07 — Media i załączniki | Ukończony lokalnie; telefon/portal/schowek sesji i fizyczne audio w S12 |
| S08 — Reakcje, edycje, odpowiedzi i wskaźnik pisania | Ukończony lokalnie; telefon i drugi rozmówca w S12 |
| S09 — Usuwanie i wiadomości znikające | Lokalnie PASS; usuwanie live potwierdzone; znikanie, wszystkie tryby usuwania i suspend otwarte |
| S10 — Grupy, kontakty i pełne rozpoczynanie rozmów | Lokalnie PASS; rozmowy grupowe live potwierdzone; szczegółowe role/zaproszenia/uprawnienia otwarte |
| S11 — Odporność, pełny odbiór i wydajność | Ukończony lokalnie; ACCEPTANCE.md i dowody S11; live w S12 |
| S12 — Instalacja, aktywacja i odbiór z telefonem | Wdrożony; lokalnie i lifecycle pulpitu PASS; podstawowy odbiór live PASS; rozszerzona macierz otwarta |

## S12 — Kropki, reakcje i podgląd załączników — 2026-09-21

- **Wdrożone:** `20260921-110638-03f24e35e2b4`. Kropki bez ramki/tła,
  w linii pierwszego wiersza treści, jasne na ciemnym tle i ciemne na
  akcencie. Reakcje także bez ramki, obok godziny/edycji/odczytu.
  Kliknięcie miniatury otwiera podgląd; nazwa, rozmiar oraz działania
  Zapisz/Otwórz/Zamknij są dopiero tam. Plik bez miniatury ma symbol typu
  prowadzący do tego samego widoku. Enter otwiera, Escape przywraca fokus.
- **Pliki:** MessageHistory, AttachmentCard, MediaPreview; test mediów
  i syntetyczny harness Waylanda. Dokumentacja wyglądu i kontraktów
  zaktualizowana; transport, IPC produkcji i SQLite bez zmian.
- **Sprawdzone:** 272 QML bez błędów, 32 celowane testy Qt PASS,
  prywatny Wayland PASS z rzeczywistym kliknięciem miniatury, skalą 1,5,
  akcentami i restartem. Obejrzane zrzuty stopki edytowanej/odczytanej
  wiadomości oraz podglądu. Pakiet: 167 QML PASS, instalator kod 0.
- **Po aktywacji:** Signal `ready/linked`, puste kody błędów, zgodne sumy
  źródeł/wydania, Caffeinate `presentation`, pięć buildów. Powrót:
  `20260921-104858-36c9df96d894`. [Dowody](../evidence/signal/S12/ui-refinement/README.md).
  Próby wyłącznie syntetyczne; rozszerzona macierz telefonu bez zmian.
  Następny krok: użytkownik ocenia dopracowany wygląd.

## S12 — Korekta układu po odbiorze — 2026-09-21

- **Wdrożone:** `20260921-104858-36c9df96d894`. Ramką okna zarządza
  wyłącznie Hyprland. Szczegóły są po prawej w nagłówku i zawierają
  znikanie. Menu ⋯ jest w prawym górnym rogu dymka, a reakcje po lewej
  obok godziny/stanu. Własne dymki mają akcent i kontrastowy tekst.
  Composer zaczyna od 36 px, jak oba przyciski, i rośnie wraz z tekstem.
- **Pliki:** MessagesView, ConversationDetails, MessageHistory,
  MessageComposer, AttachmentCard i MediaPreview; dopasowane testy
  retention/groups oraz syntetyczny harness signal-acceptance/Wayland.
  Bez zmian API, schematu bazy i transportu.
- **Testy:** `scripts/check` — 272 QML, 0 błędów; dwa skorygowane pliki
  fixture ponownie PASS. Sześć celowanych zestawów Qt — 44 PASS.
  Prywatny natywny Wayland PASS; obejrzano zrzuty własnych dymków,
  reakcji, załącznika, pustego/długiego pola, Szczegółów i skali 1,5.
  Instalator — 167 QML PASS, aktywacja kod 0. Wcześniejsze próby i poprawki
  testów opisuje [dowód układu](../evidence/signal/S12/ui-layout/README.md).
- **Po aktywacji:** `signal status` — `ready/linked`, brak błędów,
  zachowane Caffeinate `presentation` i pięć buildów. Pliki okna zgodne
  ze sprawdzonymi źródłami. Powrót: `20260921-091350-39f9ddda75b4`.
  Testy wyglądu używają wyłącznie rozmów syntetycznych; nie rozszerzają
  macierzy odbioru z telefonem. Następny krok: ocena wyglądu przez użytkownika.

## S12 — Pakiet, aktywacja i telefon — 2026-09-21

- **Wdrożone:** `20260921-091350-39f9ddda75b4` przez `scripts/install --activate`.
  Jedna instancja w `putkin.service`/UWSM, prawidłowy właściciel powiadomień
  i gotowość blokady. Zachowano pięć buildów oraz Caffeinate `presentation`.
  Poprzedni punkt powrotu: `20260921-080356-f26716f87551` (shell bez Signala).
- **Pakowanie:** nowe `scripts/package-signal-runtime`, `_signal_install.py`,
  `signal_release.py`, `signal-release.json` i `distribution.json`; rozszerzone
  `install`/`_install.py` oraz wybór narzędzi w bridge. Dwa oficjalne archiwa,
  cała dystrybucja i oba poprawione jary zweryfikowane. Odtworzenie daje ten
  sam hash drzewa. Wydanie ma 357 plików źródeł runtime i 348 CLI/JRE;
  nie zawiera atrap, konta, historii, mediów ani szkiców.
- **Zgodność:** reader i pin są porównywane z kontraktem. Prywatny znacznik
  danych powstaje przed migracją. Instalator sprawdza SQLite razem z WAL,
  ponawia kontrolę pod lease po stopie i odmawia niezgodnego downgrade’u,
  także przy odzyskiwaniu po nieudanym starcie. Nie cofa kluczy ani treści.
  Prywatny rollback między gotowymi pakietami zachował każdy hash danych.
- **Scalenie:** checkout Signala był starszy od aktywnego shella. Trójstronnie
  włączono zmiany `main` 311edb8, w tym uwierzytelnianie, launcher, skróty,
  rozwijane karty i wspólne przewijanie. Zachowano routing, redakcję i quick
  reply Signala. Uzupełniono migrację pełnych historycznych katalogów komend.
  Indeks Git i gałąź main pozostały nietknięte; nie wykonano commita S12.
- **Testy:** końcowe `scripts/check`: 272 QML / 0 błędów. `scripts/test`:
  kod 0, 218 Python, 787 Qt / 0 FAIL / 0 SKIP i 23/23 integracje PASS.
  Dodatkowo 11 testów wydania (częściowo pokrywają się z pełnym przebiegiem),
  17 instalatora, 16 API CLI i cztery lifecycle JVM. Natywny prywatny
  Wayland oraz gotowy pakiet z pustym kontem i wyłączoną siecią PASS.
  [Dokładne polecenia, logi i naprawione próby](../evidence/signal/S12/README.md).
- **Pulpit:** puste okno Wiadomości otwarto/zamknięto bez zmiany PID bridge.
  Kontrolowany stop zakończył bridge; start przywrócił go pod nowym PID
  w tym samym cgroup. Caffeinate i sumy ustawień zachowane. Natywne IPC
  `signal status/openSettings/pair` nie eksportuje tożsamości, treści ani QR.
- **Telefon i poprawka live:** użytkownik zeskanował QR i wysłał wiadomość;
  baza potwierdziła `sent`, potem IPC `invalid_event`. Audyt rzeczywistych
  klas CLI ujawnił błędne akcje pisania w parserze/fixture. W 0.14.8 są
  `STARTED`/`STOPPED`; naprawione. Dodano test rzeczywistego serializatora
  JVM, regresję obu stanów bez historii oraz beztreściowe `eventErrorLocation`.
  Po aktualizacji konto `ready/linked`, brak błędów i brak ponownego skanu.
  Oryginalnego wadliwego eventu nie zapisano. Po aktualizacji odebrano nowe
  wiadomości przychodzące i własny sent sync przy stanie `ready`; scenariusz
  Notatki potwierdzono osobno poniżej; bezpośredni test pisania jest otwarty.
  71 testów domeny/wydania, nowe przypadki regresji i realny serializator
  PASS; 272 QML bez błędów.
- **Dokumentacja:** [OPERATIONS.md](OPERATIONS.md), kontrakt danych,
  API diagnostyki, plan testów i macierz live zaktualizowane. Signal Desktop
  i jego konfiguracja pozostały nietknięte. Aktualizacja zachowała dane konta.
- **Odbiór live:** [note-text.json](../evidence/signal/S12/note-text.json)
  dokumentuje tekst z telefonu do własnej Notatki i natywną wysyłkę testowej
  odpowiedzi z Putkina (`sent`). Użytkownik potwierdził widoczność na obu
  urządzeniach oraz reakcje i załączniki w rozmowie z drugą osobą
  ([user-acceptance.json](../evidence/signal/S12/user-acceptance.json)).
  Potwierdził także edycję widoczną na obu urządzeniach oraz Otwórz
  właściwą rozmowę i odpowiedź bez okna z powiadomienia.
  Dodatkowo potwierdził odczyt przez obserwowane zmiany statusu wiadomości,
  usuwanie wiadomości oraz rozmowy grupowe. Nie określił wszystkich trybów
  usuwania ani operacji administracyjnych w grupach.
  Reakcje są dostępne przez ⋯ w oknie rozmowy. Quick reply obsługuje tekst;
  dodawanie reakcji bezpośrednio z powiadomienia nie jest zaimplementowane.
  Nie powtarzano pliku do Notatki po potwierdzeniu załączników live.
  Agent wysyłał wyłącznie do własnej Notatki; dane rozmów nie trafiły do dowodów.
- **Pozostały zakres:** podstawowy odbiór zakończony. Do dalszej, rozszerzonej
  sesji odbioru potrzebne są wskazana grupa testowa i udział użytkownika
  przy próbach fizycznego sprzętu. Niewykonane pozostają pełne
  warianty prywatności receipts i read sync między urządzeniami,
  wszystkie tryby usuwania oraz znikanie,
  role grupowe, live akcenty w quick reply oraz fizyczny IME/audio,
  suspend/monitory i zasoby konta live. Część załącznikowa ma potwierdzenie
  użytkownika, bez pełnej specyfikacji formatów i kierunków. Wdrożenie
  S12 działa; pełna rozszerzona macierz odbioru pozostaje otwarta.

## S11 — Odporność, pełny odbiór i wydajność — 2026-09-21

- **Rezultat:** [macierz odbioru](ACCEPTANCE.md), połączony E2E wszystkich
  etapów na syntetycznym CLI, fault injection, prawdziwe okna i wejście na
  prywatnym Waylandzie, pomiary dużej historii oraz osobno prawdziwego JVM.
  Końcowy `scripts/test`: kod 0, wszystkie 23 runnery integracyjne PASS,
  w tym 9 Signala. Dwa wcześniejsze przebiegi ujawniły wyścigi fixture
  receipts i paneli; po poprawkach pełny zestaw PASS. Zachowano wszystkie logi.
- **Naprawy:** NotificationService odracza przeliczenie geometrii przy
  hotplug, aby nie odczytywać usuwanego QScreen. MessageHistory odpina model
  przed resetem podczas inkubacji delegatów. Test Audio czeka na pełny fade;
  oczekiwanie powodujące niestabilny wynik S10 zostało poprawione. Fixture wejścia
  mediów odpowiada bieżącemu kontraktowi composera i sprawdza prawdziwy IME.
  Runner receipts przenosi fokus dopiero po mapowaniu okna; poprzednio
  asynchroniczna aktywacja mogła unieważnić wcześniejsze przykrycie okna.
  Runner paneli czeka również na odroczone zniszczenie powierzchni po
  wyłączeniu loadera. scripts/test wypisuje kod zakończenia każdego runnera.
- **Pliki/interfejsy:** nowe scripts/test-signal-acceptance,
  signal-acceptance-test.qml, tests/signal_acceptance.py, signal_wayland.py,
  test_signal_reliability.py. Rozszerzone test-wayland (--signal),
  test-signal-process (--idle), signal_jvm_owner oraz media-input.qml/cpp.
  Poprawione scripts/test-signal-receipts i signal-receipts-test.qml.
  Bridge ma wyłącznie testowe, beztreściowe test.metrics za --test-scenario.
  Publiczny IPC v1, SQLite v7 i pin putkin-retention-2 pozostają bez zmian.
  Uzupełniono prawa wykonywania czterech helperów/nowego runnera.
- **Wyniki:** 202 Python PASS, 667 Qt PASS / 0 FAIL / 0 SKIP, 259 QML bez
  błędów. Natywny S11, wejście Qt/IME, 16 kontroli rzeczywistego API CLI,
  klasy polityki mediów/retencji i cztery próby lifecycle JVM: PASS.
  [Dokładne polecenia, logi i obejrzane zrzuty](../evidence/signal/S11/README.md).
- **Zasoby:** 10 000 wiadomości / 200 stron; strona mediana 10,04 ms,
  p95 13,11 ms. 60 s idle: QML 0,05 s CPU, bridge 0,00 s; stale cztery
  procesy, jeden receiver, QML timers 0, typing 0, jeden deadline retencji.
  20/20 okien zwolnionych, 8 delegatów przy 49/99 rekordach po redakcji,
  wzrost median RSS +2352 KiB przy budżecie 16 MiB. Rzeczywisty JVM bez
  konta osobno: 0,01 s CPU / 60 s, RSS 158 952 KiB bez wzrostu.
- **Zakres dowodów:** produkcyjne QML/SQLite/pipe, syntetyczne konta i
  prywatne XDG/D-Bus. Wayland z GPU: hjkl/Unicode, aktywne reply, fokus,
  dwa akcenty preview/cancel/save, małe/duże okno, skala 1,5, drugi monitor,
  hotplug, lock i hard reload. Brak pozostałych procesów w nowych runnerach.
  Fizyczny silnik IME nie jest zastąpiony przez test zdarzeń QInputMethodEvent.
- **Niewykonane:** telefon/serwer, wskazany rozmówca i grupa, fizyczny
  suspend/DPMS/monitory, portal/schowek sesji i odtwarzanie przez sprzęt,
  zasoby konta live, instalacja i rollback wydania. Granice ACK/COMMIT,
  unknown, skończonej retencji serwera, braku replay i usuwania danych są
  jawne w ACCEPTANCE; atrapy nie zaliczają poziomu live.
- **Następny krok:** wyłącznie
  [S12 — instalacja, aktywacja i telefon](../prompts/signal/12-release-activation.md).
  Najpierw pakiet z oboma przypiętymi jarami i plan rollbacku bez cofania
  danych; następnie staging/aktywacja i minimalny scenariusz live z ACCEPTANCE.
  S12 nie rozpoczęto, nie zmieniono aktywnego shella, nie wykonano commita.

## S10 — Grupy, kontakty i pełne rozpoczynanie rozmów — 2026-09-21

- **Rezultat:** nowa rozmowa po kontakcie, numerze lub username, profile i
  odświeżanie, katalog grup/zaproszeń, tworzenie z avatarem i dołączenie
  przez link. Szczegóły grupy obejmują role, członków/prośby, nazwę/opis,
  avatar, uprawnienia, link i opuszczenie z następcą ostatniego admina.
  Destrukcyjne akcje wskazują cel, z domyślnym fokusem Anuluj.
- **Tożsamości i model:** SQLite v7; directory_operations,
  conversation_preferences i directory_avatars. ACI/groupId pozostają
  kluczem mimo zmiany nazw/numerów. Trwały operationId przed RPC,
  sending → unknown po awarii/restartcie, częściowy wynik zachowuje ID,
  late result uzupełnia tę samą operację. Unknown create blokuje tworzenie;
  readback i jawny wybór istniejącej grupy bez automatycznego ponowienia.
- **Dostęp:** aktualne członkostwo/uprawnienia są sprawdzane przed dispatch.
  Utrata członkostwa wyłącza composer i odpowiedź ze starego powiadomienia.
  Nieznany nadawca pozostaje pending bez read/typing/reply do akceptacji.
  Block/unblock mają odczyt zwrotny; mute/hidden są wyłącznie lokalne,
  zachowują odbiór, zapis i unread. Snapshoty grup tworzą typowane zdarzenia
  systemowe bez body, autora, toasta ani wysyłki.
- **Interfejsy:** directory.refresh/profile/avatar, group.get/create/update/
  join/quit/operations/reconcile, conversation.accept/block/preferences.
  CLI listContacts/listGroups, getAvatar, updateGroup, joinGroup, quitGroup,
  sendMessageRequestResponse, block/unblock; audyt źródeł v0.14.8.
  Pin putkin-retention-2 i IPC v1 bez zmian. Cache avatara ma walidację,
  limit i cleanup; UI odświeża prezentację bez resetu historii i szkicu.
- **Pliki:** signal_directory.py, signal_groups.py, schema_v7.sql;
  account/store/backend/receipts, SignalMessagingAdapter/SignalBackend,
  SignalNotifications, NewConversation/ConversationDetails/MessagesView/
  MessageHistory, atrapy i testy Python/Qt. Nowy natywny runner
  test-signal-groups oraz signal-groups-test.qml; scripts/test włącza S10.
  Poprawiono propagację anulowania sendera/batcha odczytu przy wyłączeniu
  konta. Runner S04 po reloadzie czeka na rzeczywiście wyrenderowany widok.
- **Wyniki:** backend **197 PASS**, w tym **12** testów S10; bramka QML
  **258 plików, 0 błędów**. Pełny QtTest **666 PASS, 1 FAIL** (Audio,
  oczekiwanie na aktualizację modelu); osobne powtórzenie Audio **22 PASS**,
  celowane widoki wiadomości **58 PASS**. Natywny S10 i osiem wcześniejszych
  runnerów: końcowe PASS, brak błędów QML/osieroconych procesów.
  [Polecenia, logi, zrzuty i przebieg poprawek](../evidence/signal/S10/README.md).
- **Granice:** testy syntetyczne w prywatnych XDG/D-Bus, Qt offscreen.
  API nie eksportuje rewizji grupy/trybu akceptacji linku ani osobnego
  messageRequestResponse sync. Odczyt profileSharing/blokady potwierdza
  lokalny stan CLI, nie doręczenie do telefonu. Zdarzenia systemowe są
  różnicą obserwowanych snapshotów, nie pełnym audytem serwera.
  Live tworzenie/zaproszenia/role/linki/profile/blokada i synchronizacja
  wymagają telefonu oraz wskazanej grupy w S12. Bez wdrożenia i commita.
- **Następny krok:** wyłącznie [S11 — odporność i pełny odbiór](../prompts/signal/11-reliability-acceptance.md),
  na SQLite v7 i istniejącym pinie. Zbudować macierz ACCEPTANCE, sprawdzić
  pełny zestaw pod obciążeniem (w tym niestabilne oczekiwanie Audio),
  lifecycle/unknown/retencję i wydajność. S11 oraz S12 nie rozpoczęto.

## S09 — Usuwanie i wiadomości znikające — 2026-09-21

- **Rezultat:** „Usuń u mnie”, „Usuń u wszystkich” i czas znikania rozmowy.
  Odliczanie od wysłania / widocznego odczytu lub read sync, najwcześniejszy
  start, brak resetu po edycji/replay. Trwałe terminy, startup przed historią,
  jedno timerfd obsługujące deadline, resume i zmianę zegara.
- **Model:** SQLite v6; minimalne trwałe tombstones również przed celem,
  domknięcie grafu wersji, usunięcie body/wersji/reakcji/payloadów/cytatów.
  Lokalny delete znika z page i nie wysyła RPC. Remote delete we wspólnej
  kolejce z autorem, limitem 24 h, retry/unknown i sprawdzeniem przed dispatch.
- **Kopie:** oryginały, miniatury, staging i pliki CLI zwalniane po ostatniej
  referencji. Redakcja przerywa własny aktywny dekoder i odrzuca jego wynik.
  Zajęty edytor, cytat, podgląd i dokładna karta/historia powiadomień są
  czyszczone; stare odpowiedzi IPC nie odtwarzają treści. WAL truncation i
  startup GC wznawiają sprzątanie po błędzie/awarii. Brak backupu historii.
- **API i pin:** message.delete, conversation.expiration, message.redacted;
  CLI remoteDelete, updateContact.expiration, updateGroup.expiration.
  Nowe putkin-retention-2 eksportuje expirationStartTimestamp i rzeczywiste
  send.expiresInSeconds, poprawia Note-to-Self, usuwa stary resend log przy
  --disable-send-log. Pin obejmuje oba jary; źródła/hashe w dowodach.
- **Pliki:** signal_retention.py, schema_v6.sql, Store/Events/Receipts/Outbox/
  Mutations/Backend/Transport/Media; SignalMessagingAdapter, historia/widok,
  NotificationService/SignalNotifications; przypięte poprawki Java i builder;
  nowe testy Python/Qt/Java, runner test-signal-retention i probe natywny.
- **Wyniki:** pełny backend **128 PASS**, pełny QtTest **659 PASS, 0 FAIL/SKIP**;
  bramka QML **254 pliki, 0 błędów**. Celowana retencja/media **30 PASS**,
  akcje/podgląd Qt **8 PASS**, instalator **15 PASS**. Natywne runnery S09
  i regresja S07: PASS, bez błędów QML i osieroconych procesów. Poprawione
  rzeczywiste klasy JVM, build i próba pustego konta/RPC: PASS.
- **Odbiór:** rzeczywiste polecenia, logi i zrzut w
  [dowodach S09](../evidence/signal/S09/README.md). Testy syntetyczne,
  prywatne SQLite/XDG/D-Bus, Qt offscreen i JVM bez konta/sieci.
- **Granice:** view-once nadal niedostępny, „Usuń u mnie” tylko lokalne.
  Remote delete nie gwarantuje kasowania cudzych/wyeksportowanych kopii.
  Wyłączony shell nie sprząta o terminie; robi to przy starcie. Cofnięcie
  czasu zachowuje absolutną datę, może opóźnić jej osiągnięcie. Brak obietnicy
  forensic erase SSD/RAM/swap/snapshotów. Wyłączony resend log ogranicza
  automatyczną naprawę błędu odszyfrowania u odbiorcy. Telefon, prawdziwy
  suspend i kompozytor pozostają w S11/S12. Bez aktywacji i commita.
- **Następny krok:** wyłącznie [S10 — grupy i kontakty](../prompts/signal/10-groups-contacts.md),
  na SQLite v6 i obu nowych pinach. Zweryfikować członkostwo/uprawnienia,
  zdarzenia zmian kontaktów/grup i pełne rozpoczynanie rozmów. Zachować
  retencję oraz ograniczenia view-once i delete-for-me. Nie rozpoczęto S10.

## S08 — Reakcje, edycje, odpowiedzi i pisanie — 2026-09-21

- **Rezultat:** reakcje emoji z liczbą/osobami oraz zmianą/cofnięciem własnej,
  osobny edytor własnej wiadomości z Anuluj/Escape, cytaty z autorem i
  przejściem do oryginału, wzmianki ze znanych członków grupy i ulotne
  pisanie w oknie/quick reply. Zwykły szkic zachowuje tekst, pliki i trwałą
  kompozycję cytatu/wzmianek; edycja go nie nadpisuje.
- **Model:** SQLite v5, stały messageId i kolejność, graf timestampów
  wersji, odłożone zmiany z TTL, osobna tożsamość autora reakcji, stan
  mutacji w tej samej kolejce wysyłania. Receipts odnoszą się do wersji,
  edycja nie przejmuje read pierwotnej wersji ani nie resetuje expiry.
  Znani odbiorcy edycji grupowej są zapisywani osobno.
- **Interfejsy:** `message.edit`, `message.react`, rozszerzone message.send,
  draft composition i `typing.set/typing.changed`; IPC nadal v1. Rzeczywiste
  API to `send.editTimestamp`, `sendReaction`, quote/mention/textStyle oraz
  `sendTyping`. Nadal ten sam pin CLI **0.14.8 JVM + putkin-media-1**.
- **Pliki:** nowe signal_content/interactions/mutations/typing.py i
  signal_schema_v5.sql, MessageText.js, testy Python/Qt, osobny runner i
  probe. Rozszerzone Store/Outbox/receipts/Account/bridge, SignalBackend,
  SignalMessagingAdapter/ReplySession, MessageHistory/Composer, ustawienia
  oraz SignalNotifications. Widoki nie uruchamiają poleceń.
- **Wyniki:** pełny backend **111 PASS**, pełny QtTest **650 PASS, 0 FAIL/SKIP**;
  bramka QML **252 pliki, 0 błędów**. Natywny runner S08, regresja mediów
  S07 oraz odczytu S06: PASS, bez błędów QML i osieroconych procesów.
  Zestaw celowany interakcji: **19 PASS**. Faktyczne komendy i wyniki w
  [dowodach S08](../evidence/signal/S08/README.md).
- **Rzeczywiście odebrane lokalnie:** 1:1/grupa, odwrotne łańcuchy/duplikaty,
  sent sync z telefonu jako fixture, reakcje/edycje przed celem, autora
  odróżnionego od aktora, cytat bez starej historii, UTF-16/ZWJ, błąd/retry/
  unknown/cancel, szkic i pliki podpisu, konkretne RPC przez pipe i SQLite,
  powiadomienie po edycji/reakcji, 15 s typing expiry i hard reload bez
  ponownego wysłania. Klawiatura/fokus/akcenty sprawdzone przez QtTest.
- **Granice:** testy syntetyczne/offscreen, nie dowód działania telefonu.
  Telefon i rzeczywisty kompozytor pozostają S11/S12. Wskaźnik pisania ma
  **osobny lokalny przełącznik, domyślnie wyłączony**: przypięte API nie
  eksportuje ustawienia telefonu ani nie egzekwuje go w sendTypingMessage.
  Nie obiecujemy wspólnego przełącznika. Nie odtwarzamy edycji sprzed
  historii ani wcześniejszych placeholderów edit_unsupported. Limit edycji
  10/24 h liczony ze znanej historii; Notatka bez limitu czasu.
- **Następny krok:** S09, [usuwanie i znikanie](../prompts/signal/09-deletion-expiration.md).
  Najpierw zamknąć lukę `expirationStartTimestamp` i zaktualizować pin API.
  Retencją objąć też nowe wersje, cytaty/kompozycję i mutacje inflight,
  poza mediami/powiadomieniami z S07. Nie rozpoczęto realizacji S09.

## S07 — Media i załączniki — 2026-09-21

- **Rezultat:** tekst z kilkoma plikami lub same załączniki, usuwalne
  elementy kompozycji, miniatury i obraz z zachowaniem proporcji. Podgląd
  ma zamknięty obieg Tab/Shift+Tab, Escape, powrót fokusu i żywe oba akcenty.
  Qt Multimedia obsługuje dostępne kodeki audio/wideo; błędy dekodera są
  jawne, oryginał pozostaje do zapisu. Quick reply nadal jest tekstowy.
- **Backend:** nowe `signal_media.py`, `signal_schema_v4.sql`, zmiany
  Store/Events/Outbox/bridge i schematu SignalBackend. IPC
  `attachment.stage/paste/remove/save/open`; `message.send` przyjmuje
  `attachmentIds`, CLI dostaje `attachment: [ścieżki]`. Schemat v4 dodaje
  `media_files`, `draft_attachments` oraz `media_cli_gc` z triggerem.
  Atomowy transfer własności szkic → outbox, fsync przed COMMIT,
  post-commit/startup cleanup. Deduplikacja sent sync przed i po RPC
  zachowuje ID i sprząta także zmieniony identyfikator pliku CLI.
- **Pliki i limity:** 32 MiB/plik, 8 plików i 128 MiB/kompozycję,
  512 MiB kontrolowanego magazynu. Staging, oryginały, miniatury i eksport
  mają osobną własność. NOFOLLOW na każdym poziomie, regularny plik,
  kontrola MIME, uprawnień, zmiany źródła, hardlinków i nazw. Worker
  poza UI: 12 s, 1 GiB pamięci adresowej, 20 MP i ograniczony wynik.
  Referencje chronią współdzielone kopie; ostatnie usunięcie uruchamia GC.
  Pending/busy bez procentów, których CLI nie dostarcza.
- **CLI:** nowe `services/signal-cli-media/`, `build-signal-media-cli`
  i `test-signal-media-cli`. Zweryfikowane źródła v0.14.8, oddzielny build
  i pin biblioteki SHA-256; bez zmiany oryginalnej dystrybucji.
  Pobranie ≤32 MiB, limit transferu zaszyfrowanego 40 MiB, cache CLI
  ≤512 MiB, prywatny temp. View-once/expiring pomijają pobranie jeszcze
  przed JSON w obu kierunkach. Wyłączone niezarządzane preview/avatary
  kontaktów/miniatury cytatów. Runtime odmawia innej biblioteki przez
  `media_policy_required`. Brak eksportu początku retencji nadal jest S09.
- **UI i powiadomienia:** `AttachmentCard.qml`, `MediaPreview.qml`,
  kompozytor/historia/widok, SignalMessagingAdapter/Service,
  SignalNotifications i NotificationService. Miniatura powiadomienia
  jest tą samą pochodną; blokada/reset/usunięcie wygaszają referencję.
  Podgląd zatrzymuje odczyt historii. Widoki nie uruchamiają poleceń.
- **Testy:** nowe Python/QtTest, syntetyczne PNG/H.264/WAV/TXT,
  `signal-media-test.qml`, runner `test-signal-media` w scripts/test,
  natywne zdarzenia drop/FileDialog w `test-signal-media-input`, Java
  test rzeczywistej poprawionej metody odbioru. Zmiany fixture migracji
  i atrapy send, kontrola schematu integracji, ustabilizowany pomiar
  viewportu runnera S06 przed zachowanymi asercjami.

| Odbiór | Wynik / dowód |
| --- | --- |
| Składnia/importy | **PASS**, 250 QML — [check.log](../evidence/signal/S07/check.log) |
| Pełny backend Signal po końcowych zmianach | **PASS**, 92 testy — [python-final.log](../evidence/signal/S07/python-final.log) |
| Pełna regresja QML | **PASS**, 642 wyniki, 0 FAIL/SKIP — [all-qml.log](../evidence/signal/S07/all-qml.log) |
| Końcowy fokus, media, oba akcenty i dekoder Qt | **PASS**, 6 wyników — [media-controls-final.log](../evidence/signal/S07/media-controls-final.log) |
| Natywne okno/SQLite/outbox/reload z atrapą CLI | **PASS** — [media-qml.json](../evidence/signal/S07/media-qml.json), [kompozycja](../evidence/signal/S07/composer.png), [podgląd](../evidence/signal/S07/image-preview.png) |
| Natywne drop i callback wyboru FileDialog | **PASS** — [media-input.log](../evidence/signal/S07/media-input.log) |
| Poprawione klasy CLI, bez sieci/konta | **PASS** — [build](../evidence/signal/S07/cli-build.log), [polityka](../evidence/signal/S07/cli-policy-tests.log), [JVM/RPC](../evidence/signal/S07/cli-probe.json) |
| Regresja S05/S06 i lifecycle | **PASS** — [powiadomienia](../evidence/signal/S07/notifications-regression.json), [odczyt](../evidence/signal/S07/receipts-regression.json), [idle/reload/cleanup](../evidence/signal/S07/lifecycle-idle.json) |
| Instalator w prywatnych katalogach | **PASS**, 15 testów — [install-tests.log](../evidence/signal/S07/install-tests.log) |

**Granice odbioru:** syntetyczne transporty i prywatne XDG/D-Bus/offscreen;
bez konta, telefonu, prawdziwego schowka Waylanda, portalu wyboru i
fizycznego wyjścia audio. Qt odtworzył H.264, odczytał metadane PCM/WAV;
nie jest to obietnica każdego kodeka. Plik audio nie oznacza nagrywania
voice notes. S12 musi dostarczyć poprawioną dystrybucję/JRE oraz
`file`, `ffprobe`, `ffmpeg`, `prlimit`, Qt Multimedia i `wl-paste`.
Nazwy oryginalne są zachowane lokalnie; CLI wysyła kontrolowaną nazwę
UUID.ext, więc odbiorca nie dostaje jeszcze pierwotnej nazwy dokumentu.
Deduplikacja mediów pod dokładnym kluczem wiadomości sprawdza metadane,
nie hash bajtów (API go nie eksportuje). Brak lazy fetch/getAttachment
z serwera. View-once i expiring pozostają jawnymi placeholderami.

[Pełne dowody, komendy i początkowe błędy](../evidence/signal/S07/README.md).
Bez commita i aktywacji pulpitu. **Dokładny następny krok — S08:**
[reakcje, edycje, odpowiedzi i wskaźnik pisania](../prompts/signal/08-reactions-edits-quotes.md),
z zachowaniem pinów CLI, bez aktywacji i bez rozpoczynania S09.

## S06 — Raporty i odczyt między urządzeniami — 2026-09-20

- **Rezultat:** sent → delivered → read → viewed bez cofania stanu.
  Grupy mają liczniki per odbiorca; failed/unknown/pending pozostają
  odróżnione. Material check/send, tekstowe statusy i Accessible.name,
  dotychczasowe Mocha/gradient/fade. Wspólny unread zasila pasek i listę.
- **Backend:** nowy `services/signal_receipts.py`, `signal_schema_v3.sql`;
  zmienione Store, event normalizer, Outbox, Account i dispatcher/worker
  bridge oraz akceptowany schemat SignalBackend. Migracja 2→3 zachowuje
  stabilne ID/outbox/szkice, przejmuje pending S02 i usuwa je z dawnej tabeli.
  Konto, własny autor, odbiorca i kierunek są częścią dopasowania receipt.
  Przetwarzane są także potwierdzenia przed message/RPC oraz wiele timestampów.
- **Interfejsy:** IPC `messages.read(accountId,conversationId,messageIds)`
  i zdarzenie `message.read` po COMMIT. Rekordy dodają unread/readAtMs,
  receiptSummary i osobne czasy każdego odbiorcy. CLI `sendReceipt`:
  recipient:string, targetTimestamp:[integer], type:read, account.
  Jedna kolejka modyfikacji bridge, batch ≤100 po autorze.
- **Widoczność:** MessagesWindow używa faktycznego Qt Window.active,
  visible/minimized, controller.interactive/blocked i ukończonego fade.
  MessagesView przekazuje stan do historii; MessageHistory sprawdza pozycje
  delegatów, stabilny viewport przez 250 ms i konkretny ID. Brak RPC dla
  cache poza ekranem, samej selekcji, tworzenia rozmowy, przewijania,
  centrum, quick reply czy blokady. Większy niż viewport bąbelek odczytuje
  się przy widocznym końcu. Zwykłe bąbelki muszą mieścić się w pionie.
- **Powiadomienia:** SignalNotifications i NotificationService wygaszają
  dokładną kartę messageId. Starszy read nie zamyka nowszej karty.
  Read podczas oczekiwania na IPC nie pozwala odtworzyć nieaktualnego toasta.
  Centrum zachowuje treść/routing. Przychodzący zapis po wcześniejszym
  read sync nie generuje nowego powiadomienia.
- **Testy:** `test_signal_receipts.py`, `tst_signal_receipts.qml`,
  dwa przypadki w `tst_signal_notifications.qml`, rozszerzony test czyszczenia
  S03, nowy `signal-receipts-test.qml` i `scripts/test-signal-receipts`
  w scripts/test. Atrapa CLI waliduje prawdziwy kształt sendReceipt;
  MockMessagingBackend obsługuje lokalne odczyty. Zaktualizowano asercje
  schematu oraz fixture wcześniejszej migracji.

| Odbiór | Wynik / dowód |
| --- | --- |
| Składnia/importy | **PASS**, 245 QML — [check-final.log](../evidence/signal/S06/check-final.log) |
| Pełny backend Signal | **PASS**, 77 testów — [python-tests.log](../evidence/signal/S06/python-tests.log) |
| Końcowy reducer/RPC/cleanup | **PASS**, 18 testów, w tym 2 dodatkowe po pełnym zestawie — [receipts-final.log](../evidence/signal/S06/receipts-final.log) |
| Widoczny zakres i statusy; renderowane powiadomienia | **PASS**, 6 + 12 wyników — [receipts-qml-final.log](../evidence/signal/S06/receipts-qml-final.log), [notifications-qml.log](../evidence/signal/S06/notifications-qml.log) |
| Cała regresja QML | **PASS**, 636 wyników, 0 FAIL/SKIP — [qml-tests.log](../evidence/signal/S06/qml-tests.log) |
| Natywne okna Qt/SQLite/bridge, atrapa CLI | **PASS** — [receipts.json](../evidence/signal/S06/receipts.json), [log](../evidence/signal/S06/receipts.log), [widok](../evidence/signal/S06/receipts.png) |
| Transport, reload, cleanup, idle | **PASS**, 60 s, 0 ticków CPU/RPC/nowych procesów — [integration.json](../evidence/signal/S06/integration.json) |
| Regresja okna i powiadomień | **PASS** — [S04](../evidence/signal/S06/messages-regression.json), [S05](../evidence/signal/S06/notifications-regression.json), [zewnętrzny D-Bus](../evidence/signal/S06/external-notifications.json) |
| Instalator/pakowanie | **PASS**, 15 testów w prywatnych katalogach — [install-tests-final.log](../evidence/signal/S06/install-tests-final.log) |

**Ograniczenia:** źródła przypiętego CLI potwierdzają oddzielny self-sync
przy wyłączonych zewnętrznych receipts; atrapa sprawdza parametry/puste
results, **nie dostarczenie do telefonu**. Submitted kolejki read oznacza
odpowiedź CLI, self-sync nie ma osobnego ACK; unknown po awarii zachowuje
lokalny marker bez automatycznego ponowienia. Bez ACI odczyt jest lokalny.
Sent sync 0.14.8 pomija odbiorców grupy i viewed sync: dla takiej grupy
total=null, brak obietnicy pełnych statusów innych urządzeń. Brak read
nie znaczy „nie przeczytał”. Nie zmieniano prywatności ani flag daemona.
Placeholdery retencji pozostają S09. Faktyczny Hyprland/DPMS i macierz
telefon ↔ komputer z obiema prywatnościami pozostają S11/S12.

Pierwszy fixture migracji, niewyrenderowane karty w teście Qt oraz blokada
socketu D-Bus dały negatywne wyniki; przyczyny, poprawki i logi są jawne
w [raporcie S06](../evidence/signal/S06/README.md). Końcowe zestawy przeszły.
Bez commita, konta live i wdrożenia.

**Dokładny następny krok — S07:** wykonać
[media i załączniki](../prompts/signal/07-media-attachments.md) na SQLite v3,
istniejących statusach i kolejce. Najpierw zweryfikować ograniczenia
`--ignore-attachments`/getAttachment, limity zasobów oraz view-once;
nie deklarować pobierania na żądanie z samego lokalnego getAttachment.
Uwzględnić czyszczenie referencji i kopii w powiadomieniach. Retencja i brak
expirationStartTimestamp nadal wymagają rozwiązania w S09 przed S12.
Nie aktywować integracji na pulpicie.

## S05 — Powiadomienia i quick reply — 2026-09-20

- **Rezultat:** Otwórz/Odpowiedz w toastcie i w sesyjnym centrum,
  dzwonek lokalnego wyciszenia rozmowy. Edytor ma Enter/Shift+Enter,
  literowe hjkl, blokadę kompozycji i podwójnego send. Mocha, wspólny
  gradient, kwadratowe ramki, fade, podgląd/zapis/anulowanie akcentów.
- **Koordynacja:** nowy `core/SignalNotifications.qml`,
  `services/SignalReplySession.qml`, `modules/notifications/NotificationReply.qml`.
  Zmieniono LocalNotification/NotificationService/Entry, karty, centrum,
  stos, NotificationWindows i NotificationFocus oraz rejestracje/shell.
  Jeden dotychczasowy serwer; zewnętrzne inlineReplySupported nadal false.
- **Dane:** `signal_schema_v2.sql`, `signal_replies.py`, zmiany Store,
  outboxu, dispatchera, czyszczenia historii i akceptowanego schematu QML.
  IPC v1, SQLite v2; reply.draft.get/set, conversation.notifications,
  message.send z draftContext=quickReply oraz message.received po COMMIT.
  Szkic pełnego okna pozostaje osobny. Reply wiąże się atomowo z outboxem;
  tekst po enqueue ma jednego właściciela w messages.
- **Polityka:** jeden wpis/toast na rozmowę, maks. 100 w historii.
  Scalanie 120 ms, sekwencyjne odczyty i do 3 nowych toastów na 2 s.
  Nadejście nie zabiera fokusu. DND/wyciszenie/lock tłumią zwykły Signal.
  Odbiór przy blokadzie nadal działa, UI ukrywa treść i wyłącza akcje.
  Odblokowanie odczytuje bieżące dane, bez replay toastów.
- **Routing/retencja:** archiwum zawiera tylko deskryptor
  service/account/conversation/message, bez martwych akcji. Aktywna usługa
  rozwiązuje go ponownie; odłączenie i brak rozmowy wyłączają akcje.
  Zmiany/usunięcia odświeżają archiwum; fade nie kopiuje treści.
  Sent sync i techniczne eventy nie tworzą toastów. Akcje centrum nie
  wysyłają receipts ani nie zmniejszają unread rozmów (S06).
- **Testy:** nowe `test_signal_notifications.py`,
  `tst_signal_notifications.qml`, `signal-notifications-test.qml`,
  `scripts/test-signal-notifications` (dodany do scripts/test).
  Rozszerzono MockMessagingBackend i test kasowania historii S03;
  wcześniejsze asercje schematu zaktualizowano do 2.

| Odbiór | Faktyczny wynik / dowód |
| --- | --- |
| Składnia/importy | **PASS**, 243 QML — [check-final.log](../evidence/signal/S05/check-final.log); końcowy null guard [focus-check.log](../evidence/signal/S05/focus-check.log) |
| Backend Signala | **PASS**, 62 testy — [python-tests.log](../evidence/signal/S05/python-tests.log) |
| Usunięcie historii z nowym szkicem/wyciszeniem | **PASS**, dodatkowy test — [history-clear-tests.log](../evidence/signal/S05/history-clear-tests.log) |
| Karty, reply i klawiatura z atrapą | **PASS**, 10 wyników — [signal-notifications-final.log](../evidence/signal/S05/signal-notifications-final.log) |
| Cała regresja QML | **PASS**, 628 wyników, 0 FAIL/SKIP — [qml-tests-final.log](../evidence/signal/S05/qml-tests-final.log) |
| Produkcyjne QML/SQLite/bridge z atrapą CLI | **PASS** — [notifications.json](../evidence/signal/S05/notifications.json), [log](../evidence/signal/S05/notifications.log); routing S04, zamknięte okno, reply, replacement, lock/DND, wielokrotny reload i unknown bez drugiego send |
| Zewnętrzny protokół powiadomień | **PASS** — [external-notifications.json](../evidence/signal/S05/external-notifications.json); 13 scenariuszy, 20 lifecycle, brak osieroconych procesów |
| Okno wiadomości S04 | **PASS** — [messages-regression.json](../evidence/signal/S05/messages-regression.json); 65 przychodzących, strony 50+16, szkic i reload |
| Pakowanie/instalator | **PASS**, 15 testów — [install-tests.log](../evidence/signal/S05/install-tests.log); prywatne katalogi, bez aktywacji |

Widok: [odpowiedź](../evidence/signal/S05/notifications-reply.png),
[unknown](../evidence/signal/S05/notifications-unknown.png).

**Granice:** wszystko syntetyczne, XDG/D-Bus prywatne, okna offscreen.
Brak telefonu i serwera Signala. Fizyczny fokus OnDemand/grab, kompozytor,
hotplug i silnik IME pozostają S11/S12; QtTest sprawdza ich kontrolery
i warunek preedit, nie deklaruje odbioru urządzeń. Pełne odczyty S06,
media S07, edycje S08 i retencja S09 pozostają osobnymi etapami.
Wyciszenie dotyczy Putkina, nie synchronizuje ustawień innych urządzeń.
Signal Desktop może równolegle pokazać własną kartę; jego powiadomień
i autostartu nie zmieniano. Brak commita i wdrożenia.

W testach znaleziono i naprawiono wyścigi nowszego message.received
z odświeżeniem starej karty, load szkicu z pisaniem oraz krótkie okno
powtórnego send przed oczyszczeniem tekstu. Pierwsza pełna regresja QML
ujawniła null service w dawnych podglądach: wynik 439 PASS / 189 FAIL
zachowano w [qml-tests.log](../evidence/signal/S05/qml-tests.log), nie jest
wynikiem pozytywnym. Dodano guard i ponowiono pełny zestaw.
Pierwszy D-Bus w sandboxie był zablokowany; dalsze testy dostały dostęp
do lokalnego socketu, zachowując izolację. Dopuszczone komunikaty masks
offscreen i celowego braku obserwatora w negatywnym teście są jawnie
opisane w raportach; nie pomijano innych ostrzeżeń.

**Dokładny następny krok — S06:** wykonać
[dostarczenie, odczyt i stan między urządzeniami](../prompts/signal/06-receipts-read-state.md)
na istniejącym outboxie/historii, API przypiętego CLI i wspólnym oknie.
Read oznacza wiadomość widoczną w aktywnej rozmowie; nie używać
NotificationService.markAllRead ani zamykania/odpowiedzi karty jako receipt.
Uwzględnić schemaVersion 2 i odświeżać kopie powiadomień przez aktualny
deskryptor. Nie aktywować integracji przed S12.

## S04 — Okno wiadomości, tekst i nowa rozmowa — 2026-09-20

- **Stan:** implementacja i syntetyczny odbiór zakończone. Wdrożona tylko
  integracja Signala; wspólny interfejs gotowy na przyszły adapter BlueFerry,
  bez systemu wtyczek. Bez zmian aktywnego pulpitu i podłączania konta.
- **Widoczny rezultat:** osobne okno „Wiadomości”, lista z nazwami/numerami,
  grupy z autorami, historia po 50 wpisów z dniami/czasem/kierunkiem,
  edytor Enter/Shift+Enter i nowa rozmowa z kontaktu/numeru/nazwy użytkownika.
  Poniżej 680 px lista i szczegóły są osobne. Mocha, kwadratowe ramki,
  jeden gradient, fade i wspólne ikony add/send z katalogu Google.
- **Wejścia:** Material `chat_bubble/chat` na pasku, działanie `messages`,
  domyślna komenda launchera `:messages` i IPC `messages open` oraz
  `messages openConversation signal ACCOUNT_UUID CONVERSATION_UUID`.
  Bez nowego globalnego skrótu; migracja zachowuje komendy użytkownika.
- **Kod wspólny:** `core/ConversationRoute.js`, `MessageHub.qml`,
  `MessagesController.qml`, `MessagesFocus.qml`, `services/MessagesIpc.qml`,
  `modules/messages/{MessagesWindow,MessagesView,MessageHistory,MessageComposer}.qml`.
  Jawny adapter `services/SignalMessagingAdapter.qml` scala model i zdarzenia
  starej usługi. Shell wyłącznie łączy instancje. Zmiany w pasku, Actions,
  ActionController, qmldir i dwóch zasobach Material.
- **Backend:** dodatkowe conversation.get i recipient.resolve (IPC/schema
  nadal v1). Lookup getUserStatus nie wywołuje send; pusty czat istnieje
  przed pierwszą wysyłką. Modele biorą nazwy/uprawnienia z katalogu CLI.
  Bridge odrzuca obce konto, niedostępną rozmowę i brak prawa wysyłania;
  preflight ponownie sprawdza blokadę, członkostwo, admin-only i retencję.
- **Trwałość/race:** CAS szkicu, scalenie szybkiego pisania, enqueue z UUID
  i draftRevision. Brak automatycznej ponownej wysyłki unknown. Zmiana
  selekcji odrzuca stare odpowiedzi i czyści poprzedni widok. Zdarzenia
  wiadomości mają kolejkę odświeżania, by seria nie przeciążała IPC.
  Kotwica przewijania zachowuje ID/przesunięcie, statusy nie udają delivered.
- **Lifecycle:** jeden LazyLoader, właściwy monitor dla nowego okna,
  przywołanie istniejącego po PID/tytule, hotplug i zamknięcie przy lock.
  Odbiór i zapis nie zależą od widoku; hard reload odzyskuje historię/szkic.
- **Testy/dowody:** [S04](../evidence/signal/S04/README.md),
  [duże okno](../evidence/signal/S04/messages-wide.png),
  [320×300](../evidence/signal/S04/messages-small.png).
  Nowe `test_signal_messages.py`, `tst_messages.qml`,
  `tst_messages_controller.qml`, `MockMessagingBackend.qml`,
  `signal-messages-test.qml`, `scripts/test-signal-messages`.
  Runner jest w scripts/test; limit pełnej regresji Qt zwiększony do 600 s
  zgodnie z faktycznym czasem istniejącego zestawu (>260 s).

| Odbiór | Wynik i dowód |
| --- | --- |
| Składnia/importy | **PASS**, 238 QML — [check.log](../evidence/signal/S04/check.log); końcowe zmiany dodatkowo [check-final.log](../evidence/signal/S04/check-final.log) i [controller-check.log](../evidence/signal/S04/controller-check.log) |
| Backend Signala | **PASS**, 56 testów — [python-tests.log](../evidence/signal/S04/python-tests.log) |
| Cała regresja QML | **PASS**, 616 wyników, 0 FAIL/SKIP — [qml-tests.log](../evidence/signal/S04/qml-tests.log) |
| Końcowy UI i routing/pasek | **PASS**, 9 + 6 wyników — [messages-tests.log](../evidence/signal/S04/messages-tests.log), [controller-tests.log](../evidence/signal/S04/controller-tests.log) |
| Natywne okno + prawdziwy bridge/SQLite + atrapa CLI | **PASS** — [messages.json](../evidence/signal/S04/messages.json), [log](../evidence/signal/S04/messages.log); 65 wiadomości przy zamkniętym oknie, strony 50+16, dwie drogi wejścia, restart i szkic |
| Regresja transportu/reload/cleanup | **PASS** — [integration.json](../evidence/signal/S04/integration.json); próbka idle 2 s, 0 ticków/RPC/nowych procesów, brak osieroconych PID |
| Regresja parowania | **PASS** — [pairing.json](../evidence/signal/S04/pairing.json); QR pozostaje w pamięci |
| Instalator/pakowanie | **PASS**, 15 testów w prywatnych katalogach — [install-tests.log](../evidence/signal/S04/install-tests.log) |

**Granice:** test natywny jest offscreen, konto/CLI są syntetyczne.
Wybór dwóch monitorów, przywołanie po PID i hotplug sprawdzono na jawnych
atrapach kontrolera, bez fizycznego kompozytora. Test Enter/preedit sprawdza
warunek handlera kompozycji; sesja z rzeczywistym silnikiem IME pozostaje
w S11/S12. Unicode zachowuje treść, ale lokalna instalacja fontów nie ma
japońskich glifów (widoczne brakujące znaki w syntetycznych PNG).
Nie instalowano fontów. Kontakty/grupy korzystają z obecnego katalogu;
pełne zarządzanie i zaproszenia należą do S10.

Licznik wynika z otrzymanych wiadomości, **nie jest zmniejszany po
otwarciu**: model read/read-sync należy do S06. Nie dodano powiadomień
wiadomości ani quick reply (S05), mediów (S07) czy odczytów. Znikające
wiadomości pozostają objęte dotychczasową blokadą retencji do S09.

**Dokładny następny krok — S05:** wykonać
[prompt powiadomień](../prompts/signal/05-notifications-quick-reply.md).
NotificationService powinien przechowywać pełny adres
`{serviceId, accountId, conversationId}` i przekazać go do istniejącego
MessagesController. Quick reply używa tej samej usługi/outboxu i rewizji
szkicu. Nie wyprowadzać odbiorcy z tytułu i nie dodawać drugiej usługi.

## S03 — Parowanie konta i ustawienia — 2026-09-20

- **Stan:** ukończony w zakresie implementacji i syntetycznego odbioru S03.
  Bez skanu telefonu, rzeczywistego konta i aktywacji pulpitu.
- **Widoczny rezultat:** trzecia sekcja Signal w SettingsWindow, nazwa
  urządzenia, QR z CLI, Połącz/Anuluj/Odnów, sprawdzenie połączenia,
  włączenie/wyłączenie lokalnego odbioru, rozwijane ścieżki narzędzi
  i osobna akcja „Usuń lokalną historię Putkina”. Własne błędy trafiają
  do istniejących ErrorNotifications jako stałe teksty, bez payloadów CLI.
- **Kod:** nowe `services/signal_account.py`, `signal_qr.py`,
  `modules/settings/SignalSettings.qml`, `SignalQr.qml`,
  `preview/MockSignalBackend.qml`, `signal-pairing-test.qml`,
  `scripts/test-signal-pairing`, `tests/test_signal_pairing.py`,
  `tests/signal_qr_decode.py`, `tests/qml/tst_signal_settings.qml`.
  Zmieniono SignalBackend/Service, backend Python i zapis konfiguracji,
  jawne przekazywanie serwisu przez PanelHost/PanelSurface/SettingsView,
  shell, qmldir, atrapę CLI, test capabilities oraz runner scripts/test.
  `scripts/test-icons` przyjmuje opcjonalny dodatni --timeout.
- **Kontrakt:** IPC v1 i schemaVersion 1; account.configure,
  account.link.start/cancel, account.refresh/directory/history.clear.
  Konfiguracja v1 dodaje deviceName. libqrencode 4.1.1 generuje QR w RAM;
  Canvas nie korzysta z plików i cache Image. URI nie trafia do QML,
  logów, konfiguracji, historii ani artefaktów. Macierz nie wychodzi
  przez ogólny sygnał SignalService.changed.
- **Lifecycle:** jedna próba i termin 120 s, brak ślepego ponawiania
  finishLink. Cancel/timeout kończy CLI przed nowym listAccounts;
  zapisane konto jest rekoncyliowane również po utracie odpowiedzi.
  Awaria bridge podczas QR czyści widok i pozwala uruchomić usługę
  ponownie z ustawień. Zamknięcie połączonego okna nie kończy odbioru.
- **Metadane:** po potwierdzeniu ACI i gotowej bazie subscribeReceive,
  żądanie sync i dostępny katalog kontaktów/profili/grup. Zdarzenia
  CONTACTS_SYNC/GROUPS_SYNC odświeżają cache bez okresowego timera.
  Nie utworzono fikcyjnych rozmów ani importu dawnych wiadomości.
- **Odłączenie:** lokalny stop jest trwałą konfiguracją, zachowuje konto
  i historię. Cofnięcie upoważnienia należy do telefonu; brak managera
  jest wykrywany przy odświeżeniu, przed wysłaniem i restarcie. Błędy
  transportu zachowują linked. Usunięcie historii wymaga disabled,
  osobnego potwierdzenia i checkpoint WAL; klucze CLI zostają.

| Kryterium | Faktyczny wynik i dowód |
| --- | --- |
| Składnia/importy | **PASS**, 225 QML — [check.log](../evidence/signal/S03/check.log). |
| Proces, historia, outbox i nowe parowanie | **PASS**, 52 testy Python — [python-tests.log](../evidence/signal/S03/python-tests.log). |
| QR dokładnie odtwarza URI | **PASS**, niezależny ZXing dekoduje libqrencode, bez zapisu QR/URI; w zestawie 10 testów S03 — [pairing-tests.log](../evidence/signal/S03/pairing-tests.log). |
| Sukces/cancel/timeout/restart/revocation/offline/config | **PASS**, realne procesy, pliki i SQLite z jawną atrapą; ten sam log S03. Brak biblioteki QR, CLI i wielu kont mają testy negatywne. |
| Natywne ustawienia, odzyskanie po SIGKILL i cleanup | **PASS** — [pairing.json](../evidence/signal/S03/pairing.json), [log](../evidence/signal/S03/pairing.log), [podgląd bez QR](../evidence/signal/S03/pairing.png). |
| Klawiatura, QR w pamięci, oba akcenty preview/save/cancel | **PASS**, 11 wyników QtTest po końcowej poprawce awarii/expiry — [signal-settings-final.log](../evidence/signal/S03/signal-settings-final.log). |
| Regresja QML całego projektu | **PASS**, 601 wyników, bez błędów i pominięć — [qml-tests-final.log](../evidence/signal/S03/qml-tests-final.log). Po końcowej poprawce stanu próby powtórzono testy Signala i natywny runner powyżej. |
| Historia/outbox, reload i idle | **PASS**, 60 s, 0 ticków CPU obu pomocników, 0 nowych procesów/RPC, brak osieroconych PID — [integration.json](../evidence/signal/S03/integration.json). |
| Instalator | **PASS**, 15 testów wyłącznie w prywatnych katalogach — [install-tests.log](../evidence/signal/S03/install-tests.log). |
| Prawdziwy telefon/serwer, cofnięcie powiązania live, Note to Self | **Niewykonane**, jawny odbiór S12. |

Komendy, zależności i izolacja: [TESTING.md](TESTING.md#parowanie-i-ustawienia-po-s03).
Pierwszy QtTest w sandboxie nie mógł utworzyć prywatnego socketu D-Bus;
uruchomiono ten sam runner z dozwolonym socketem, bez usuwania izolacji.
Pierwszy pełny zestaw QML zakończył limit 240 s po zielonych testach;
ponowienie z limitem 600 s przeszło w około 256 s. Poprzedni log zachowano
jako timeout, nie wynik pozytywny. Dokładny znany komunikat platformy
offscreen o maskach okien jest jedynym dopuszczonym ostrzeżeniem natywnego
runnera. Nie wykonywano drugiego pełnego shella na D-Bus hosta.

**Granica API:** 0.14.8 nie eksportuje eventu websocket/auth. UI nie
obiecuje natychmiastowego wykrywania cofnięcia powiązania w bezczynności
ani potwierdzenia łączności serwerowej przez sam stan ready. Sprawdzenie
listAccounts jest lokalne i zdarzeniowe; źródła i uzasadnienie w
[API.md](API.md#ipc-konta-i-parowania--s03). Pełne metadane grup/kontaktów
i ich zarządzanie pozostają S10, media S07, retencja S09.

**Dokładny następny krok — S04:** wykonać
[okno rozmów, tekst i nową rozmowę](../prompts/signal/04-conversations-window.md)
na istniejącym SignalService, historii SQLite i wspólnym outboxie.
Jeden leniwie tworzony FloatingWindow, routing rozmowy, listy/strony,
szkic, klawiatura/IME i wyjście bez zatrzymania odbioru. Nie wdrażać
niekompletnej integracji do codziennego konta przed S12.

## S02 — Historia, synchronizacja i kolejka wysyłania — 2026-09-20

- **Stan:** ukończony w zakresie S02; konto, parowanie i aktywacja niewykonane.
- **Rezultat:** trwała wspólna historia incoming / sent sync / lokalnego
  tekstu, poprawne strony rozmów, deduplikacja, szkice z kontrolą rewizji
  oraz jedna kolejka dla przyszłego okna i quick reply. Reload/restart
  zachowuje stabilne ID i wynik operacji. Nie dodano widoku rozmów z S04.
- **Kod:** nowe `signal_schema.sql`, `signal_store.py`, `signal_events.py`,
  `signal_outbox.py`, wydzielone `signal_paths.py`. Zmiany w
  `signal_backend.py`, `signal_transport.py`, `SignalBackend.qml`,
  `SignalService.qml`, `signal-test.qml`, runnerze QML i peerze testowym.
  Nowe `test_signal_history.py` oraz `signal_store_crash.py`; testy S01
  uwzględniają produkcyjną subskrypcję dopiero po gotowości bazy.
- **Magazyn:** SQLite v1, atomowa migracja, indeksy i keyset pagination,
  WAL/FULL, 0700/0600, odrzucenie obcych linków i nowszego schematu.
  COMMIT poprzedza zdarzenia UI. Usunięcie treści wymaga także checkpoint
  WAL; jego niepowodzenie zatrzymuje domenę. Cleanup działa przy starcie,
  odczycie/odbiorze i przez pojedynczy termin, bez okresowego pollingu.
- **Tożsamość:** konto według ACI z CLI, własne UUID konta/rozmów/wiadomości,
  klucz autora+rozmowy+czasu, osobne ACI/PNI i nierozstrzygnięty numer.
  Grupa ma groupId, sent sync ma odbiorcę, Notatka jest osobnym rodzajem.
  Różny payload jednego klucza daje conflict bez cichego nadpisania.
- **Outbox:** queued/sending/sent/failed/unknown/cancelled, próby i wyniki
  per odbiorca, lokalnie idempotentny operationId, odmowa retry unknown
  i częściowego sukcesu, jawne retry jednoznacznej odmowy. Timeout 60 s
  pozostawia unknown; późna odpowiedź rozstrzyga tę samą próbę.
  Rekoncyliacja po pełnym kluczu zachowuje lokalny messageId. Gdy brak
  timestampu, nie zgadujemy korelacji po tekście; osobna intencja pozostaje unknown.
- **API:** IPC v1, schemaVersion 1 po otwarciu DB, accountId w snapshot.
  conversations.page, messages.page, message.get, conversation.open,
  draft.get/set, message.send, operation.status/cancel/retry. Zmiany
  przyrostowe niosą ID; QML dostaje response/changed/reset i cienkie metody.
  Dokładne parametry, limity i kontrakt cursorów: [API](API.md#ipc-i-dodatkowe-api-po-s02).
- **Retencja przejściowa:** expiring/view-once i edycje mają oznaczenie
  unsupported bez treści. Delete/edit przed celem tworzą tombstones.
  Media są tylko metadanymi/referencjami; CLI nie pobiera załączników ani
  avatarów. Read/receipt/reaction to metadane TTL 7 dni dla przyszłych etapów,
  bez pozornego delivered/read. Treść nierozstrzygniętego outboxu ma limit
  roboczy 24 h. To nie zastępuje pełnej retencji Signala z S09.

| Wykonana próba | Wynik / dowód |
| --- | --- |
| `python3 scripts/check` | **PASS**, 220 QML, 0 błędów — [log](../evidence/signal/S02/check.log). |
| `python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v` | **PASS**, 42 testy / 133 s — [log](../evidence/signal/S02/python-tests.log). |
| Trwałość i awarie SQLite | **PASS**, restart, crash przed/po COMMIT, sending→unknown, migracja rollback, nowsza/uszkodzona baza, symlink WAL, SQLITE_FULL, readonly i zajęty checkpoint — log Python powyżej. |
| Outbox i transport | **PASS**, sent sync przed/po RPC, częściowy wynik, realny timeout 60 s + późna odpowiedź, awaria CLI bez ponownego send; błąd zapisu przerywa odbiór przed trzecią kopertą — log Python powyżej. |
| Końcowa korekta retry po retencji | **PASS**, po usunięciu treści wygasłego outboxu safeRetry jest false także dla wcześniejszej jednoznacznej odmowy — [test celowany](../evidence/signal/S02/expired-retry-tests.log). |
| `python3 scripts/test-signal-integration --idle --output docs/evidence/signal/S02/qml-integration.json` | **PASS**, SignalService/Backend, strony/send/szkice, dwa soft reloady i hard reload, stabilna historia/outbox — [raport](../evidence/signal/S02/qml-integration.json), [log](../evidence/signal/S02/qml-integration.log). |
| Spoczynek 60 s i cleanup QML | **PASS**, 0 ticków CPU helpera i CLI-atrapy, 0 nowych procesów/RPC, 0 osieroconych PID po quit/TERM/KILL — raport powyżej. |
| `python3 -B -m unittest discover -s tests -p test_install.py -v` | **PASS**, 15 testów z nowymi plikami runtime — [log](../evidence/signal/S02/install-tests.log). |

**Granice:** to testy syntetyczne na rzeczywistym SQLite, pipes i QML,
bez konta/telefonu, wysyłania do kontaktów i aktywacji shella. Runner QML
i test instalatora wymagały dopuszczenia prywatnego socketu D-Bus poza
ograniczeniem sandboxa; zachowano prywatne XDG/offscreen. Realnego JVM
nie powtarzano w S02, jego dowody ownership są w S01. Pełna regresja
sprzętu/UI i live pozostają w odpowiednich późniejszych etapach.

**Pozostałe bramki:** luka CLI ACK → SQLite COMMIT nadal może powodować
utratę, bez replay/exactly-once. Pominięte załączniki nie mają obiecanego
późniejszego pobrania. Preflight timera nie zamyka wyścigu ze zmianą
ustawień rozmowy; expirationStartTimestamp i pełne znikanie/suspend/
powiadomienia muszą zostać odebrane w S09 przed aktywacją. Nie wykonano
commita; zachowano wcześniejsze zmiany S00/S01 w checkoutcie.

**Dokładny następny krok — S03:** wykonać
[parowanie konta i ustawienia](../prompts/signal/03-pairing-settings.md)
na istniejących SignalService/Backend i SQLite. Dodać metody link z
terminem/anulowaniem i ustawienia włączania konta; QR tylko w pamięci.
Nie tworzyć drugiego helpera/outboxu, nie zmieniać kluczy historii przy
reloadzie. Wykorzystać service/account status i rozróżnienie ACI konta.
Rzeczywiste skanowanie QR, konto użytkownika i aktywacja pozostają w S12.

## S01 — Proces usługi i transport — 2026-09-20

- **Stan:** ukończony w zakresie S01, bez aktywacji i konta.
- **Kod:** `services/SignalBackend.qml`, `SignalService.qml`,
  `signal_backend.py`, `signal_transport.py`, `signal_process.py`;
  rejestracja w qmldir i pojedyncze instancje w shell.qml.
  `signal-test.qml` wstrzykuje syntetyczny transport i tworzy osobne
  testowe FloatingWindow. `scripts/test` obejmuje nowy runner integracji.
- **Procesy:** jedna blokada flock na stałym inode owner.lock, dziedziczona
  przez CLI; parent-death signal helpera i shim exec CLI, EOF/TERM/KILL,
  reap przed zwolnieniem blokady. Reload ma do 6 s na przejęcie magazynu;
  druga działająca instancja kończy oczekiwanie kontrolowanym failed/busy.
  Bez pkill, własnego autostartu, linger i zależności od UWSM.
- **Transport:** asynchroniczny NDJSON/RPC, ramka do 1 MiB, 32 żądania IPC,
  8 odczytów i jedna mutacja CLI, nieblokujące wyjście do QML do 4 MiB.
  Generacje, kolejność niezależnych odpowiedzi, Unicode, timeout,
  anulowanie, result_unknown i późne odpowiedzi. Anulowana wysłana mutacja
  zajmuje slot do wyniku lub końca transportu. Brak surowych logów CLI.
- **Stany:** brak konfiguracji daje idle bez startu CLI. Włączona
  konfiguracja sprawdza wersję/listAccounts raz; linked zatrzymuje się na
  storage_not_ready bez subskrypcji. Pięć ponowień 1/2/4/8/16 s, potem
  failed i jawne retry. Zła wersja/binarka/ramka nie tworzy pętli.
- **Interfejs S02:** IPC v1, schemaVersion=0, metody `service.status`,
  `service.retry`, `request.cancel` (id próby IPC); hello/service.changed
  niosą stan konta/usługi, wersję CLI, errorCode, retryCount, capabilities.
  `test.echo/mutate/receive` są tylko przy jawnym `--test-scenario`.
  `operation.*` i metody wiadomości pozostają nieobsługiwane.
- **Testy:** rozszerzony `signal_cli_fake.py`, `test_signal_lifecycle.py`,
  `scripts/test-signal-integration`, `scripts/test-signal-process` oraz
  `tests/signal_jvm_owner.py`. Aktualne API i reguły testów w dokumentach
  obok. Instalator automatycznie obejmuje pliki services w paczce runtime.

| Wykonana próba | Wynik / dowód |
| --- | --- |
| `python3 scripts/check` | **PASS**, 220 QML, 0 błędów — [log](../evidence/signal/S01/check.log). |
| `python3 -m unittest discover -s tests -p 'test_signal*.py' -v` | **PASS**, 19 testów, w tym 14 nowych S01 — [log](../evidence/signal/S01/python-tests.log). |
| `python3 scripts/test-signal-integration --idle` | **PASS**, QML/RPC, okno, dwa soft reloady i hard reload, awarie/retry oraz quit/TERM/KILL Quickshella — [raport](../evidence/signal/S01/qml-integration.json), [log QML](../evidence/signal/S01/qml-integration.log). |
| Spoczynek przez 60 s | **PASS**, 0 ticków CPU helpera i atrapy, 0 nowych procesów/żądań; po próbach 0 osieroconych procesów — raport QML powyżej. |
| `python3 scripts/test-signal-process --executable … --java-home …` | **PASS**, 4 próby realnego JVM bez sieci i konta: exec z tym samym PID, FD blokady utrzymany przez sam JVM, TERM/KILL, wczesny spawn i bramka przed exec Java — [raport](../evidence/signal/S01/jvm-process.json). |
| `python3 -m unittest discover -s tests -p test_install.py -v` | **PASS**, 15 testów pakowania/prywatnej instalacji — [log](../evidence/signal/S01/install-tests.log). |
| `python3 -m unittest discover -s tests -p test_runtime.py -v` | **PASS**, 3 testy, w tym wykrycie błędnego importu przez nowy runner — [log](../evidence/signal/S01/runtime-tests.log). |

**Granice odbioru:** testy procesów QML używają atrapy, a realny JVM pustego
magazynu z wyłączoną siecią. Nie są próbą synchronizacji z telefonem.
Nie podłączono konta, nie wysłano wiadomości, nie aktywowano wydania.
Cgroup aktywnego putkin.service, rzeczywiste parowanie i telefon pozostają
w S12. Pełna regresja wszystkich widoków i sprzętu nie była wymagana ani
uruchamiana w S01. Nie wykonano commita; wcześniejsze zmiany S00 zachowano.

**Następny krok — S02:** trwały SQLite i migracje, tożsamości, deduplikacja,
historia/szkice, outbox oraz rekoncyliacja unknown. Otworzyć bazę i wykonać
cleanup przed subskrypcją; zastąpić testowy callback odbioru transakcją
commit przed eventem UI. Dopiero wtedy zdjąć produkcyjną bramkę
storage_not_ready i zmienić schemaVersion/capabilities. Nie odtwarzać S01
ani nie aktywować konta. Luka expirationStartTimestamp nadal należy do S09.

## S00 — Audyt integracji i kontrakty — 2026-09-20

- **Stan:** ukończony w zakresie S00; testy telefonu zgodnie z planem w S12.
- **Rezultat:** udokumentowane miejsca integracji, stany i tożsamości,
  prywatny SQLite/XDG, retencja, dwa rodzaje odczytu, routing okna,
  wspólny outbox i plan sprzątania po awarii/reloadzie także bez UWSM.
  Działający, jawnie wstrzykiwany fake JSON-RPC z syntetycznymi eventami.
- **Wersje:** Quickshell 0.3.1 / Qt 6.11.2 / Python 3.14.7 / SQLite 3.53.4.
  Wybrano **signal-cli 0.14.8 JVM**, commit
  `22b028bbb9cee8f6aa22af71c6b3e9d09028a16a`, prywatny Temurin
  **25.0.4.1+1-LTS**. Archiwa sprawdzone SHA-256 względem metadanych
  wydawców. [Pochodzenie](../evidence/signal/S00/provenance.json).
- **Transport:** CLI `jsonRpc --receive-mode manual` po stdio, jedna
  subskrypcja po gotowości magazynu; QML ↔ helper własny NDJSON v1.
  Historyczne ustawienia UI nie blokują wewnętrznego quick reply w S05.
- **Pliki:** CONTRACTS.md, API.md, TESTING.md; `scripts/test-signal-cli`,
  `tests/signal_cli_fake.py`, `tests/test_signal_contract.py`,
  `tests/fixtures/signal/v0.14.8/session.json`; aktualizacja obu roadmap
  i statusów. Kod produkcyjny i manifest runtime bez zmian.
- **Środowisko:** brak CLI/Javy w PATH; wyodrębniono narzędzia do
  ignorowanego `artifacts/signal-s00/tool/`. Bez pakietów systemowych.
  Prompty były nieobecne, bo `docs/prompts/` jest celowo ignorowane;
  odzyskano lokalnie 13 oryginałów z `/home/attntd/projects/putkin`.
  Reguły wykluczenia pozostały bez zmian. Kluczowe przekazanie S01 jest
  również w wersjonowanych dokumentach, niezależnie od tych kopii.

| Próba | Wynik / dowód |
| --- | --- |
| `python3 scripts/check` | **PASS**, 217 QML, 0 błędów — [check.log](../evidence/signal/S00/check.log). |
| `python3 -m unittest discover -s tests -p test_signal_contract.py -v` | **PASS**, 5 testów — [transport-tests.log](../evidence/signal/S00/transport-tests.log). |
| Kontrola fixture względem schematów wydania oraz lokalnych linków dokumentacji | **PASS**, 14 kopert i 2 wyniki wysłania; jawna tolerancja pól null z serializerów Java, nie ścisła walidacja niezmienionego JSON Schema — [fixture-review.json](../evidence/signal/S00/fixture-review.json). |
| `python3 scripts/test-signal-cli --executable artifacts/signal-s00/tool/signal-cli-0.14.8/bin/signal-cli --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre --output docs/evidence/signal/S00/cli-jvm-probe.json` | **PASS**, 16 kontroli: wersja, 14 help, seria 18 RPC i EOF z exit=0 — [raport JVM](../evidence/signal/S00/cli-jvm-probe.json). Prywatny bwrap bez sieci/konta/home. |
| Ten sam probe dla `artifacts/signal-s00/tool/signal-cli` (native, bez JRE) | **FAIL**, 18 odpowiedzi otrzymano, exit=99 na EOF z błędem GraalVM — [raport negatywny](../evidence/signal/S00/cli-native-probe.json). Wariant odrzucony jako baza tej integracji. |

Pierwsza wersja probe użyła błędnej nazwy `sendRemoteDelete`; sprawdzenie
CLI wskazało `remoteDelete`, runner i kontrakt poprawiono przed końcowym
odbiorem. Uruchomienie bwrap wymagało wyjścia poza sandbox agenta z powodu
odmowy NETLINK_ROUTE; właściwa próba nadal miała prywatną, wyłączoną sieć.

**Znane luki i ich wpływ:** brak `expirationStartTimestamp` w eksporcie
sent sync wymaga uzupełnienia interfejsu przed pełnym S09/S12. View-once-open
i viewed sync nie są eksportowane; view-once pozostaje niedostępne.
Delete-for-me nie ma potwierdzonego sync, więc „usuń u mnie” jest lokalne.
S07 musi uwzględnić pobieranie mediów przed JSON i brak zdalnego lazy fetch.
Nie ma ACK transakcji bridge ani gwarancji replay; unknown jest konieczny.
Szczegóły i źródła: [API.md](API.md). Nie usunięto wymagania znikania/mediów.

**Granice dowodów:** sprawdzono źródła przypiętej wersji, rzeczywisty
executable bez konta oraz framing atrapy. Nie sprawdzono prawdziwego
parowania, dostarczenia, synchronizacji telefonu, UI ani zachowania
produkcyjnego bridge po awarii — bridge jeszcze nie istnieje.
Nie zapisano URI QR, kluczy ani prywatnych wiadomości. Nie wysyłano
wiadomości i nie aktywowano wydania. Nie utworzono commita.

**Dokładny następny krok — S01:** zaimplementować SignalBackend/SignalService
i `signal_backend.py` według CONTRACTS.md, z prywatnym stdin/stdout,
generacjami i ograniczeniami ramek. Rozszerzyć fake o awarie/kolejność/
timeout. Sprawdzić `flock` dziedziczony przez wrapper JVM i parent-death
signal, dwa równoczesne starty, EOF/TERM/KILL oraz reload bez osieroconych
procesów i bez UWSM. Rzeczywisty odbiór konta pozostaje wyłączony do S02,
a parowanie użytkownika do S12. Nie zaczynać S02 przed odbiorem S01.

## Stan początkowy (historyczny)

Przed S00 przygotowano wyłącznie roadmapę i 13 promptów, odczytano Theme,
powiadomienia bez inline reply, zewnętrzny SignalTrayState i instalator.
Kontrole tamtej dokumentacji w `docs/evidence/signal/roadmap/` nie były
testami integracji. Obecny audyt i jego dowody są zapisane osobno w S00.

## Format wpisu po każdym etapie

### SXX — nazwa — data

- **Stan:** w toku / gotowy do odbioru środowiskowego / ukończony.
- **Widoczny rezultat:** co rzeczywiście działa.
- **Pliki:** zmienione źródła i dokumenty.
- **Interfejsy:** rzeczywiste API, wersje, schemat danych i decyzje.
- **Weryfikacja:** polecenie, środowisko, PASS/FAIL, odnośnik do dowodu.
- **Granice:** osobno atrapy, prawdziwe API, UI i telefon; niewykonane kryteria.
- **Znane problemy:** konkretna przyczyna i wpływ.
- **Następna sesja:** dokładny etap i potrzebny krok, bez odsyłania do czatu.

„Ukończony” oznacza spełnienie obowiązkowych kryteriów danego promptu.
S00–S11 mogą być zakończone z jawnym pozostawieniem testów live dla S12.
S12 nie ma pełnego odbioru, dopóki jego wymagane próby z telefonem/
wskazaną rozmową nie mają potwierdzenia. Brak telefonu nie przekreśla
ukończonej implementacji, testów lokalnych i przygotowanego wydania.
