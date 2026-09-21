# Układ okna wiadomości — 2026-09-21

Zmiany na życzenie użytkownika: wyłącznie ramka okna Hyprlanda,
Szczegóły po prawej w nagłówku, ⋯ w prawym górnym rogu wiadomości,
reakcje po lewej obok godziny i stanu, własne dymki w kolorze akcentu,
composer od 36 px rosnący z tekstem, znikanie przeniesione do Szczegółów.
Usunięto dodatkowy obrys także z podglądu załącznika i Szczegółów.

## Sprawdzenie

- `scripts/check`: **272 QML, 0 błędów** (`check.log`). Po korekcie sondy
  i testu grup osobno oba pliki: **2 PASS** (`check-fixtures.log`).
- `scripts/test-icons --file … --log …`: **44 PASS**, bez błędów QML.
  `tst_messages.qml` — 9 (`messages-qt-final.log`),
  `tst_signal_retention.qml` — 8 (`retention-qt.log`),
  `tst_signal_interactions.qml` — 7 (`interactions-qt.log`),
  `tst_signal_media.qml` — 6 (`media-qt.log`),
  `tst_signal_receipts.qml` — 6 (`receipts-qt.log`),
  `tst_signal_groups.qml` — 8 (`groups-qt-final.log`).
- `scripts/test-wayland --nested --signal --output docs/evidence/signal/S12/ui-layout/wayland`:
  **PASS**, kod 0, prywatne XDG/D-Bus, prawdziwy Hyprland i GPU.
  Keyboard/Unicode/Shift+Enter, quick reply, zmiana obu akcentów,
  resize, skala 1,5, hotplug, lock/redakcja i reload zachowują działanie.
  `wayland/signal-report.json` i `wayland/cleanup.json` zawierają wyniki
  i potwierdzenie usunięcia prywatnej sesji.

Obejrzano `wayland/messages-empty-composer.png`, `messages-multiline.png`,
`messages-small.png`, `messages-scale-1.5.png`, `messages-after-reload.png`
oraz `conversation-details.png`. Widoczny jest nowy układ nagłówka, menu,
reakcji, kontrast tekstu na obu akcentach i jednakowa wysokość pustego
composera/przycisków. Dłuższy tekst zwiększa wysokość pola; znikanie jest
w Szczegółach. Małe okno zachowuje kotwicę historii, a ponowne otwarcie
pokazuje jej koniec. Wszystkie zrzuty i wiadomości są syntetyczne.
Zrzut prywatnej rozmowy od użytkownika nie został skopiowany do dowodów.

## Poprawione próby

Pierwszy wariant układu dymka z RowLayout powodował odroczoną zmianę
wysokości i błędy kotwiczenia. Zastąpiono go bezpośrednią geometrią
Item/Column/Row; wcześniejszy `messages-qt.log` zachowuje porażkę,
a końcowy przebieg zalicza oba scenariusze przewijania.

Test grup oczekiwał zmiany koloru usuniętej ramki. Teraz sprawdza podgląd
akcentów na rzeczywistym fokusie pola nazwy grupy (`groups-qt.log` →
`groups-qt-final.log`). Test znikania otwiera najpierw Szczegóły.
Harness Waylanda dostał syntetyczne własne wiadomości, reakcję i obraz
oraz zrzuty pustego/długiego composera i Szczegółów. W przygotowaniu
harnessu poprawiono powieloną nazwę metody IPC, odczyt fokusu przed
mapowaniem okna oraz uprawnienia 0700 testowego katalogu załączników.
Końcowy przebieg przechodzi bez ostrzeżeń QML.

## Wdrożenie

`activation.log` zapisuje wynik `scripts/install --activate`.
Bieżący build i beztreściowy stan usługi zapisuje `live-status.json`.
Zmiany nie wymagają migracji SQLite ani ponownego parowania.
Wdrożono **`20260921-104858-36c9df96d894`**, kod instalatora 0,
167 QML pakietu bez błędów. Po aktywacji Signal **ready/linked**, kody
błędów puste, Caffeinate `presentation`; osiem plików QML katalogu
messages ma identyczne sumy w źródłach i wydaniu. Zachowano pięć buildów.
Powrót: `20260921-091350-39f9ddda75b4`.
