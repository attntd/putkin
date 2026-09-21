# S09 — usuwanie i wiadomości znikające

Odbiór lokalny 2026-09-21 w checkoutcie `/home/attntd/projects/signal`.
Wyłącznie dane syntetyczne, prywatne XDG/D-Bus/SQLite i Qt offscreen;
klasy JVM w bubblewrap bez sieci i konta. Bez instalacji na pulpicie,
parowania, telefonu i wysyłki do rzeczywistych kontaktów.

## Co odebrano

- Usunięcie lokalne nie wysyła RPC, usuwa wpis z widoku i blokuje replay.
  Remote delete używa `remoteDelete.targetTimestamp`, wspólnego outboxu,
  własności i limitu 24 h; unknown/partial nie mają automatycznego retry.
- Usunięcie przed celem, po celu i sent sync z telefonu. Odwrotne łańcuchy
  edycji, duplikaty oraz późne wyniki inflight nie odtwarzają treści.
  Osobne tożsamości autora/rozmowy i minimalne trwałe tombstones.
- Timery incoming od kwalifikowanego odczytu albo wcześniejszego read sync;
  outgoing od wysłania, w tym Notatka. Najwcześniejszy start, brak wydłużania
  przez edycję/replay/zmianę rozmowy. Faktyczny timer z buildera CLI
  zastępuje odczyt preflight; partial/unknown z timestampem zachowuje expiry.
- Trwały deadline, cleanup przed historią przy starcie, rzeczywisty timerfd
  bez okresowego skanowania i jednego timera na wiadomość. Symulowane
  resume, kroki zegara oraz ECANCELED; brak zmiany zegara/uśpienia hosta.
- Body, wersje, reakcje, mutacje, kontrolowane cytaty i kompozycja; skan
  SQLite/WAL na syntetyczny marker. Awaria GC/checkpointu i ponowny start.
  Współdzielony plik żyje do ostatniej referencji; późny wynik workera nie
  przywraca kopii. Rzeczywisty własny proces dekodera jest kończony po delete.
- Qt: dwa zakresy usunięcia, wybór czasu, klawiatura, oba akcenty, usunięcie
  treści zajętego edytora/cytatu/podglądu obrazu. W centrum/toastach dokładny
  messageId, ochrona nowszej karty i odrzucenie spóźnionego fetch.
- Natywny runner łączy produkcyjny QML/bridge/SQLite i atrapę CLI; potwierdza
  remoteDelete, updateContact.expiration, odczyt widoczny, zamknięte okno,
  restart po deadline oraz sprzątnięcie wszystkich własnych procesów.
- Java: faktyczne metody odbioru/serializacji, pole startu także dla 0,
  metadane rzeczywistego timera i usunięcie starych payloadów resend z
  prawdziwej bazy CLI. View-once pomija pobieranie, media znikające trafiają
  do ograniczonego downloadera.

## Wyniki

Wyniki końcowych poleceń są zapisane w poniższych plikach. Pełna regresja
obejmuje wcześniejsze etapy; testy telefonu nie są częścią tych wyników.

| Odbiór | Wynik i dowód |
| --- | --- |
| QML składnia/importy | **PASS**, 254 pliki, 0 błędów — [check-final.log](check-final.log) |
| Pełny backend | **PASS**, 128 testów — [python-final.log](python-final.log) |
| Pełny QtTest | **PASS**, 659 wyników, 0 FAIL/SKIP — [all-qml.log](all-qml.log) |
| Retencja, migracje i media | **PASS**, 18 oraz 30 testów (zestawy częściowo wspólne) — [retention-final.log](retention-final.log), [media-retention-final.log](media-retention-final.log) |
| Akcje, klawiatura, edytor, podgląd | **PASS**, 8 wyników, 0 FAIL/SKIP — [retention-ui-final.log](retention-ui-final.log) |
| Natywny S09 | **PASS**, bez błędów QML i osieroconych procesów — [raport](native-retention.json), [log](native-retention.log), [akcje](delete-actions.png) |
| Natywna regresja S07 | **PASS**, bez błędów QML i osieroconych procesów — [raport](media-regression.json), [log](media-regression.log) |
| CLI build i rzeczywiste klasy | **PASS** — [build](cli-build-final.log), [polityka/retencja](cli-policy-final.log), [puste konto/RPC](cli-probe.json) |
| Instalator, tylko katalogi tymczasowe | **PASS**, 15 testów — [install-tests.log](install-tests.log) |
| Źródła i hashe | [api-provenance.json](api-provenance.json), [runtime](../../../../services/signal-cli-media/runtime.json) |

