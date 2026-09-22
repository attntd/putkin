# Konfiguracja Putkina i programów

`scripts/install` instaluje pliki wymienione w `catalog.json`. Edytuj zwykłe
pliki w tych katalogach; nie trzeba znać składni menedżera dotfiles.

| Katalog | Odpowiedzialność |
| --- | --- |
| `hypr/` | Modułowy Hyprland, skróty, wygląd, tapety i domyślne ustawienia wejścia. |
| `apps/` | Kitty, Fish, Starship, Neovim, Yazi z pluginami, Zen, tmux, btop, Glow, Voxtype, GTK, Qt/Kvantum oraz ustawienia klientów SSH, GPG i Git. |
| `putkin/` | Początkowe ustawienia shella, Signala i tapety. |
| `session/` | Środowisko UWSM, pomocnik i jednostki sprawdzania aktualizacji. |
| `packages/` | Jawne listy pakietów Arch i AUR. |
| `pam.d/` | Konfiguracja PAM należąca do runtime blokady. |

Małe pliki `menu-keybinds.lua`, `shell-layers.lua`, `desktop-appearance.lua`
pozostają publicznymi wejściami integracji shella: istniejące instalacje
i testy używają tych ścieżek. Nie są drugim kompletem ustawień Hyprlanda.

## Edycja Hyprlanda

`hypr/hyprland.lua` ustala ścieżkę modułów i kolejność ich ładowania.
`appearance.lua`, `animations.lua`, `layout.lua`, `input.lua`, `rules.lua`,
`permissions.lua`, `environment.lua` i `autostart.lua` mają oddzielne role.
W `keybinds/` są pliki `apps`, `windows`, `workspaces`, `hardware` i `shell`;
`lib/bindings.lua` wykrywa duplikaty, a `lib/paths.lua` wylicza i cytuje
ścieżki XDG. `Super+h/j/k/l` zachowuje kierunki fokusu okien.

`~/.config/hypr/local.lua` jest ładowany na końcu. Tu ustawiaj własne
monitory, pozycje, skalę i urządzenia. Instalator tworzy go tylko raz,
a eksport zachowuje pusty szablon. Podczas migracji starej lokalnej
konfiguracji zawartość `monitors.lua` trafia do `local.lua`. Na nowym
komputerze działa automatyczny wybór monitora, bez nazw poprzedniego sprzętu.

Skróty Print z modyfikatorami otwierają aktualny wybór screenshota Putkina;
nie wskazują już nieistniejących akcji `quickshell-de`. Region/okno/monitor
wybiera się w tym samym narzędziu.

## Aktualizacja i własne ustawienia

Pierwsza instalacja zapisuje backup zastępowanych plików. Następne
aktualizują pliki zgodne z ostatnią instalacją, a lokalne edycje pokazują
jako `preserve-local`. `--replace-config` wymusza zmianę zarządzanych
plików z backupem. Pliki `seed`, w tym `local.lua` i ustawienia Putkina,
zachowują istniejącą wersję poza jawnym `--clean-slate`.
`--shell-only` pomija konfigurację aplikacji.

`scripts/export-config --output /tmp/moj-putkin-config` tworzy nową paczkę
według katalogu. Przenieś ją i użyj `scripts/install --config-source KATALOG`.
Nowy plik dodaje się jawnie do `catalog.json`, po sprawdzeniu, że zawiera
konfigurację, a nie dane konta. Nie ma rekurencyjnego eksportu `~/.config`.

Zen dostaje CSS, skróty oraz wskazane preferencje przez `user.js`.
Instalator odczytuje profil domyślny z `profiles.ini`; na świeżym koncie
tworzy nowy profil `putkin.default`. Nie przenosi identyfikatora starego
profilu, sesji, historii, cookies, haseł, danych rozszerzeń ani kont Sync.
Eksport preferencji czyta wyłącznie klucze wymienione w dołączonym `user.js`.

