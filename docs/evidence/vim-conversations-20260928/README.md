# Nawigacja rozmowy i pisanie — dowody

Wszystkie zrzuty i testowe rozmowy są syntetyczne. Qt korzysta z prywatnych
XDG/D-Bus; `wayland-final` działa w osobnym bubblewrap/Hyprlandzie.
Końcowe wyniki opisuje [status](../../status.md#nawigacja-rozmowy-i-pisanie--2026-09-28).

`install-plan.json`, `install.log` i `activation*.json` dokumentują
zleconą instalację `20260928-210607-4d3626da5e34` i odbiór działającej
wersji. Raporty zawierają statusy oraz sumy ustawień, bez treści rozmów
i kluczy konta. Zachowano SQLite v9 i poprzednie wydanie.

- `check-final.log`: pełna bramka 299 QML.
- `qml-focus-final.log`, `message_navigation.log`: 17 PASS po ostatniej
  poprawce usuwania ramki przez mysz oraz powrotu z toolbaru/popupu.
- `qml-final.log`: regresja ośmiu pakietów; dwa niepowodzenia myszy w tym
  przebiegu naprawiono i powtórzono w powyższym końcowym pakiecie.
  Pozostałe siedem pakietów daje 92 PASS. Każdy ma pełny osobny log.
- `wayland-final`: 10 natywnych scenariuszy i raport sprzątania.
  `wayland` zachowuje wcześniejszy udany przebieg.
- `input-final`: rzeczywiste zdarzenia touchpada i myszy oraz klawiatura.
- `ime-input.log`: QInputMethodEvent, Unicode, Enter i rzeczywiste URL drops.
- `integration.json/.log`: produkcyjne okno, bridge i SQLite z atrapą CLI.
- `normal-bubble.png`, `normal-editor.png`, `insert.png`: fokus i natywny
  kursor bez dodatkowej etykiety; `regression` zawiera nowe zrzuty testów
  historycznych, których wcześniejsze dowody przywrócono z kopii sprzed próby.

`*-initial`, `*-target`, `qml-navigation` i `check-focus` to wcześniejsze
próby/diagnostyka. Nie są końcowym wynikiem odbioru.

Polecenia odtworzenia:

```sh
scripts/check
scripts/test-messages-input --output artifacts/vim-messages/input
scripts/test-signal-media-input
scripts/test-signal-messages --output artifacts/vim-messages/integration.json
scripts/test-wayland --nested --signal --output artifacts/vim-messages/wayland
```

Pakiety QML uruchomiono przez qmltestrunner z `isolated_environment`
z `scripts/_common.py` i dbus-run-session. Nowy pakiet jest też zbierany
przez `scripts/test`.