## Polecenia

```sh
scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
PYTHONPATH=tests:services python3 -B -m unittest test_signal_retention test_signal_media -v
python3 -B scripts/test-icons --file tst_signal_retention.qml --log docs/evidence/signal/S09/retention-ui-final.log
python3 -B scripts/test-icons --all-qml --timeout 600 --log docs/evidence/signal/S09/all-qml.log
python3 -B scripts/test-signal-retention --output docs/evidence/signal/S09/native-retention.json
python3 -B scripts/test-signal-media --output docs/evidence/signal/S09/media-regression.json
python3 scripts/build-signal-media-cli --source artifacts/signal-s09/source --distribution artifacts/signal-s00/tool/signal-cli-0.14.8 --jdk artifacts/signal-s07/jdk-25.0.4.1+1 --output artifacts/signal-s09/cli-final
python3 scripts/test-signal-media-cli --distribution artifacts/signal-s09/cli-final --jdk artifacts/signal-s07/jdk-25.0.4.1+1
python3 scripts/test-signal-cli --executable artifacts/signal-s09/cli-final/bin/signal-cli --java-home artifacts/signal-s07/jdk-25.0.4.1+1 --output docs/evidence/signal/S09/cli-probe.json
python3 -B -m unittest discover -s tests -p test_install.py -v
```

## Znalezione błędy i poprawki

Pierwszy przebieg backendu miał oczekiwania schematu v5 i poprzednią odmowę
wiadomości znikających; zostały zastąpione sprawdzeniami nowej semantyki.
Fixtures migracji do starszych schematów muszą usuwać również nowe kolumny.
Test v2 wykrył faktyczną złą kolejność: reducer read wywoływał retencję przed
utworzeniem kolumn v6. Reducer działa teraz po zakończeniu migracji.
Celowany i pełny odbiór zostały ponowione.

Pierwszy QtTest oczekiwał zachowania tekstowego placeholdera w centrum po
delete; S09 usuwa całą kartę. Nowy fixture podglądu nie miał pola thumbnail,
co dawało ostrzeżenie QUrl; dodano pełne metadane załącznika. Logi pierwszych
przebiegów pozostają: python-initial/intermediate/migration-order,
all-qml-initial, notifications-ui. Testy izolacji potrzebowały uprawnienia
utworzenia prywatnego gniazda D-Bus i przestrzeni bubblewrap; brak tego
uprawnienia nie jest wynikiem testu funkcji.

## Granice i przekazanie

View-once jest niedostępny; API nie eksportuje viewOnceOpen. Delete-for-me
jest lokalne. Remote delete jest żądaniem, nie gwarancją kasowania u innych.
Kontrolowane kopie zapisane przez użytkownika poza integracją nie są usuwane.
Wyłączony shell nie sprząta o terminie, robi to przy starcie. Nie obiecujemy
forensic erase SSD/RAM/swap/snapshotów. Przy wyniku wysyłki utraconym przed
poznaniem timestampu pozostaje unknown z ograniczoną retencją stagingu,
bez wymyślania potwierdzonego początku protokołu. Wyłączenie resend log
usuwa możliwość automatycznej naprawy błędu odszyfrowania u odbiorcy.

Telefon, prawdziwy suspend/resume i kompozytor pozostają S11/S12. Nie
uruchomiono S10. Następny prompt: [grupy i kontakty](../../../prompts/signal/10-groups-contacts.md),
SQLite v6, CLI putkin-retention-2 z dwoma przypiętymi jarami. Bez commita.
