# Klawiatura — 2026-09-17

Sekcja Ustawienia → Klawiatura przypisuje skrót i komendę `:` do gotowego
działania. Katalog `core/Actions.js` obejmuje 61 przypisań: launcher, schowek,
komendy, Wiadomości, ustawienia, panele Wi-Fi/Bluetooth/audio/baterii/Quick Menu, pasek, powiadomienia
i DND, screenshot, audio/mikrofon, jasność, blokadę/menu sesji, wyłączenie
(`shutdown` i `poweroff`), trzy profile zasilania, uśpienie, hibernację, restart, fokus/przenoszenie okien,
pływanie/pełny ekran, workspace 1–10 oraz przeniesienie okna do workspace.
Własne dispatchery, polecenia powłoki i edytor istniejącego pliku Hyprlanda
nie są częścią tego zakresu. Pozostałe skróty użytkownika pozostają w jego
konfiguracji; konflikt z nimi blokuje przypisanie w Putkinie.

Użytkownik wybiera działanie, edytuje pola „Skrót klawiszowy” i „Komenda :”,
a następnie zapisuje. Puste pole usuwa dane przypisanie. Klawisze h/j/k/l
nawigują listą i przyciskami, Enter wybiera/potwierdza, a litery w polach
pozostają tekstem. Nie dodano podpowiedzi ani tooltipów.

`q` bez modyfikatorów działa jak `Escape`: zamyka panel lub kończy nawigację
po pasku i toastach. W zagnieżdżonym widoku najpierw wraca poziom wyżej,
np. zwija powiadomienie albo wychodzi z podglądu schowka. Skrót nie działa,
gdy fokus jest w polu tekstowym, również polu hasła, polu tylko do odczytu
lub polu z walidacją odrzucającą literę `q`. `Escape` zachowuje dotychczasowe
działanie także w polach tekstowych.

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
`:hibernate`, `:reboot`, `:screenshot`, `:powersaver`, `:balanced`, `:performance`,
`:messages`, `:wifi`, `:bluetooth`, `:volume`, `:battery`, `:notifications` i `:quickmenu`;
screenshot zachowuje `Print`.
Odczyt kompletnego poprzedniego katalogu 49/50 działań dodaje nowe rekordy
w pamięci oraz uzupełnia puste komendy ustawień i blokady. Stary domyślny
skrót komend zmienia się na Super+;, jeśli nie zajmuje go inne działanie.
Własne przypisania pozostają; zajęte nazwy nowych komend nie są nadpisywane.
Kompletny poprzedni katalog 55 przypisań otrzymuje trzy komendy profili
w pamięci, bez zapisu przy odczycie i bez nadpisywania zajętych nazw.
Niepełna/uszkodzona lista nadal jest błędem. Zapis z edytora utrwala 61
rekordów. Późniejsze świadome usunięcie lub zmiana przypisania pozostaje
zachowane. Cudzy Print jest konfliktem, tak jak inne przypisania;
adapter nie usuwa obcych skrótów.

Korekta 2026-09-23: kompletny katalog sprzed dodania Wi-Fi i Bluetooth
(59 działań, także po wcześniejszych migracjach) dostaje dwa nowe rekordy
oraz komendy `:volume`, `:battery`, `:notifications` i `:quickmenu` tam,
gdzie pole było puste. Własne aliasy i wszystkie skróty pozostają zachowane;
zajęte nazwy blokują tylko dane nowe przypisanie. Nie ma zapisu przy odczycie.
Kompletny bieżący katalog nie jest ponownie uzupełniany, więc usunięcie
komendy z edytora jest trwałe. Nowe działania otwierają istniejące panele
przez wspólny koordynator; [lista komend](launcher.md#moduły-paska-w-komendach--2026-09-23).

Super+H pozostaje nawigacją Hyprlanda do okna po lewej. Wiadomości mają
domyślny globalny skrót `SUPER + CONTROL + SHIFT + Return`
(Ctrl+Shift+Super+Enter), który otwiera hub
lub przywołuje istniejące okno. Działa też `:messages`. Quick Menu ma `SUPER + Q`.
Istniejące własne przypisania w `keyboard.json` pozostają zachowane.

`config/menu-keybinds.lua` rejestruje osiem początkowych uchwytów z opisem
`Putkin:<action>`. Adapter usuwa/odtwarza tylko te uchwyty i zachowuje dane
do rollbacku nieudanego wywołania Lua. Dodatkowy istniejący Super+Shift+B
pozostaje skrótem paska w konfiguracji Hyprlanda. Walidacja i aktywacja
ponownie sprawdzają konflikty, także między zapisaniem pliku a zastosowaniem.

Skróty wywołują `actions invoke <id>`. Launcher dopasowuje zapisane komendy
po początku aliasu lub słowa w nazwie działania, bez rozróżniania wielkości
liter i polskich znaków w nazwach. `:wiadomosci` i `:Wiadomości` wybierają
Wiadomości z aliasem `:messages`. Dopasowanie nazwy obejmuje tylko działania
z niepustą komendą; dokładny zapisany alias zachowuje pierwszeństwo.
Sam `:` lub puste pole
w trybie „Komenda” pokazuje wszystkie przypisane komendy; dokładne dopasowanie
jest pierwsze. Enter lub kliknięcie wykonuje wybrany wynik przez ten sam
`ActionController`, również gdy wpisano tylko część nazwy. Wiersze pokazują
opis działania i jego kategorię z pasującą ikoną, bez dodatkowego podpisu
`:nazwa`. Dwukropek ze spacją w zwykłym launcherze tworzy chip „Komenda”
i pozostawia puste pole z fokusem. Kategoria zależy od działania, więc
zmiana aliasu zachowuje np. „Bateria” dla profilu zrównoważonego.
Ten sam katalog określa etykiety grup w ustawieniach klawiatury.
`shutdown` i `poweroff` mają wspólny wynik „Wyłącz komputer”: launcher pokazuje
go raz, dopasowując obie nazwy. Dotychczasowe osobne przypisania i własne
skróty pozostają zachowane w ustawieniach.
Komendy `powersaver`, `balanced` i `performance` wybierają odpowiednio profil
oszczędny, zrównoważony i wydajności przez ten sam `PowerProfileService` co
panel baterii. Niedostępny profil lub trwająca zmiana zgłasza błąd; ponowne
wybranie aktywnego profilu nie wysyła kolejnego żądania.
Komendy Hyprlanda zachowują okno i monitor sprzed otwarcia launchera.
Otwieranie kolejnego panelu jest odroczone do zamknięcia starego launchera,
aby jego sygnał aktywacji nie zamknął nowego widoku. Samo pisanie nie uruchamia
działań; brak dopasowań pozostawia pustą listę. `:shutdown`, `:poweroff` i `:reboot`
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
