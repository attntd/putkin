# Odbiór `--clean-slate`, 2026-09-22

Wszystkie instalacje i restore dotyczą wyłącznie prywatnego prefiksu
w `/tmp`, wskazanego w `scenario.json`. Scenariusz zawiera sztuczne stare
konfiguracje i canary danych prywatnych; nie pochodzi z profilu użytkownika.
Nie przełączano aktywnego pulpitu i nie zmieniano jego usług.

- `check.log`: `scripts/check`, 272 QML, 0 błędów.
- `clean-slate-tests.log`: 13 testów rzeczywistych operacji na plikach,
  przerwania procesu i granic czyszczenia; polecenia usług mają atrapy.
- `install-tests.log`: 19 wcześniejszych testów instalatora.
- `regression-tests.log`: 29 testów dotfiles, bootstrapu Signala,
  zgodności danych i natywnego preflight.
- `dotfiles-final-tests.log`: 9 testów dotfiles ponowionych po dodaniu
  metadanych celu katalogu; nie są doliczane ponownie do 61 testów.
- `install.log`, `acceptance.json`: pełna instalacja ze starymi plikami,
  173 zgodne konfiguracje, 11 prywatnych plików bez zmiany inode/mtime.
- `restore.json`, `restore-acceptance.json`: przywrócenie całej lokalnej
  kopii, 19 oryginalnych plików i powiązania starej usługi.
- `reinstall.log`, `summary.json`: ponowna czysta instalacja po restore,
  173 zgodne pliki i runtime po rzeczywistej walidacji.

Polecenie instalacji używało `--clean-slate --destination PREFIX --offline
--signal-runtime RUNTIME`. Przypięty CLI/JRE pochodził ze zweryfikowanej
prywatnej instalacji z wcześniejszego odbioru bootstrapu. Nie wymagano
sieci ani ponownego pobrania. `restore-config --destination PREFIX
--backup BACKUP` przywrócił oryginały. Walidacja używała bubblewrap
bez sprzętu/PAM/systemowego D-Bus i nie uruchamiała pełnego shella.
