# Signal — macierz odbioru S11/S12

Odbiór lokalny 2026-09-21, checkout `/home/attntd/projects/signal`.
**S12 wdrożony i sparowany. Podstawowy odbiór live PASS; rozszerzona macierz otwarta.**
SQLite **v7**, IPC **v1**, signal-cli **0.14.8 JVM + putkin-retention-2**.
Wydanie `20260921-091350-39f9ddda75b4` aktywne; parowanie PASS, konto `ready/linked`
po aktualizacji parsera pisania. Tekst w obie strony, reakcje i załączniki live potwierdzone. Wyniki lokalne S11 poniżej zachowano historycznie.
Dowody: [S12](../evidence/signal/S12/README.md), historyczne [S11](../evidence/signal/S11/README.md).

## S12 — bieżąca macierz wdrożenia i live

| Próba | Wynik / dowód |
| --- | --- |
| Powtarzalny pakiet CLI/JRE, hashe, brak danych w buildzie | **PASS** — package-rebuilt.json, source-sha256.json |
| Prywatny cel, dry-run, pięć buildów, aktualizacja i rollback | **PASS** — install-tests.log, staging-rollback.json; wszystkie hashe danych zachowane |
| Migracja, odmowa downgrade’u i niezgodnego fallbacku | **PASS** — 11 testów wydania, bez cofania kluczy/usunięć/retencji |
| Regresja po scaleniu z aktywnym main | **PASS** — 218 Python, 787 Qt, 23 integracje, kod 0; 272 QML bez błędów |
| Aktywacja przez UWSM, pojedynczy shell i właściciel powiadomień | **PASS** — activation.log |
| Okno → zamknięcie, stop/start, brak bridge po stopie, Caffeinate/ustawienia | **PASS na pulpicie** — live-shell.json; konto jeszcze niesparowane |
| Prawdziwy QR w ustawieniach | **PASS wyświetlenia** — pairing-status.json bez URI/obrazu; **skan PASS**, potwierdzony przez użytkownika |
| Konto i restart po parowaniu | **PASS live** — skan potwierdzony; aktualizacja przywróciła `ready/linked` bez skanu |
| Parser pisania po błędzie pierwszej sesji | **PASS D/J** — `STARTED`/`STOPPED`, realny serializator; ponowny odbiór wiadomości i sent sync działa; bezpośredni test pisania otwarty |
| Notatka: tekst telefon ↔ Putkin | **PASS live** — note-text.json, użytkownik potwierdził widoczność na obu urządzeniach |
| Reakcje i załączniki z drugą osobą | **PASS live wg użytkownika** — reakcje w otwartej konwersacji; user-acceptance.json; pełna lista formatów/kierunków załączników nieokreślona |
| Dodawanie reakcji z powiadomienia | **BRAK w obecnym UI** — reakcje wybiera się w oknie rozmowy przez ⋯; quick reply obsługuje tekst |
| Edycja wiadomości po obu stronach | **PASS live wg użytkownika** — zmiana widoczna na obu urządzeniach |
| Powiadomienie: Otwórz właściwą rozmowę i quick reply bez okna | **PASS live wg użytkownika** — potwierdzone oba działania |
| Dynamiczne akcenty w quick reply | **PASS W**, prywatny Wayland; osobna zmiana akcentów w rozmowie live niewykonana |
| Sent sync | **PASS live** — wiadomości z telefonu w bazie po poprawce; tekst widoczny na obu urządzeniach |
| Potwierdzenia odczytu | **PASS live wg użytkownika** — obserwowane zmiany statusu wiadomości w rozmowie |
| Usuwanie wiadomości | **PASS live wg użytkownika** — wszystkie tryby i kierunki usuwania nieokreślone |
| Rozmowy grupowe | **PASS live wg użytkownika** — działanie rozmów potwierdzone |
| Prywatność receipts i read sync między urządzeniami, znikanie | **NIEWYKONANA pełna macierz live** — potwierdzenie statusu odczytu nie obejmuje wszystkich wariantów |
| Role, zaproszenia i uprawnienia grupowe | **NIEWYKONANE live** — szczegółowe operacje administracyjne wymagają osobnej próby |
| Fizyczny IME, portal, audio, monitory/DPMS/suspend, zasoby konta live | **NIEWYKONANE** — atrapy i prywatny compositor nie zastępują sprzętu/konta |

