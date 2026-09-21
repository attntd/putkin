# S10 — grupy, kontakty i akceptacja

Odbiór lokalny 2026-09-21 w `/home/attntd/projects/signal`.
Wyłącznie syntetyczne dane, prywatne SQLite/XDG/D-Bus, Qt offscreen i atrapa
signal-cli po rzeczywistych pipe. Bez parowania, wdrożenia na pulpicie,
telefonu i wiadomości do rzeczywistych kontaktów. Audyt źródeł przypiętego
v0.14.8; runtime pozostaje **putkin-retention-2**, SQLite **v7**, IPC **v1**.

## Odebrany zakres

- Kontakty/profile i numer/username bez próbnego send; zmiana nazwy,
  numeru i avatara zachowuje ACI, conversationId i historię. Odświeżanie
  nie gubi wyboru członków, szkicu ani aktywnego pola. Wybór grup obejmuje
  również zaproszenia bez wiadomości.
- Tworzenie grupy z członkami/avatarem, walidacja, rzeczywisty groupId,
  deduplikacja operationId, partial, crash/restart i późny wynik.
  Unknown blokuje kolejne create; jawna rekoncyliacja wiąże istniejący ID,
  bez automatycznego ponawiania i dopasowania wyłącznie po nazwie.
- Nazwa/opis, członkowie, administratorzy, ostatni admin z następcą,
  uprawnienia, link, join/requesting, zaproszenie i prośby o dołączenie.
  Niepełny snapshot i brak uprawnień blokują administrację. Potwierdzenie
  usunięcia/opuszczenia/blokady wskazuje cel i zaczyna od Anuluj.
- Group quick reply trafia do `groupId`, nigdy do ACI ostatniego autora.
  Syntetyczny sync utraty członkostwa wyłącza otwarty composer i reply
  starego powiadomienia. Dotyczy także left/terminated/blocked w backendzie.
- Nieznany nadawca: bez read, typing, odpowiedzi i mutacji do akceptacji.
  Akceptacja i block/unblock odczytują stan CLI. Mute i hidden są lokalne;
  nie blokują odbioru/zapisu/unread ani nie zmieniają DND.
- Typowane zdarzenia systemowe zmian grup bez body/autora, unread i toasta.
  Kontekst grup zachowuje tekst/media, autora, cytat, wzmianki UTF-16,
  edycje, reakcje, raporty per osoba, usuwanie i znikanie.
- Cache avatara: walidacja dekodera/MIME/limitu, prywatna miniatura,
  zastąpienie i cleanup. Testowany rzeczywisty worker i magazyn plików.

## Wyniki

| Próba | Rzeczywisty wynik i dowód |
| --- | --- |
| Składnia/importy QML | **258 plików, 0 błędów**, [check.log](check.log) |
| Pełny Python | **197 PASS**, w tym 12 S10, [python-full.log](python-full.log) |
| Pełny QtTest | **666 PASS, 1 FAIL, 0 SKIP**, [qml-full.log](qml-full.log); jedyny FAIL: Audio::test_external_update_shared_state_and_identity |
| Powtórzenie Audio | **22 PASS**, [tst_audio.qml.log](tst_audio.qml.log); pełnego zestawu po tym nie powtarzano |
| Qt S10 | **8 PASS**, [tst_signal_groups.qml.log](tst_signal_groups.qml.log) |
| Qt wiadomości/interakcje/media/retencja/receipts/powiadomienia | **50 PASS**, odpowiednie pliki `tst_*.qml.log` obok |
| Natywny S10 | **PASS**, [raport](groups-native.json), [log](groups-native.log), [szczegóły](group-details.png), [po utracie członkostwa](group-left.png) |
| Natywne S01/S03–S09 | **8 końcowych PASS**, raporty `regression-*.json` i logi obok |
| Audyt przypiętych źródeł | [Ścieżki, URL i SHA-256](api-provenance.json); nie zastępuje prób telefonu |

Pierwsza pełna regresja backendu ujawniła połknięte anulowanie transportu
podczas wyłączania konta. Sender/read batch teraz propagują CancelledError,
z zachowaniem unknown dla niepewnego batcha. Oczekiwanie testu nierozwiązanego
numeru zmieniono zgodnie z S10: pending pozostaje unread. Celowana próba
obu przypadków przeszła ([focused-regression.log](focused-regression.log)),
następnie cały backend zakończył się 197 PASS.

Pierwszy natywny S04 zakończył się ostrzeżeniem Qt o dwóch inkubowanych
elementach przy zamknięciu silnika, po przejściu asercji funkcjonalnych.
Runner kończył zaraz po przywróceniu szkicu, zanim wyrenderował się widok
po hard reload. Dodano oczekiwanie na historię i rzeczywisty kadr po reload;
końcowy [raport S04](regression-messages.json) i [log](runtime-messages.log)
nie mają błędów. [Pierwsza lista kodów wyjścia](native-regression.json)
zachowuje ten wcześniejszy FAIL; pozostałe siedem runnerów przeszło od razu.

Pojedynczego błędu Audio w pełnym Qt nie uznano za naprawiony na podstawie
samego ponowienia. Osobny plik przeszedł 22/22, bez zmian kodu audio.
S11 ma sprawdzić stabilność całego zestawu pod obciążeniem.

## Polecenia i izolacja

```sh
scripts/check
python3 -m unittest discover -s tests -p 'test_*.py' -v
scripts/test-icons --all-qml --timeout 600 --log artifacts/signal-s10/qml-full.log
scripts/test-signal-groups --output artifacts/signal-s10/groups-native.json
scripts/test-signal-messages
scripts/test-signal-notifications
scripts/test-signal-receipts
scripts/test-signal-media
scripts/test-signal-interactions
scripts/test-signal-retention
scripts/test-signal-pairing
scripts/test-signal-integration
```

Celowane Qt uruchomiono tym samym mechanizmem co `scripts/test-icons --file`:
`isolated_environment`, prywatne dbus-run-session, qmltestrunner `-input`
na pojedynczy plik i `-import` na checkout. Pliki: tst_audio, tst_messages,
tst_signal_groups, tst_signal_receipts, tst_signal_retention,
tst_signal_interactions, tst_signal_notifications, tst_signal_media.
Razem **80 PASS**, wliczając inicjalizację/cleanup QtTest.

Pełny Python oraz Qt/natywne runnery uruchomiono poza ograniczeniem sandboxa
agenta, które blokowało budzenie wątków asyncio i prywatny D-Bus. Zachowano
izolację samych runnerów; nie podłączano usług ani kont użytkownika.

## Granice i przekazanie

CLI nie eksportuje rewizji grupy, osobnego trybu akceptacji linku ani
messageRequestResponse w JSON sync. Odświeżamy katalog po zdarzeniach;
zmiana snapshotu jest obserwacją lokalną, nie pełnym audytem serwera.
Readback profileSharing/blokady nie dowodzi odebrania sync przez telefon.
Przyjęcie bieżącego stanu operacji nie dowodzi dystrybucji do wszystkich.

Rzeczywiste tworzenie i dołączanie, avatar, role/uprawnienia, odmowa,
zaproszenia, block/accept oraz synchronizacja z telefonem i drugim członkiem
wymagają wskazanej grupy testowej w S12. Portal/IME/kompozytor także nie są
odbierane przez offscreen. S11: macierz ACCEPTANCE, odporność, pełny odbiór
i wydajność. Nie rozpoczęto S11/S12; bez wdrożenia i commita.
