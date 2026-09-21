# S04 — okno wiadomości i wspólny routing

2026-09-20, `/home/attntd/projects/signal`. Dane, kontakty i konto są
syntetyczne; bez połączeń z serwerem Signal i zmian aktywnego pulpitu.

| Próba | Dowód |
| --- | --- |
| Składnia/importy całego projektu | [check.log](check.log): 238 QML, PASS; końcowe zmiany dodatkowo [check-final.log](check-final.log) i [controller-check.log](controller-check.log) |
| S00–S04 backend/SQLite/transport/konto | [python-tests.log](python-tests.log): 56 testów, PASS |
| Pełna regresja QML | [qml-tests.log](qml-tests.log): 616 PASS, 0 FAIL/SKIP |
| Końcowy UI, 180 wpisów i seria 40 zdarzeń | [messages-tests.log](messages-tests.log): 9 PASS |
| Kontroler, dwa monitory, fokus/PID, bar i migracja komend | [controller-tests.log](controller-tests.log): 6 PASS |
| Native MessagesWindow + produkcyjny adapter/bridge/SQLite | [messages.json](messages.json), [log](messages.log), [776×720](messages-wide.png), [320×300](messages-small.png) |
| Proces/outbox/soft+hard reload/TERM/KILL/cleanup | [integration.json](integration.json), [log](integration.log); idle 2 s, 0 ticków/RPC/nowych procesów |
| Parowanie i odzyskanie po SIGKILL | [pairing.json](pairing.json), [log](pairing.log); brak zapisywania QR |
| Pakowanie i instalator | [install-tests.log](install-tests.log): 15 PASS |

Polecenia: [TESTING.md](../../../signal/TESTING.md#okno-wiadomości--po-s04).
Bramka QML działała w sandboxie. Prywatny D-Bus wymagał dopuszczenia socketów
poza sandboxem; wszystkie natywne testy zachowały prywatne XDG i offscreen.
Jedyną dopuszczoną wiadomością platformy jest znany brak obsługi masek okien.

Test natywny rozwiązuje nazwę bez wysyłki, tworzy pusty czat, wysyła jedną
wiadomość przez trwały outbox, odbiera 65 przy zamkniętym oknie i sprawdza
strony 50+16. IPC i bezpośredni routing nie tworzą drugiego okna/odbiorcy.
Obce konto jest odrzucane; hard reload zachowuje szkic i usuwa stary proces.
Są to testy atrapy CLI, nie potwierdzenie wymiany z telefonem.

Kontroler ma testy dwóch sztucznych ekranów i przywołania okna po PID;
nie jest to odbiór na fizycznym kompozytorze. IME: sprawdzono gałąź preedit,
bez uruchamiania zewnętrznego silnika IME. Standardowe klawisze przechodzą
przez QtTest. Tekst Unicode przetrwał zapis, ale japońskie glify są nieobecne
w fontach hosta i na zrzutach widać ich zastępniki. Nie instalowano fontów.
Powiadomienia/quick reply należą do S05, semantyka read/unread do S06.