[Dowody S12](../evidence/signal/S12/README.md), [obsługa i powrót](OPERATIONS.md).
Nie wyłączono ani nie zmieniono Signal Desktop.

## Poziomy dowodów

- **D** — prawdziwy reducer/SQLite/transport i syntetyczne zdarzenia/RPC.
- **J** — rzeczywiste przypięte klasy/binarka JVM, puste konto, bez sieci.
- **Q** — produkcyjne QML, prawdziwe zdarzenia Qt, prywatne XDG/D-Bus,
  renderowanie offscreen i syntetyczny CLI.
- **W** — produkcyjne okna/powiadomienia na prywatnym Hyprlandzie/GPU,
  prawdziwe wyjścia, wtype i grim; domena Signal nadal syntetyczna.
- **L** — telefon, serwer, wskazana druga osoba/grupa i rzeczywisty sprzęt.
  Parowanie, tekst, reakcje, załączniki, edycja i powiadomienia live potwierdzone; pozostałe próby otwarte; lifecycle prawdziwego
  shella odebrano osobno powyżej. Żadna atrapa nie zastępuje telefonu.

## Wymaganie → implementacja → test → wynik

| Wymaganie | Implementacja | Dowód automatyczny | Poziom / wynik |
| --- | --- | --- | --- |
| Telefon jako urządzenie główne, parowanie i anulowanie | SignalSettings, signal_account/qr, przypięte startLink/finishLink | test_signal_pairing, test-signal-pairing; capture odmawia podczas QR | **PASS** — D/Q; telefon L |
| Przychodzący tekst i cztery rodzaje mediów → historia | signal_events/store/media, adapter i MessageHistory | test-signal-acceptance: PNG, MP4, WAV, TXT z nazwą traversal; test_signal_media | **PASS** — D/Q |
| Odbiór przy zamkniętym oknie, toast → quick reply | SignalNotifications, NotificationService, SignalReplySession, wspólny outbox | test-signal-acceptance: brak okna/read RPC, dokładny recipient, pojedynczy send | **PASS** — D/Q |
| Routing do grupy bez pomylenia z autorem | ConversationRoute, MessageHub, MessagesController, signal_outbox | test-signal-groups; zapis parametrów groupId; test_messages_controller | **PASS** — D/Q |
| Telefon → sent sync bez toasta; komputer → send | signal_events/store/outbox | S11 E2E i test_signal_history; stały messageId przed/po odpowiedzi | **PASS** — D/Q; oba rzeczywiste kierunki L |
| Dostarczenie/odczyt i odwrotna kolejność | signal_receipts, wersje wiadomości, widoczny zakres MessageHistory | test_signal_receipts, test-signal-receipts; S11 read → delivery | **PASS** — D/Q; prywatność telefonu L |
| Centrum nie oznacza rozmowy jako przeczytanej | NotificationService vs SignalMessagingAdapter.markVisible | test_signal_notifications, test-signal-notifications/receipts | **PASS** — D/Q |
| Reakcja, edycja, cytat, wzmianka, pisanie | signal_interactions/mutations/content/typing, MessageText | test_signal_interactions, Qt SignalInteractions, S11 E2E | **PASS** — D/Q |
| Zmiany przed celem, duplikaty, brak oryginału | trwałe wersje/pending/tombstones, deduplikacja po tożsamości | S11 reverse edit/reaction/delete; 800 eventów → 400 wpisów; test_signal_history/retention | **PASS** — D/Q |
| Usuwanie i wygaśnięcie obejmują kontrolowane kopie | signal_retention, timerfd, GC, redakcja adaptera/powiadomień | test_signal_retention, test-signal-retention; S11 hard reload po rozpoczęciu terminu | **PASS** — D/Q/J; fizyczny suspend L |
| Grupy/profile/role/linki/akceptacja/blokada | signal_directory/groups, ConversationDetails/NewConversation | test_signal_groups, test-signal-groups; S11 create/admin/notification | **PASS** — D/Q; wskazana grupa L |
| Offline/reconnect i bounded backoff | Bridge.supervise, generacje, StoreLease | LifecycleTests.test_backoff_stops_after_five_retries_and_explicit_retry_recovers; test_reconnect_generation_error_redaction_and_explicit_cancel | **PASS** — D |
| Awaria shella/bridge/CLI i reload w trakcie operacji | parent-death, dziedziczony flock, trwałe sending → unknown | test_signal_lifecycle/history/groups; test-signal-integration; test-signal-process | **PASS** — D/Q/J |
| Timeout po możliwym wysłaniu, late result | RpcTransport.uncertain_mutation, wspólny outbox | test_timeout_late_reply_reconciles_and_releases_queue_without_resend; unknown create/reconcile; S11 brak replay po reload | **PASS** — D/Q |
| Zmieniony klucz/odmowa tożsamości | IDENTITY_FAILURE jako failed; brak automatycznego trust/retry | ReliabilityTests.test_identity_failure_is_failed_without_trust_or_automatic_resend | **PASS** — D; rzeczywista zmiana klucza L |
| Utrata uprawnień/członkostwa | canSend/canAdmin sprawdzane przed dispatch i w quick reply | test_signal_groups; test-signal-groups: stare powiadomienie i otwarty composer | **PASS** — D/Q |
| Odłączenie konta przy reconnect | listAccounts → relinkRequired; zachowana historia, brak send | ReliabilityTests.test_revoked_account_after_cli_death_preserves_history_and_disables_send | **PASS** — D |
| Pełny dysk/readonly/uszkodzona baza/wyższy schemat | transakcje, brak publikacji przed COMMIT, storage_error, bramka wersji | HistoryTests.test_full_disk_and_readonly_transaction_never_publish_uncommitted_message; test_schema_rollback_newer_version_corrupt_db_and_unsafe_companions; BridgeHistoryTests.test_storage_failure_stops_receive_before_next_event_and_requires_retry | **PASS** — D |
| Granice IPC, nadmiar zdarzeń, wolny odbiorca stdout | 1 MiB/frame, 32 IPC, 8 read RPC, 1 mutation, 4 MiB output | test_signal_lifecycle; OutputPressureTests; S11 800 eventów w odwrotnej kolejności | **PASS** — D |
| Brak prywatnych errorów/treści w logach, prywatne pliki | kody błędów bez raw payload, scrub-log, stderr odrzucony, 0700/0600 | ReliabilityTests.test_rpc_private_error_never_enters_logs_status_or_database; test_signal_pairing i przegląd dowodów S11 | **PASS** — D/Q/J |
| Path traversal/symlink/hardlink, limity plików | signal_paths/media, poprawka CLI przed pobraniem | test_signal_media; SignalMediaPolicyTest; S11 nazwy `../../...` nie sterują ścieżką | **PASS** — D/J/Q |
| Bezpieczny tekst i lock | PlainText, MessageText escaping, redakcja, zatrzymanie widocznego odczytu | test_signal_interactions/notifications; W: dosłowne `<b>`, zamknięcie okna i redakcja po lock | **PASS** — D/Q/W |
| Klawiatura, Unicode, IME, fokus | MessageComposer, NotificationReply, NotificationFocus | QtTest; rzeczywisty QInputMethodEvent preedit/commit obu edytorów; W: hjkl/Unicode/Shift+Enter/Escape i powrót do innej aplikacji | **PASS** — Q/W; silnik IME L |
| Dwa akcenty live, podgląd/zapis/anulowanie | wspólne Theme, Settings i prawdziwy FileView | W: aktywna quick reply zachowuje szkic przy wszystkich trzech operacjach i reloadzie | **PASS** — W |
| Małe/duże okno, skala, drugi ekran/hotplug | MessagesWindow/Controller, NotificationWindows/Service | test-wayland --signal: okno 420×520, wyjście 1920×1080, 1×/1,5×, usunięcie wyjścia z aktywnym oknem | **PASS** — W; monitory fizyczne L |
| Spoczynek/20 cykli/duża historia | leniwy loader, keyset pagination, ograniczone delegaty, eventowe timery | test-signal-acceptance: 60 s, 20 cykli, 10 000 wiadomości; test-signal-process --idle dla JVM osobno | **PASS** — D/Q/J |
| Regresja istniejącego shella | scripts/check, scripts/test i natywne runnery | pełny końcowy przebieg z logiem, bez pomijania błędów | **PASS** — 202 Python, 667 Qt, 23 integracje |

