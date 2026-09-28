# Rozmowy Signal — dowody lokalne

Testy używają danych syntetycznych, prywatnych XDG/D-Bus i wirtualnego audio.
Pliki `live-*` dokumentują późniejszą, zleconą aktywację na pulpicie
i odczyt metadanych gotowości. Nie ma danych konta, kontaktów, nagrań
ani próby rozmowy z telefonem.
[Wyniki i ograniczenia](../../status.md#rozmowy-głosowe-signal--2026-09-26),
[opis wykonania](../../signal/CALLS.md).

- `check-final.log`: pełna bramka QML.
- `signal-regression-final.log`: regresje Python; `python.log`: końcowe
  testy połączeń po korektach; `runtime-verification.log`: uszkodzony tunel.
- `qml.log`: końcowe połączenia; `qml-*.log`: regresje pozostałych funkcji.
- `messages-integration.json`: produkcyjne okno/bridge z syntetycznym CLI.
- `java-contract.log`: prawdziwy serializer i polityki poprawionego CLI.
- `rust-tests.log`: testy przypiętego i poprawionego tunelu.
- `native-audio.json` i `native-audio.log`: procesy PCM, wirtualne moduły
  RingRTC, mute i sprzątanie. Bez pomiaru próbek i transmisji przez Signal.
- `reproducible-*.log`: budowanie CLI/JRE oraz tunelu z cache offline.
- `install-tests.log`, `install-final.log`, `package-verification.json`:
  instalacja wyłącznie do prefiksu `artifacts/signal-calls/install`.
- `capture-final.log`, `incoming-*.png`, `connected-*.png`: syntetyczny
  wygląd okna przy 320 i 980 px; powstały przez Qt `grabToImage`.
- `live-install-plan.json`, `live-before.json`, `live-install.log`,
  `live-activation.json`: instalacja na pulpicie, dwukrotna kontrola
  gotowości i zgodności źródeł oraz zachowanie preferencji.

Aktywacja przełączyła kod shella i przypięty CLI/JRE; zachowała ustawienia,
bieżące konto i historię, bez cofania danych protokołu. Nie wykonywano
wysyłek ani rozmowy testowej. Natywne biblioteki w testach zgłaszają
ostrzeżenia zapisane w logach; nie usuwano ich filtrami.
