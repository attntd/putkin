# Etap 08 — dowody Bluetooth

Podglądy są renderami produkcyjnych widoków na MockBluetoothBackend,
prywatnych XDG i D-Bus, offscreen/software. Nie są zrzutami aktywnego
pulpitu ani potwierdzeniem działania radia. Obejrzano wszystkie siedem
obrazów i porównano styl z referencją (3): Mocha, kwadratowe rogi,
wspólne tokeny i wyraźny fokus.

| Scenariusz | Rozmiar logiczny / skala | Obraz i log |
| --- | --- | --- |
| Radio, sparowane urządzenia, bateria komputera i peryferium | 1920×1080 / 1 | [Obraz](08-bluetooth-1920.png), [log](08-bluetooth-1920.log) |
| Wybór jednego z dwóch adapterów | 1366×768 / 1,25 | [Obraz](08-bluetooth-multiple.png), [log](08-bluetooth-multiple.log) |
| Radio wyłączone | 1366×768 / 1,5 | [Obraz](08-bluetooth-off.png), [log](08-bluetooth-off.log) |
| Brak BlueZ | 1366×768 / 1 | [Obraz](08-bluetooth-unavailable.png), [log](08-bluetooth-unavailable.log) |
| Brak opcjonalnego Bluemana | 1366×768 / 1 | [Obraz](08-bluetooth-manager.png), [log](08-bluetooth-manager.log) |
| Mały panel przewinięty do urządzenia | 320×220 / 2 | [Obraz](08-bluetooth-small.png), [log](08-bluetooth-small.log) |
| Oczekujące połączenie | 1366×768 / 1 | [Obraz](08-bluetooth-pending.png), [log](08-bluetooth-pending.log) |

Przykładowe polecenia:

```sh
scripts/preview --bluetooth --size 1920x1080 --screenshot docs/evidence/08-bluetooth-1920.png
scripts/preview --bluetooth --scenario bluetoothMultiple --size 1366x768 --scale 1.25 --screenshot docs/evidence/08-bluetooth-multiple.png
scripts/preview --bluetooth --scenario bluetoothDeviceFocus --size 320x220 --scale 2 --screenshot docs/evidence/08-bluetooth-small.png
scripts/test-bluetooth-integration --idle --output docs/evidence/08-bluetooth.json
```

- [Bramka QML](08-check.log).
- [QtTest sekcji Bluetooth](08-qt.log).
- [Pełna regresja](08-tests.log), [pierwsze uruchomienie z błędami testów](08-tests-initial.log).
- [Końcowa integracja natywna, w tym reload podczas operacji](08-bluetooth-validation.json), [log](08-bluetooth-validation.log).
- [Integracja natywna, 20 cykli i pomiar 60 s](08-bluetooth.json), [log](08-bluetooth.log).

Pierwsza pełna regresja ujawniła dwa nieprawidłowe założenia nowych testów:
próbę najechania tooltipu przed przeliczeniem układu po zmianie adaptera
oraz zakładanie stałej kolejności urządzeń ObjectManagera. Test Qt czeka
na układ; integracja identyfikuje urządzenie po nazwie fixture, nie indeksie.
Nie zmieniono wymagań ani nie wyciszono importów/ostrzeżeń QML.

Pomiary dotyczą wyłącznie prywatnego fixture i krótkiego przedziału czasu.
Wayland/layer-shell, fokus obcego programu, mieszane skale fizycznych
monitorów, prawdziwe adaptery/profile Bluetooth i parowanie w Blueman
wymagają osobnego odbioru. Pełne wyniki i ograniczenia: [status](../status.md),
[kontrakt](../bluetooth.md).