Z SSH i GPG trafiają wyłącznie `config` oraz `gpg-agent.conf`; klucze,
keyring, dane zaufania i konta Signal/Bitwarden nie należą do katalogu.
Także token Voxtype pozostaje do ręcznego ustawienia.
Kontrola treści odrzuca rozpoznane literalne sekrety bez drukowania wartości;
nie zastępuje przeglądu nowych pozycji katalogu.

Istniejące dowiązania plików konfiguracji i zasobów GTK są zastępowane
z backupem samego dowiązania; instalator nie odczytuje ani nie zmienia jego
zewnętrznego celu. Eksport takich pozycji używa wersji z repozytorium
i wskazuje je w `absentUsingDefaults`. Nie zastępuje dowiązań całych
katalogów `.ssh` lub `.gnupg`.

## Zakres clean-slate

Ten tryb archiwizuje stare drzewa konfiguracji i odtwarza wersję z katalogu,
włącznie z `seed` i `local.lua`. Nie scala dawnych modułów. Uruchamia się
po wylogowaniu z pulpitu; [polecenia i przywracanie](../docs/install.md#świeży-start---clean-slate).

| Zakres | Działanie |
| --- | --- |
| `hypr`, `kitty`, `fish`, `nvim`, `yazi`, `Kvantum`, `gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`, `glow`, `btop`, `uwsm`, `voxtype`, `putkin` w XDG config | Backup i usunięcie dawnych plików, także spoza katalogu; następnie instalacja konfiguracji z paczki. |
| `quickshell`, `quickshell.previous`, `quickshell-de`, `putpuccin`, `waybar`, `ags`, `eww`, `hyprpanel`, `dms`, `noctalia`, `swaync`, `dunst`, `mako`, `hypridle`, `hyprlock`, `hyprpaper`, `swww` | Archiwizacja starych konfiguracji shella. Nowy domyślny Quickshell wskazuje Putkina. |
| Zen | Świeże CSS w `chrome`, skróty i `user.js`; istniejący profil oraz jego dane pozostają. |
| `systemd/user` i XDG autostart | Rozpoznane stare panele/shelle, powiadomienia, tapety i idle: backup jednostek i powiązań, maski `/dev/null` oraz wpisy `Hidden=true`. Pozostałe autostarty zostają. |
| Pojedyncze pliki katalogu poza tymi drzewami | Nadpisanie z backupem, w tym Starship, tmux, Git, ustawienia klientów SSH/GPG i pomocniki. |

Ochrona obejmuje dane konta `putkin/signal`, całe inne profile/konta poza
powyższym zakresem, klucze i bazy danych, `.env`, osobne pliki/katalogi
`token`, `tokens`, `credentials`, `secrets`, `keyring`, `fish_variables`
oraz zakładki GTK. Katalog zawierający takie pliki jest dzielony na mniejsze
zakresy czyszczenia; chronione elementy pozostają w miejscu. Ich lista jest
w `cleanSlate.preserved`. Dodatkowe programy poza tym zakresem nie są czyszczone.
Zmiana katalogu eksportu nie może rozszerzyć listy katalogów do skasowania.

Sekret osadzony w zwykłym starym pliku konfiguracyjnym może znaleźć się w
lokalnym backupie tego pliku. Kopia ma prywatny katalog poza repozytorium;
nie jest paczką eksportową. Dowiązania są kopiowane jako dowiązania, bez
czytania ich zewnętrznych celów. Nie ma rekurencyjnego kasowania całego HOME,
XDG config, XDG data ani profilu przeglądarki.

## Licencje zasobów

GTK 4: niezmienione CSS/SVG z `catppuccin-gtk-theme-mocha` 1.0.3-1,
źródło [catppuccin/gtk](https://github.com/catppuccin/gtk), GPL-3.0
([licencja](apps/gtk-4.0/LICENSE)). Pluginy/flavour Yazi zawierają licencje
upstream i przypięcia w `apps/yazi/package.toml`. Neovim zachowuje
`lazy-lock.json`; jego pluginy pobierają się przy pierwszym uruchomieniu.
