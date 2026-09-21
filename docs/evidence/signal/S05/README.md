# S05 — dowody syntetyczne, 2026-09-20

Wyniki dotyczą źródeł w checkoutcie signal. Nie użyto konta ani telefonu,
nie wdrażano shella. XDG i D-Bus są prywatne, okna offscreen.

| Dowód | Co faktycznie sprawdzono |
| --- | --- |
| [check-final.log](check-final.log), [focus-check.log](focus-check.log) | 243 QML oraz końcowy guard pustej usługi w NotificationFocus |
| [python-tests.log](python-tests.log) | 62 testy procesu, SQLite/outboxu, parowania i S05 |
| [history-clear-tests.log](history-clear-tests.log) | Usunięcie także szkicu reply i preferencji wyciszenia, brak tekstu w DB/WAL |
| [signal-notifications-final.log](signal-notifications-final.log) | 10 wyników QML; realne karty/edytor/klawiatura, atrapy usług |
| [qml-tests-final.log](qml-tests-final.log) | Końcowa pełna regresja QML: 628 PASS, 0 FAIL/SKIP |
| [notifications.json](notifications.json), [log](notifications.log) | Produkcyjne QML/bridge/SQLite, atrapa CLI, jeden prawdziwy serwer powiadomień na prywatnym busie, hard reload/unknown/cleanup |
| [reply](notifications-reply.png), [unknown](notifications-unknown.png) | Rzeczywiście wyrenderowane karty z danymi syntetycznymi |
| [external-notifications.json](external-notifications.json) | 13 scenariuszy protokołu obcych klientów, 20 lifecycle, brak pozostałych PID |
| [messages-regression.json](messages-regression.json) | Regresja natywnego okna S04, stron i szkicu |
| [install-tests.log](install-tests.log) | 15 testów pakowania/instalatora w prywatnych katalogach |

Pierwszy pełny [qml-tests.log](qml-tests.log) to **nieudany przebieg**:
439 PASS / 189 FAIL, null service w NotificationFocus dawnych podglądów.
Dodano guard i uruchomiono cały zestaw ponownie. `check.log` to wcześniejszy
nieudany lint typowania wyłącznie entrypointu testowego; poprawiono rzutowanie.
`check-targeted.log` i `notifications-regression.log` są próbami częściowymi.
`python-targeted.log` zawiera także ponownie odkryte testy S02 (łącznie 23);
końcowy nowy moduł ma 6 testów i nie duplikuje S02 w zestawie 62.

Natywny runner toleruje wyłącznie dokładnie znane ostrzeżenie offscreen
o maskach okien. Test obcego protokołu ma osobno zapisany oczekiwany błąd
celowo niedostępnego obserwatora; brak innych diagnostyk. Pierwsza próba
D-Bus w sandboxie nie mogła utworzyć socketu; zaakceptowane uruchomienia
z dostępem do lokalnego socketu zachowały wszystkie prywatne magistrale.

Granice: brak fizycznego Waylanda/IME/hotplug/telefonu; test kontrolera
na atrapach nie jest ich odbiorem. Komendy i interpretacja:
[TESTING.md](../../../signal/TESTING.md#powiadomienia-i-quick-reply--po-s05),
[STATUS.md](../../../signal/STATUS.md#s05--powiadomienia-i-quick-reply--2026-09-20).
