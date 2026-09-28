# Karty i zarządzanie rozmowami — dowody

Materiały testowe używają wyłącznie atrap rozmów, profili, wiadomości i kont.
Qt używa prywatnych XDG/D-Bus; native Wayland działa w osobnym bubblewrap.
Po testach użytkownik zlecił instalację. `install-plan.json`, `install.log`
oraz `activation-before.json`/`activation.json` dokumentują rzeczywistą
aktualizację i migrację v8→v9. Odbiór zawiera statusy i sumy ustawień,
bez treści rozmów, profili i kluczy.

Końcowe wyniki opisuje [status](../../status.md#karty-archiwum-i-zarządzanie-rozmowami--2026-09-28).
`check-final.log` obejmuje cały projekt, `check-scrollbar.log` ostatnią
korektę wspólnego paska i jego klienta testowego.
`conversations.log` i pozostałe logi nazwane jak pakiety zawierają pełny
wynik każdego pakietu QML. Zbiorcze `qml-*.log` zachowują również
wcześniejsze przebiegi i przyczynę kolejnych poprawek.

`python-signal.log` to pełny przebieg 198 testów; sześć niepowodzeń
uruchomienia podprocesów w sandboxie powtórzono w
`python-sandbox-retry.log`. `python-final.log` zawiera końcowy pakiet
nowych zachowań i migracji. `integration-final.json/.log` używają
produkcyjnego QML, bridge i SQLite, ale syntetycznego CLI.

`input-final/input.log` to rzeczywiste zdarzenia Qt, a `wayland/` zawiera
testy klawiatury i zrzuty natywnego okna. `rail.png`, `archive.png`,
`pinned.png` i `header-*.png` pokazują nowe elementy. Historyczne dowody
z wcześniejszych dni zachowują wcześniejszą zawartość.

Logi `*-initial`, `*-diagnostic*`, `ui-debug`, `check-ui` oraz `input-run`
zachowują próby, które doprowadziły do poprawek; nie są wynikiem odbioru.

Polecenia odtworzenia głównych sprawdzeń:

```sh
scripts/check
python3 -m unittest discover -s tests -p 'test_signal_*.py' -v
scripts/test-signal-messages --output artifacts/conversations/integration.json
scripts/test-messages-input --output artifacts/conversations/input
scripts/test-wayland --nested --signal --output artifacts/conversations/wayland
```

Nowe pakiety `tst_conversations.qml` i `test_signal_conversations.py`
są też automatycznie zbierane przez `scripts/test`. Pakiety QML tego
odbioru uruchamiano osobno przez `qmltestrunner` z `isolated_environment`
z `scripts/_common.py` i `dbus-run-session`.
