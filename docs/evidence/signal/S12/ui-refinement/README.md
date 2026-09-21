# Kropki, reakcje i podgląd załączników — 2026-09-21

Po kolejnych uwagach użytkownika:

- Menu ⋯ ma przezroczyste tło bez ramki i wysokość pierwszego wiersza
  treści. Jest jasne na ciemnym dymku i ciemne na jasnym akcencie.
- Reakcje są bez ramki/tła, w tej samej linii co godzina i status.
  Stopka rezerwuje rzeczywistą szerokość reakcji, aby nie zawijać
  niepotrzebnie „Edytowano · Przeczytano”. Fokus klawiatury jest widoczny.
- Kliknięcie miniatury otwiera podgląd. Nazwa, rozmiar i przyciski
  Zapisz/Otwórz/Zamknij występują dopiero w podglądzie. Bez miniatury
  pozostaje klikalny symbol typu załącznika; plik nadal można otworzyć.

Zmiany: `MessageHistory.qml`, `AttachmentCard.qml`, `MediaPreview.qml`.
Test mediów obejmuje kliknięcie i Enter, metadane w podglądzie, delegowanie
otwierania właściwego pliku oraz powrót fokusu po Escape/Zamknij, dla
obrazu i dokumentu. Natywny harness dodaje odczytaną, edytowaną wiadomość
z reakcją i rzeczywisty klik przez prywatny protokół virtual-pointer.

## Weryfikacja

- `scripts/check`: **272 QML, 0 błędów** (`check.log`).
- Cztery zestawy `scripts/test-icons --file … --log …`: **32 PASS**.
  Messages — 9 (`messages-qt.log`), SignalInteractions — 7
  (`interactions-qt.log`), SignalRetention — 8 (`retention-qt.log`),
  SignalMedia — 8 (`media-qt-final.log`). Wcześniejszy `media-qt.log`
  zawiera 7 PASS, przed dodaniem wariantu dokumentu.
- `scripts/test-wayland --nested --signal --output docs/evidence/signal/S12/ui-refinement/wayland`:
  **PASS**, kod 0, bez błędów QML. Prywatny compositor/XDG/D-Bus,
  syntetyczne konto, obraz i wiadomości. Zachowanie quick reply,
  Unicode/Shift+Enter, obu akcentów, resize/skali 1,5, hotplug,
  blokady i restartu także PASS. Sesja testowa usunięta (`cleanup.json`).
- Obejrzane zrzuty: `wayland/messages-empty-composer.png`,
  `wayland/messages-scale-1.5.png` oraz `wayland/attachment-preview.png`.
  Potwierdzają wyrównanie kropek, kolory, reakcję obok pełnego statusu,
  czystą miniaturę i metadane/działania wyłącznie w podglądzie.

`check.log` zapisuje pełną bramkę QML. `activation.log` zapisuje wdrożenie
przez `scripts/install --activate`, a `live-status.json` beztreściowy stan
Signala i zgodność źródeł z wydaniem. Dane użytkownika nie są materiałem
testowym. Zmiana nie wymaga migracji bazy ani ponownego parowania.

Wdrożone: **`20260921-110638-03f24e35e2b4`**, kod instalatora 0,
167 QML pakietu bez błędów. Po wdrożeniu **Signal ready/linked**,
kody błędów puste, Caffeinate `presentation`. Osiem plików QML okna
wiadomości ma zgodne sumy w źródłach i wydaniu. Zachowano pięć buildów;
powrót do `20260921-104858-36c9df96d894`.
