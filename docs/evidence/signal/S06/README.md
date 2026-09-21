# S06 — wyniki lokalnego odbioru

2026-09-20, checkout `/home/attntd/projects/signal`. Wyłącznie syntetyczne
konta/treści, prywatne XDG/D-Bus, renderowanie offscreen. Nie parowano
telefonu, nie wysyłano do realnych kontaktów, nie aktywowano pulpitu.

| Komenda / zakres | Wynik | Dowód |
| --- | --- | --- |
| `scripts/check` | PASS, 245 QML | [check-final.log](check-final.log) |
| `python3 -m unittest discover -s tests -p 'test_signal_*.py' -v` | PASS, 77 testów | [python-tests.log](python-tests.log) |
| `PYTHONPATH=tests python3 -m unittest test_signal_receipts test_signal_pairing.PairingTests.test_disable_persists_and_history_deletion_is_separate -v` | PASS, 18 testów po końcowej walidacji wyniku RPC i dodaniu dwóch przypadków | [receipts-final.log](receipts-final.log) |
| `python3 scripts/test-icons --file tst_signal_receipts.qml --log …` | PASS, 6 wyników | [receipts-qml-final.log](receipts-qml-final.log) |
| `python3 scripts/test-icons --file tst_signal_notifications.qml --log …` | PASS, 12 wyników, także 2 nowe scenariusze read/toast | [notifications-qml.log](notifications-qml.log) |
| `python3 scripts/test-icons --all-qml --timeout 600 --log …` | PASS, 636 wyników, 0 FAIL/SKIP | [qml-tests.log](qml-tests.log) |
| `python3 scripts/test-signal-receipts --output …` | PASS, produkcyjne QML/SQLite/bridge, atrapa CLI, realne Qt Window.active/minimized | [receipts.json](receipts.json), [log](receipts.log), [widok](receipts.png) |
| `python3 scripts/test-signal-integration --idle --output …` | PASS, reload/awarie/cleanup; idle 60 s, 0 ticków CPU, 0 nowych procesów/RPC | [integration.json](integration.json), [log](integration.log) |
| `python3 scripts/test-signal-messages --output …` | PASS, regresja okna, stron, szkicu i reloadu | [messages-regression.json](messages-regression.json) |
| `python3 scripts/test-signal-notifications --output …` | PASS, regresja routingu/quick reply/unknown | [notifications-regression.json](notifications-regression.json) |
| `python3 scripts/test-notifications-integration --output …` | PASS, 13 scenariuszy, 20 lifecycle, bez osieroconych procesów | [external-notifications.json](external-notifications.json) |
| `python3 -m unittest discover -s tests -p test_install.py -v` | PASS, 15 testów w prywatnych katalogach | [install-tests-final.log](install-tests-final.log) |

W powyższych komendach `…` oznacza odpowiedni plik tej tabeli, a nie
pominięty krok testu. Pełne komendy odtworzenia: [TESTING.md](../../../signal/TESTING.md#raporty-i-odczyt--po-s06).
Raporty natywne potwierdzają brak pozostawionych bridge/CLI.
Żaden wynik atrapy nie jest odbiorem serwera Signala ani telefonu.

Nowe testy Python obejmują monotoniczne delivery/read/viewed, duplikaty,
wiele timestampów, receipt przed wiadomością i RPC, scalanie sent sync,
częściową grupę/partial send, nieznany mianownik dla grupy telefonu,
rozróżnienie własnych markerów i raportu rozmówcy, read sync przed incoming,
izolację kont/autora/kierunku, brak ACI, trwałe batchowanie po autorach,
limit 100, brak automatycznego powtarzania unknown, usuwanie historii,
migrację v2→v3 i TTL niezwiązanych metadanych. Zestaw 18 obejmuje 17 S06
oraz rozszerzony test czyszczenia historii S03; nie należy dodawać 77+18
jako liczby unikalnych testów.

Natywny runner potwierdza rzeczywisty fokus dwóch okien Qt offscreen,
minimalizację, produkcyjny lock i widoczny zakres. Hyprland, zasłanianie
w fizycznej sesji, DPMS i telefon pozostają S11/S12. Szczególnie niewykonane
są cztery kierunki/prywatności read sync z [macierzy live](../../../signal/TESTING.md#raporty-i-odczyt--po-s06).
Sukces sendReceipt nie dowodzi odebrania self-sync; pusta lista results
z atrapy sprawdza obsługę odpowiedzi przy wyłączonych raportach zewnętrznych.
Audyt oficjalnego tagu 0.14.8 i hashe: [api-provenance.json](api-provenance.json).

Pierwsze próby pozostawiono jako wyniki negatywne:

- [python-initial.log](python-initial.log): 1 błąd starego testu migracji,
  który oznaczył bazę v3 jako v1 bez usunięcia nowych tabel/kolumn.
  Fixture odtwarza teraz rzeczywisty v1; rollback i cały backend przeszły.
- [receipts-qml-initial.log](receipts-qml-initial.log) oraz
  [receipts-qml.log](receipts-qml.log): niepełny monitor testowy i ostrzeżenia
  QUnifiedTimer w teście kart bez ich renderowania. Monitor poprawiono,
  a przypadki kart przeniesiono do istniejącego renderowanego zestawu S05.
  Końcowe testy i pełny QML przechodzą bez pomijania tych ostrzeżeń.
- [messages-initial.log](messages-initial.log), [install-tests.log](install-tests.log):
  sandbox odmówił bind prywatnego socketu D-Bus. Ponowiono z dostępem
  do lokalnego socketu, zachowując prywatne XDG i magistralę.

Runnery Signala dopuszczają wyłącznie znane ograniczenie offscreen
`This plugin does not support setting window masks`. Regresja zewnętrznego
NotificationServer dodatkowo rozpoznaje celowy brak procesu obserwatora
w swoim negatywnym scenariuszu; zapisuje go w expected_diagnostics,
przy pustym unexpected_diagnostics. Nie dodano innych filtrów ostrzeżeń.
`git diff --check` i kompilacja nowych
modułów Python przeszły. Nie utworzono commita ani wydania.
