# Etap 09 — dowody powiadomień i DND

Podglądy renderują produkcyjne widoki na MockNotificationBackend, w prywatnych
XDG i D-Bus, offscreen/software. Nie uruchamiają serwera hosta. Obejrzano
wszystkie sześć obrazów i odniesiono wygląd do referencji (2) i (3):
nieprzezroczyste Mocha, kwadratowe rogi, cienka ramka akcentu, wspólne tokeny
i czytelny fokus. To nie jest odbiór okien/fokusu kompozytora.

| Scenariusz | Rozmiar logiczny / skala | Obraz i log |
| --- | --- | --- |
| Toast z aplikacją, ikoną, treścią, czasem i akcjami | 1920×1080 / 1 | [Obraz](09-notification-1920.png), [log](09-notification-1920.log) |
| Długi tekst i obraz, przewinięcie do ósmej akcji | 1366×768 / 1,25 | [Obraz](09-notification-long.png), [log](09-notification-long.log) |
| Mały ekran, stały nagłówek i widoczna ósma akcja | 320×220 / 2 | [Obraz](09-notification-small.png), [log](09-notification-small.log) |
| Krytyczne powiadomienie pomimo DND | 1366×768 / 1,5 | [Obraz](09-notification-critical.png), [log](09-notification-critical.log) |
| DND w Quick Settings, zwykłe powiadomienia wygaszone | 1920×1080 / 1 | [Obraz](09-notification-dnd.png), [log](09-notification-dnd.log) |
| Inny właściciel nazwy, komunikat i wyłączone DND | 1366×768 / 1,25 | [Obraz](09-notification-unavailable.png), [log](09-notification-unavailable.log) |

Polecenia odtwarzające podglądy i pomiar:

```sh
scripts/preview --notifications --scenario notification --size 1920x1080 --screenshot docs/evidence/09-notification-1920.png
scripts/preview --notifications --scenario notificationLong --size 1366x768 --scale 1.25 --screenshot docs/evidence/09-notification-long.png
scripts/preview --notifications --scenario notificationLong --size 320x220 --scale 2 --screenshot docs/evidence/09-notification-small.png
scripts/preview --notifications --scenario notificationCritical --size 1366x768 --scale 1.5 --screenshot docs/evidence/09-notification-critical.png
scripts/preview --notifications --scenario notificationDnd --size 1920x1080 --screenshot docs/evidence/09-notification-dnd.png
scripts/preview --notifications --scenario notificationUnavailable --size 1366x768 --scale 1.25 --screenshot docs/evidence/09-notification-unavailable.png
scripts/test-notifications-integration --idle --output docs/evidence/09-notifications.json
```

- [Bramka: 115 plików QML, PASS](09-check.log).
- [Pełna regresja: 194 wyniki Qt, 6 regresji Python i wszystkie integracje, PASS](09-tests.log).
- [19 wyników Qt powiadomień — wyciąg z pełnej regresji](09-qt.log).
- [Natywny protokół: 12 grup, 20 cykli i 60 s spoczynku, PASS](09-notifications.json), [log](09-notifications.log).
- [Pierwszy test Qt z nieprawidłowym zdarzeniem Shift+Tab](09-qt-initial.log).
- [Pierwsza integracja z awarią po dużym obrazie](09-notifications-initial.json), [log](09-notifications-initial.log), [stos GDB](09-initial-gdb.log).
- [Pierwszy pomiar z błędną klasyfikacją oczekiwanego braku Pythona](09-notifications-idle-initial.json), [log](09-notifications-idle-initial.log).

Finalny test rzeczywistych klientów sprawdza create/replace/actions,
expire/dismiss/client close, brakujące dane, powrót klienta, timeout 6000 ms
i 0, resident/transient, DND/krytyczne, zalew 100 zdarzeń i obraz RGBA
2048×1024 (8 MiB) wraz z zastąpieniem. Sprawdza też istniejącego właściciela
z allow-replacement, brak przejęcia po jego późniejszym odejściu, reload
i zwolnienie obserwatorów. Znacznik treści nie wystąpił w argv, logach,
cache ani prywatnych plikach XDG.

Końcowy pomiar **60,000732 s**: shell +1 tick CPU, obserwator +0;
RSS shella 103 068 → 103 196 KiB, obserwatora stałe 27 544 KiB.
W 20 cyklach RSS shella 136 344 → 135 552 KiB, maksymalnie 136 344 KiB.
Zarejestrowano i zakończono 11 własnych procesów; nie pozostały żadne PID-y.
Nie jest to dowód braku wycieków w wielogodzinnej sesji ani ograniczenie
pamięci dowolnie dużego pojedynczego payloadu.

Wayland/layer-shell, fokus obcej aplikacji, fizyczny hotplug i mieszane skale
wymagają osobnego odbioru. Nie wykonano przełączenia serwera na pulpicie.
Pełne wyniki, poprawki i ograniczenia: [status](../status.md),
[kontrakt i migracja](../notifications.md).
