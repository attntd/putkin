# Wskaźnik pisania Signal — 2026-09-26

- `live-before.json`: odczyt metadanych awarii, bez wiadomości i tożsamości konta.
- `before.log`: odtworzone odrzucenie domyślnego CLI i restart po zmianie preferencji.
- `python.log`: końcowa regresja, 53 testy konta, runtime, interakcji i rozmów.
- `settings-qml.log`: 12 wyników QtTest, w tym mysz i klawiatura przełącznika.
- `settings-integration.json` i `.log`: rzeczywiste okno ustawień z bridge,
  prywatne XDG/D-Bus i jawna atrapa CLI; 7 grup, brak błędów QML i procesów po zamknięciu.
- `check.log`: 282 QML, zero błędów.
- `private-install.log`, `packaged-runtime.json`: gotowy pakiet w prywatnym
  prefiksie i rzeczywisty CLI/JRE, 175 QML i 375 plików zgodnych ze źródłami.
- `install-plan.json`, `live-install.log`, `live-activation.json`: plan,
  udana aktywacja po odblokowaniu pulpitu i odbiór dwoma odczytami w odstępie
  10 s. Signal `ready/linked`, bez błędów/ostrzeżeń, zachowane preferencje.

`fix.log` zawiera wczesny przebieg, w którym test wybierał zaległe zdarzenie
startu sprzed przełączenia; poprawiono zakres obserwacji. `python-first.log`
ujawnił zmianę semantyki jawnego wyłączenia usługi; zachowano poprzednie
zachowanie dla ustawień innych niż wskaźnik i powtórzono cały celowany zestaw.

Testowe rozmowy i wskaźniki trafiały wyłącznie do atrap, bez sprzętu audio.
Odbiór pulpitu odczytuje stan i skróty plików preferencji, nie wykonuje
rozmowy ani wysyłki. Pełny zestaw `scripts/test`, natywny Wayland i rozmowa
z prawdziwym urządzeniem pozostają niewykonane w tej korekcie.
