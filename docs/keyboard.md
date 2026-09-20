# Klawiatura — 2026-09-17

Sekcja Ustawienia → Klawiatura przypisuje skrót i komendę `:` do gotowego
działania. Katalog `core/Actions.js` obejmuje 55 działań: launcher, schowek,
komendy, ustawienia, panele audio/baterii/Quick Settings, pasek, powiadomienia
i DND, screenshot, audio/mikrofon, jasność, blokadę/menu sesji, wyłączenie
(`shutdown` i `poweroff`), uśpienie, hibernację, restart, fokus/przenoszenie okien,
pływanie/pełny ekran, workspace 1–10 oraz przeniesienie okna do workspace.
Własne dispatchery, polecenia powłoki i edytor istniejącego pliku Hyprlanda
nie są częścią tego zakresu. Pozostałe skróty użytkownika pozostają w jego
konfiguracji; konflikt z nimi blokuje przypisanie w Putkinie.

Użytkownik wybiera działanie, edytuje pola „Skrót klawiszowy” i „Komenda :”,
a następnie zapisuje. Puste pole usuwa dane przypisanie. Klawisze h/j/k/l
nawigują listą i przyciskami, Enter wybiera/potwierdza, a litery w polach
pozostają tekstem. Nie dodano podpowiedzi ani tooltipów.

## Zapis i wykonanie

`$XDG_CONFIG_HOME/putkin/keyboard.json` ma `schemaVersion: 1` i `bindings`:
po jednym rekordzie `{action, shortcut, command}` dla każdego działania.
Wygląd zachowuje dotychczasowy `settings.json`; nie ma migracji jego schematu.
Otwarcie okna nie tworzy pliku. Komenda ma postać `:nazwa` (litery ASCII,
cyfry, `-`, `_`, maks. 40 znaków po dwukropku); normalizujemy wielkość liter.
`:a`, `:f`, `:c`, `:w`, `:mw` i `:wN`/`:mwN` są zarezerwowane.

Skróty używają Super/Control/Ctrl/Alt/Shift i nazwy klawisza XKB;
`Super + :` oraz `Super + Shift + ;` normalizują się do
`SUPER + SHIFT + semicolon`. Samodzielne Print, F1–F35 i klawisze XF86 są dozwolone.
Zapis odrzuca duplikaty, nieznane klawisze i konflikty z kompozytorem,
również gdy cudzy skrót używa fizycznego kodu klawisza lub innej submapy.

`KeyboardSettings` sprawdza konfigurację i zleca kontrolę konfliktów.
`SettingsFile` zapisuje atomowo, chroni cudze edycje i potwierdza zawartość
odczytem. Dopiero wtedy jednorazowy `services/keyboard.py` aktualizuje
własne uchwyty Lua; odczyt `hyprctl binds` potwierdza rezultat. Awaria
aktywacji pozostawia błąd i możliwość ponowienia; sam zapis pliku nie jest
potwierdzeniem aktywnych skrótów. Nie ma nowego daemona ani pollingu.
Reload Hyprlanda zgłasza zdarzenie, po którym wracają zapisane przypisania.
Restart Quickshella ponownie odczytuje plik.

Launcher komend ma domyślnie `SUPER + semicolon` (Super+; bez Shift).
Komendy domyślne to `:settings`, `:lock`, `:shutdown`, `:poweroff`, `:sleep`,
`:hibernate`, `:reboot` oraz `:screenshot`; screenshot zachowuje `Print`.
Odczyt kompletnego poprzedniego katalogu 49/50 działań dodaje nowe rekordy
w pamięci oraz uzupełnia puste komendy ustawień i blokady. Stary domyślny
skrót komend zmienia się na Super+;, jeśli nie zajmuje go inne działanie.
Własne przypisania pozostają; zajęte nazwy nowych komend nie są nadpisywane.
Niepełna/uszkodzona lista nadal jest błędem. Zapis z edytora utrwala 55
rekordów. Późniejsze świadome usunięcie lub zmiana przypisania pozostaje
zachowane. Cudzy Print jest konfliktem, tak jak inne przypisania;
adapter nie usuwa obcych skrótów.

`config/menu-keybinds.lua` rejestruje siedem początkowych uchwytów z opisem
`Putkin:<action>`. Adapter usuwa/odtwarza tylko te uchwyty i zachowuje dane
do rollbacku nieudanego wywołania Lua. Dodatkowy istniejący Super+Shift+B
pozostaje skrótem paska w konfiguracji Hyprlanda. Walidacja i aktywacja
ponownie sprawdzają konflikty, także między zapisaniem pliku a zastosowaniem.

Skróty wywołują `actions invoke <id>`. Launcher wyszukuje wyłącznie dokładnie
przypisaną komendę; Enter wykonuje ją przez ten sam `ActionController`.
Komendy Hyprlanda zachowują okno i monitor sprzed otwarcia launchera.
Otwieranie kolejnego panelu jest odroczone do zamknięcia starego launchera,
aby jego sygnał aktywacji nie zamknął nowego widoku. Komendy niepełne niczego
nie wykonują i nie pokazują pomocy. `:shutdown`, `:poweroff` i `:reboot`
otwierają potwierdzenie odpowiedniej operacji w menu sesji. `:sleep` i
`:hibernate` czekają na potwierdzoną blokadę przed wysłaniem żądania logind.

## Sprawdzone API

Lokalnie: Quickshell 0.3.1, Qt 6.11.2, Hyprland 0.56.2.
[FloatingWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/),
[HyprlandToplevel i lastIpcObject](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandToplevel/),
[uchwyty skrótów 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/objects/LuaKeybind.cpp),
[dispatchery 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsDispatchers.cpp).
Przywołanie istniejącego okna wymaga natywnego fokusu Hyprlanda; zwykłe
żądanie aktywacji Qt na Waylandzie nie dawało tego efektu. `SettingsFocus`
odświeża dane topleveli, sprawdza tytuł, PID procesu i żywy adres okna.