## Wyniki i zasoby

**PASS:** bramka 259 plików QML bez błędów, backend 202 testy, QtTest
667 PASS / 0 FAIL / 0 SKIP oraz **23/23 runnerów integracyjnych**, w tym
wszystkie 9 Signala. Końcowy `scripts/test` zakończył się kodem **0**;
[pełny log](../evidence/signal/S11/full-test.log),
[podsumowanie przebiegów](../evidence/signal/S11/run-summary.json).
Natywny Wayland, rzeczywiste wejście Qt/IME, 16 kontroli lokalnego CLI,
polityka mediów/retencji na rzeczywistych klasach Java i lifecycle JVM: PASS.

[Końcowy E2E i pomiar](../evidence/signal/S11/acceptance/report.json):
10 000 wiadomości, 200 stron po 50; mediana **10,04 ms**, p95 **13,11 ms**,
max **15,82 ms**, indeks `messages_page`, brak duplikatów. Cztery rodzaje
mediów dochodzą w scenariuszu E2E. Seed i pełny przegląd: 61,925 s.

| Proces | CPU przez 60,00016 s | RSS początek → koniec |
| --- | --- | --- |
| QML/Quickshell | 0,05 s | 159 508 → 133 352 KiB |
| Bridge Signal | 0,00 s | 37 224 → 37 224 KiB |
| Istniejący obserwator powiadomień | 0,00 s | 27 584 → 27 584 KiB |
| Syntetyczny CLI | 0,00 s | 22 960 → 22 960 KiB |
| Rzeczywisty JVM, **osobna próba z pustym kontem** | 0,01 s | 158 952 → 158 952 KiB |

