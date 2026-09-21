# S08 — dowody interakcji

2026-09-21, checkout `/home/attntd/projects/signal`. Wyłącznie syntetyczne
konta, treści i pliki. Bez połączenia telefonu, wysyłki do kontaktów,
aktywacji pulpitu i commita. Qt działa offscreen, z prywatnymi XDG/D-Bus;
backend używa rzeczywistego SQLite/pipe i atrapy signal-cli.

## Wyniki

| Sprawdzenie | Wynik | Dowód |
| --- | --- | --- |
| Składnia/importy checkoutu | 252 pliki QML, 0 błędów | [check.log](check.log) |
| Pełny backend | 111 PASS | [python-final.log](python-final.log) |
| Celowane interakcje, bridge i typing | 19 PASS | [interactions-final.log](interactions-final.log) |
| Pełny QtTest | 650 PASS, 0 FAIL/SKIP | [all-qml-final.log](all-qml-final.log) |
| Interakcje QtTest | 7 PASS, 0 FAIL/SKIP | [interactions-qml-final.log](interactions-qml-final.log) |
| Powiadomienia i quick reply QtTest | 13 PASS, 0 FAIL/SKIP | [notifications-qml-final.log](notifications-qml-final.log) |
| Widoczny zakres i receipts QtTest | 6 PASS, 0 FAIL/SKIP | [receipts-qml-final.log](receipts-qml-final.log) |
| Natywne okno S08, SQLite i bridge | PASS, zero błędów QML i osieroconych procesów | [integration-final.json](integration-final.json), [log](integration-final.log) |
| Regresja natywnego S06 | PASS, zero błędów QML i osieroconych procesów | [receipts-regression-final.json](receipts-regression-final.json) |
| Regresja natywnych mediów S07 | PASS, zero błędów QML i osieroconych procesów | [media-regression-clean.json](media-regression-clean.json) |

Wyniki QtTest obejmują init/cleanup. Osobny zestaw interakcji zawiera
5 funkcji testujących i 2 lifecycle. Końcowy runner S08 wykonano ponownie
po zmianach zamykania widoku i kompozytora; zrzuty [edycji](editor.png)
oraz [reakcji](reactions.png) pochodzą z tego przebiegu. To rzeczywiste
okno Qt offscreen, nie makieta ani dowód działania kompozytora Waylanda.

## Co sprawdzono

- Edycje w odwrotnej kolejności, także przed bazową wiadomością, duplikaty,
  spóźnioną wersję, własność autora i trwałość po restarcie. Stały messageId
  i kolejność, brak nowej wiadomości/unread/toasta. Własny sent sync
  przed wynikiem RPC uzgadnia tę samą wersję.
- Reakcje wielu autorów, zmiana i cofnięcie własnej, rozdzielenie aktora
  od autora celu, odwołania do wersji, VS/ZWJ/odcień skóry i flagi.
  1:1, grupa i Notatka; nieznane zdarzenia czekają z ograniczonym TTL.
- Trwałe operacje w jednym senderze, rzeczywiste parametry send z
  editTimestamp i sendReaction, idempotentny operationId. Definitywna
  odmowa/retry/cancel, timeout/restart/partial -> unknown bez ponownego
  wysłania i bez fikcyjnej zmiany treści. Limit edycji sprawdzany również
  przed dispatch; Notatka ma wyjątek czasu.
- Receipts konkretnej wersji: stary read nie oznacza odczytania edycji;
  grupowa edycja zachowuje własną listę wyników wysyłki. Edycja podpisu
  zachowuje trwałe pliki, nie resetuje deadline znikania. Redakcja usuwa
  treść wersji i nie pozwala wskrzesić jej spóźnionym zdarzeniem.
- Cytat z poprawnym autorem/timestampem, lokalna nawigacja, brak oryginału
  bez fabrykowania historii, odświeżenie po późniejszym nadejściu celu.
  Wzmianki grupy ze znanych członków, offsety UTF-16 po emoji, trwały
  szkic cytatu/wzmianek i wyczyszczenie kompozycji po send.
