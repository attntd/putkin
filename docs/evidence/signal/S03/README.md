# S03 — odbiór parowania i ustawień

2026-09-20, checkout `/home/attntd/projects/signal`. Wszystkie konta,
kontakty i zdarzenia są syntetyczne. Bez telefonu, ruchu do Signal,
aktywacji pulpitu i zmian w opublikowanych wydaniach.

| Próba | Dowód |
| --- | --- |
| Bramka składni/importów całego projektu | [check.log](check.log) — 225 plików QML |
| Python: S00–S03, bridge/SQLite/transport/parowanie | [python-tests.log](python-tests.log) — 52 testy |
| S03: dekoder QR, cancel/expiry/crash, stan konta i konfiguracja | [pairing-tests.log](pairing-tests.log) — 10 testów |
| Natywne okno ustawień z produkcyjnym bridge i atrapą CLI | [pairing.json](pairing.json), [log](pairing.log), [ustawienia bez QR](pairing.png) |
| QML: cała regresja na atrapach, limit 600 s | [qml-tests-final.log](qml-tests-final.log) |
| Końcowa poprawka stanu próby/expiry: ponowiona sekcja Signal | [signal-settings-final.log](signal-settings-final.log) — 11 wyników |
| Wcześniejsza próba QML, zakończona limitem 240 s | [qml-tests.log](qml-tests.log) — nie liczyć jako PASS |
| Historia/outbox, soft/hard reload, EOF/TERM/KILL i cleanup | [integration.json](integration.json), [log](integration.log) |
| Pakowanie i instalator w prywatnych katalogach | [install-tests.log](install-tests.log) — 15 testów |

Polecenia są w [TESTING.md](../../../signal/TESTING.md#parowanie-i-ustawienia-po-s03).
Pierwsza próba QtTest wewnątrz sandboxa agenta zakończyła się odmową
utworzenia prywatnego socketu D-Bus. Testy natywne wykonano z dopuszczonym
socketem, zachowując odseparowane XDG i D-Bus oraz renderer offscreen.
Jedyny dopuszczony komunikat platformy to dokładny znany komunikat o braku
obsługi masek okien; pozostaje widoczny w logu natywnego okna.

URI i obraz QR nigdy nie są zapisywane w dowodach. Test dekoduje w pamięci
macierz libqrencode przez niezależny ZXing i porównuje dokładną wartość.
Canvas jest sprawdzany przez piksele QtTest w pamięci. Runner natywny
odmawia zrzutu podczas próby i pokazuje jedynie rozmiar macierzy w statusie.

Pomiar 60 s: 0 ticków CPU obu pomocników, 0 nowych procesów/RPC,
0 pozostałych własnych PID. Nie jest to pomiar JVM z kontem ani odbiór
serwerowej synchronizacji; te wymagania pozostają w S12.

Pełny zestaw QML: 601 PASS, 0 FAIL/SKIP w 255,652 s. Końcową poprawkę
obsługi awarii w QML odebrano ponownym testem sekcji Signal i natywnym
runnerem, który zabija własny bridge podczas QR i odzyskuje usługę z UI.