Zakres QML to entrypoint S11 z produkcyjnymi komponentami Signala
i powiadomień. Pomiar pełnej aktywnej konfiguracji z kontem live należy do S12.
61 próbek idle bez IPC, stale cztery procesy i jeden odbiorca.
Mierzone timery aplikacji: 0 QML przy zamkniętym oknie, 0 typing,
1 timerfd najbliższego terminu retencji/metadanych; 0 pending RPC,
late results, bajtów kolejki output oraz workerów mediów/katalogu.
Nie jest to inwentaryzacja wszystkich wewnętrznych timerów Qt/JVM.

**20/20** cykli zwolniło okno; każde pokazało 49/99 rekordów (jeden
zredagowany), tylko **8 delegatów** na obu stronach. Mediana całego cyklu
otwarcie + druga strona + fade/zamknięcie: **1,45 s**, nie czas samego
otwarcia. RSS cykli mieścił się w **168 304–173 088 KiB**;
różnica median 6–10 vs 16–20: **+2352 KiB**, poniżej budżetu 16 MiB.
Próbki nie wykazują przyrostu pamięci z każdym kolejnym oknem; nie stanowią
dowodu braku wszelkich długoterminowych wycieków. Dwie subskrypcje łącznie
(przed i po hard reload), jedna naraz; brak osieroconych procesów/błędów QML.

CPU ma rozdzielczość zegara `/proc`; 0,00 nie oznacza matematycznego zera.
Host nie był wyłącznie przeznaczony do benchmarku. Koszt JVM z pustym
kontem nie jest kosztem konta live. Pomiary QML/bridge z atrapą i JVM są
osobne, nie sumowane jako wynik produkcyjny. Starsze nieudane próby
służyły diagnozie i nie są przedstawiane jako PASS.

## Zależności kandydata

- Quickshell 0.3.1, Qt 6.11.2 (Quick/Controls/Dialogs/Multimedia/Wayland),
  Python 3.14.7 i SQLite; istniejące zależności Putkina pozostają bez zmian.
- signal-cli 0.14.8 JVM z **obydwoma** poprawionymi jarami
  `putkin-retention-2` i metadanymi polityki; wymagany JRE ≥25.
  Runtime odrzuca inne hashe. S12 musi spakować ten build, nie stockowy CLI.