- Osobny edytor własnej wiadomości, Anuluj/Escape, zachowanie zwykłego
  szkicu i błędu, standardowe hjkl i Shift+Enter, wybór reakcji/wzmianki.
  Bezpieczne escapowanie HTML i kontrolowane style; oba żywe akcenty.
- Aktywny fokus głównego edytora i quick reply, ograniczenie częstotliwości,
  STOP przy blur/lock/send, wyłączona preferencja i disconnect. Odbiór
  typing nie tworzy rozmów, historii ani unread; runner czeka rzeczywiste
  15 sekund na wygaśnięcie bez STOP.
- Aktualizacja istniejącego powiadomienia po edycji i reakcji przy
  zamkniętym oknie. Hard reload przywraca wersje/reakcje/cytat z SQLite,
  sprząta stary bridge i nie powtarza operacji.

## Polecenia

```sh
python3 scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 -B -m unittest discover -s tests -p test_signal_interactions.py -v
python3 scripts/test-icons --all-qml --timeout 600 --log docs/evidence/signal/S08/all-qml-final.log
python3 scripts/test-icons --file tst_signal_interactions.qml --log docs/evidence/signal/S08/interactions-qml-final.log
python3 scripts/test-icons --file tst_signal_notifications.qml --log docs/evidence/signal/S08/notifications-qml-final.log
python3 scripts/test-icons --file tst_signal_receipts.qml --log docs/evidence/signal/S08/receipts-qml-final.log
python3 scripts/test-signal-interactions --output docs/evidence/signal/S08/integration-final.json
python3 scripts/test-signal-receipts --output docs/evidence/signal/S08/receipts-regression-final.json
python3 scripts/test-signal-media --output docs/evidence/signal/S08/media-regression-clean.json
git diff --check
```

Prywatny D-Bus i lokalny socketpair asyncio wymagały dopuszczenia poza
sandboxem sieciowym; izolacja danych i atrapa pozostały bez zmian.
Nowy runner jest częścią `scripts/test`. Nie uruchamiano całego agregatora
obejmującego pozostałe natywne moduły shella i instalator.

## Początkowe błędy i granice

Pierwsze przebiegi nie były zielone. [Backend](python-initial.log) i
[historia](history-initial.log) wykazały stare fixture migracji/schema4
oraz blokadę lokalnego socketpair w workerze mediów. Fixture uwzględniają
v5; końcowe testy mają dopuszczony lokalny transport. Wczesne logi
interactions i messages zachowują błędy powstałe podczas implementacji.

Pierwszy pełny [QtTest](all-qml.log) miał 646 PASS i 2 FAIL dotyczące
przewijania. Po rozszerzeniu wierszy ustabilizowano kotwicę historii i
obsługę zakończenia widoku; test programowego przewijania jawnie wyłącza
followEnd i czeka na układ przed zachowanymi asercjami widoczności.
Próba naprawy timerem dawała ostrzeżenie QUnifiedTimer w
[media-regression-final.log](media-regression-final.log). Zastąpiono ją
koaleskowanymi callbackami Qt.callLater z kontrolą życia obiektu.
Końcowy natywny przebieg mediów jest czysty; nie dodano filtra ostrzeżeń.

Odczytano dokładne źródła CLI v0.14.8, [adres bazowy i hashe](api-provenance.json).
Nadal obowiązuje **0.14.8 JVM + putkin-media-1** z S07; bez nowej poprawki
Java. RPC i ograniczenia opisuje [API.md](../../../signal/API.md).
Limit 10 edycji/24 h jest lokalny, oparty na znanej historii; nie odtwarza
zmian sprzed parowania ani dawnych placeholderów edit_unsupported.

Pisanie ma **lokalny przełącznik, domyślnie wyłączony**. Ta wersja CLI
nie eksportuje ustawienia telefonu ani nie egzekwuje go w sendTypingMessage;
nie obiecujemy synchronizacji tej preferencji. Wybór emoji jest ograniczoną
paletą; odebrane sekwencje Unicode są zachowane. Nie dodano edytora stylów.

Telefon, drugi rozmówca i fizyczny kompozytor pozostają w S11/S12.
Pełna retencja, w tym kopie cytatów, aktywne mutacje i brak eksportu
expirationStartTimestamp, pozostaje **S09**. Nie wykonywano S09.
