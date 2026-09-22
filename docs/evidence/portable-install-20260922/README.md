# Instalacja i dotfiles — 2026-09-22

Wyniki dotyczą prywatnych instalacji w `/tmp`, nie aktywacji pulpitu.
`signal-build.log` zawiera pobranie oficjalnych wejść i odtworzenie pinu.
`auto-build-install.log` pokazuje przebieg instalatora z cache zawierającym
wyłącznie pobrania, bez gotowego runtime i bez ręcznej ścieżki patched CLI.
`auto-installed-signal.json` jest próbą końcowego bridge/CLI/JRE z pustym
kontem i wyłączoną siecią. `final-config.json` sprawdza końcowe pliki aplikacji.

Testy i ograniczenia: [status](../../status.md#instalacja-przenośna-i-modułowe-dotfiles--2026-09-22).
`summary.json` zawiera liczby testów i niewykonany zakres. Logi nie zawierają
konta Signal, wiadomości ani kluczy użytkownika. Testy GPG nie tworzyły klucza.