- Lokalny worker mediów/ffmpeg oraz narzędzia schowka/portalu zgodne
  z [TESTING.md](TESTING.md). Testowa infrastruktura Waylanda:
  Hyprland 0.56.2, bubblewrap, D-Bus, wtype, grim, wayland-scanner, kompilator.
- Dane XDG/SQLite/klucze CLI poza wydaniem. Nie odwracać migracji, kluczy
  ani tombstones przy rollbacku kodu. Nie istnieje importer starej historii.

## Granice niezawodności

1. ACK/cache CLI nie czeka na COMMIT bridge. Awaria między CLI/pipe/SQLite
   może utracić wiadomość; brak dowolnego replay i gwarancji exactly-once.
2. Timeout nie dowodzi niewysłania. Unknown/partial pozostają widoczne,
   bez automatycznej ponownej wysyłki; create wymaga jawnej rekoncyliacji.
3. Wyłączony shell nie odbiera. Retencja serwera jest skończona; nie
   obiecujemy odzyskania luk z wcześniejszej historii telefonu.
4. Znikanie po wyłączeniu procesu jest egzekwowane przy następnym starcie
   przed pokazaniem historii. Cofnięcie zegara może opóźnić absolutny termin.
   Brak gwarancji forensic erase SSD/RAM/swap/snapshotów/eksportów odbiorcy.
5. View-once pozostaje niedostępny i nie pobiera zwykłego cache/podglądu.
   „Usuń u mnie” jest lokalne. Remote delete nie usuwa cudzych eksportów.
6. Wyłączony resend log ogranicza automatyczną naprawę odszyfrowania.
   Zmiana tożsamości wymaga świadomej obsługi; test nie włącza auto-trust.
7. Typing ma osobne lokalne ustawienie domyślnie wyłączone. CLI nie
   eksportuje ustawienia telefonu, rewizji/trybu akceptacji linku grupy
   ani osobnego messageRequestResponse sync. Snapshot nie jest audytem serwera.
8. Sent sync grupy nie zawsze dostarcza pełną listę odbiorców. Brak read
   nie oznacza nieprzeczytania. Prywatność receipts wymaga próby z telefonem.

## Minimalny odbiór telefonu S12 — jeszcze niewykonany

1. **Wykonane:** staging, hashe/zależności, instalacja i rollback bez cofania
   danych protokołu/retencji; S12 aktywowany przez instalator.
2. Użytkownik skanuje QR; sprawdzić urządzenie połączone w telefonie.
   Nie zapisywać URI, QR ani danych prawdziwych rozmów do artefaktów.
3. Notatka: tekst i pliki w obu kierunkach, ponowne otwarcie/restart;
   telefonowe sent sync nie tworzy toasta. Notatka nie zalicza receipts.
4. Ze wskazanym drugim rozmówcą: przychodzący tekst/media przy zamkniętym
   oknie, toast/centrum → otwórz/reply, poprawny odbiorca, odczyt i read sync
   w obu kierunkach, z zewnętrznymi receipts włączonymi i wyłączonymi.
5. Zdjęcie/wideo/audio/plik w obu kierunkach, portal, schowek Waylanda,
   fizyczne odtwarzanie, błędny kodek, reakcje/edycje/cytaty i typing.
6. Lokalny/remote delete i znikanie: oba kierunki, blokada, restart po
   terminie i fizyczny suspend/resume; bez treści w powiadomieniu/cache.
7. Wyłącznie na **wskazanej grupie testowej**: create/join/link/zaproszenie,
   avatar, role/uprawnienia, utrata członkostwa, ostatni administrator,
   accept/block/unblock oraz zmiana profilu/kontaktu z telefonu.
8. Odłączenie sieci, reload podczas operacji, odłączenie urządzenia przez
   telefon, świadoma próba zmiany klucza; brak fałszywego sukcesu/retry.
9. Fizyczny IME/monitory/hotplug/DPMS/portal i pomiar konta live przez 60 s.
   Odnotować współistnienie Signal Desktop bez automatycznego wyłączania go.

Brak telefonu i grupy nie blokuje lokalnego kandydata. Pełny odbiór S12
wymaga potwierdzenia tych prób, a nie samego statusu „zainstalowano”.
