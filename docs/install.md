# Lokalne przełączenie na Putkin

## Wspólna wersja main — 2026-09-21

Aktywne wydanie: **`20260921-080356-f26716f87551`**, źródła z **`8ba66f1`**
na `main`. Łączy opisy launchera w jednej linii, dopasowania komend,
profile zasilania, nawigację i akcje centrum powiadomień oraz zamykanie
Q poza polami tekstowymi z wcześniejszym uwierzytelnianiem.

Instalacja przez `scripts/install --activate` i odbiór **PASS**: 146 QML
w paczce, 290 plików zgodnych z `main` i `launcher-suggestions`, jedna
instancja usługi i poprawny właściciel powiadomień. Ustawienia zachowane,
Polkit zarejestrowany, skróty gotowe, log i konfiguracja Hyprlanda czyste.
Instalator czeka teraz na rejestrację nazwy powiadomień w D-Bus.
[Odbiór](evidence/launcher-shell-merge-activation.json),
[instalacja](evidence/launcher-shell-merge-install.log),
[testy](status.md#wspólny-launcher-powiadomienia-i-q--2026-09-21).

`previous` wskazuje `20260920-210039-bf2eb74b4b79`; zachowano pięć buildów.
Powrót z odblokowanej sesji: `scripts/install --restore --activate`.

## Okna uwierzytelniania — 2026-09-20

Putkin przejął agenta Polkit oraz wejścia SSH/sudo askpass i GPG Pinentry.
Wdrożone wtedy wydanie: **`20260920-210039-bf2eb74b4b79`**, 287 plików runtime
zgodnych z testowanymi źródłami. Dodaje pasek odliczania, glif po prawej
i przejście do pola hasła z fokusem. [Odbiór](evidence/authentication-countdown-activation.json),
[testy korekty](status.md#odliczanie-odcisku-w-polkit--2026-09-20).
Stan końcowego wydania i testów: [status](status.md#natywne-okna-uwierzytelniania--2026-09-20).
W Fish, UWSM i środowisku usług SSH_ASKPASS/SUDO_ASKPASS wskazują
`~/.config/quickshell/services/askpass.py`; GPG agent ma `pinentry-program`
do `services/pinentry.py`. Odpowiadające pliki chezmoi są zgodne.

Zachowano obsługę obu starszych ścieżek askpass: `scripts/ssh-askpass`
w bieżącym wydaniu oraz przekierowanie w `quickshell.previous`. Dzięki
nim aplikacje już uruchomione z dawnym środowiskiem używają nowego UI.
Agent SSH nie był restartowany. `hyprpolkitagent.service` jest wyłączony;
jedynym zarejestrowanym agentem jest natywny PolkitAgent Putkina.

Pełny powrót wymaga przywrócenia wydania **i** konfiguracji klientów/Polkit.
Prywatna kopia i gotowe przywracanie:

```sh
python3 /home/attntd/.local/state/putkin/authentication-20260920-223538/restore.py --restore /home/attntd/.local/state/putkin/authentication-20260920-223538
```

Kopia zawiera wcześniejsze pliki oraz stan usługi i zmiennych środowiska.
Samo `scripts/install --restore --activate` przełącza kod, ale nie cofa
konfiguracji SSH/GPG ani nie włącza zewnętrznego agenta.
[Kontrakt i ograniczenia](authentication.md).

## Wcześniejsza instalacja main — 2026-09-20

Wdrożone wtedy wydanie: **`20260920-180112-c20011bd9d2d`**, commit **`c503fb1`**.
Zawiera komendy sesji i skrót `Super+;`, poprawki fade/zwijania paneli
oraz usunięcie pustego przycisku domyślnej akcji powiadomienia Kitty.

Instalacja przez `scripts/install --activate` i odbiór **PASS**: jedna
instancja usługi, 274 pliki zgodne z najnowszym lokalnym `main`, poprawny
właściciel powiadomień, skróty, workspace, gotowość blokady i idle.
Ustawienia zachowane, Caffeinate `off`, log QML i konfiguracja Hyprlanda
czyste. [Odbiór](evidence/latest-install-activation.json),
[testy i ograniczenia](status.md#instalacja-najnowszego-main--2026-09-20).

`previous` wskazuje `20260920-172244-98dd3094da3d`; zachowano pięć buildów.
Powrót z odblokowanej sesji: `scripts/install --restore --activate`.

## Oznaczenie i przełączanie workspace’ów — 2026-09-20

Aktywne wydanie: **`20260920-172244-98dd3094da3d`**, poprawka `53b3e70`
na `main`. Przywraca dane monitorów po niepełnej odpowiedzi IPC Quickshella
i dodaje odczyt diagnostyczny `bar status`. Zmiany powiadomień są zachowane.

Odbiór **PASS**: model aktywnego workspace i skupionego monitora zgadza się
z Hyprlandem, oznaczenie aktywności jest obecne w modelu paska, brak błędu
lub oczekującej operacji. Jedna instancja, czysty log, 274 pliki zgodne
z `main`, niezmienione ustawienia. [Raport](evidence/workspace-recovery-activation.json),
[testy](status.md#odzyskiwanie-aktywnego-workspace--2026-09-20).

`previous` wskazuje `20260920-170400-e2d7150ad167`; zachowano pięć buildów.
Powrót z odblokowanej sesji: `scripts/install --restore --activate`.

## Poprawki powiadomień — 2026-09-20

Aktywne wydanie: **`20260920-170400-e2d7150ad167`**, ze zmianami scalonymi
do `main` w commicie `34c11f1`. Zmienia pięć plików runtime: obsługę kart,
rozwijanie tekstu, przewijanie, wybór klawiaturą i wygląd przycisku ×.

Odbiór **PASS**: 137 QML w paczce, 274 pliki zgodne z `main`, jedna instancja
PID 327892 i jeden właściciel powiadomień. Skróty, blokada i idle gotowe,
ustawienia oraz Caffeinate „Prezentacja” zachowane. Końcowy log bez
ostrzeżeń; pierwsza próba została automatycznie wycofana przez niezależny
błąd odczytu ikony traya. [Wynik](evidence/notification-fixes-activation.json),
[przebieg i ograniczenia](status.md#interakcje-powiadomień--2026-09-20).

Zachowano pięć buildów. `previous` wskazuje `20260920-155210-f60d99e92e0f`.
Powrót z odblokowanej sesji: `scripts/install --restore --activate`.

## Launcher, fade i poprawka screenshota — 2026-09-20

Aktywne wydanie: **`20260920-155210-f60d99e92e0f`**, 274 pliki runtime.
Wspólna instalacja zawiera zwarty launcher i boczny podgląd schowka,
fade 200 ms oraz naprawę reguły screenshot przy restarcie. Przełączono
je przez `scripts/install --activate` z `20260920-144910-c522126acd2f`.

Odbiór **PASS**: 137 QML w paczce bez błędów, jedna instancja PID 311941
w UWSM, czysty log i konfiguracja Hyprlanda. Ustawienia oraz Caffeinate
„Praca w tle” zachowane; blokada i idle gotowe. Powtórne `qs` zachowuje PID.
Pozostało pięć buildów, `previous` wskazuje poprzednią aktywną wersję.
[Odbiór](evidence/combined-release-activation.json),
[testy i ograniczenia](status.md#wspólna-instalacja-launchera-fade-i-screenshota--2026-09-20).

Powrót z odblokowanej sesji: `scripts/install --restore --activate`.

## Screenshot — 2026-09-20

Poprzednie wydanie: **`20260920-144910-c522126acd2f`**, 272 pliki runtime.
Przełączone przez `scripts/install --activate` z
`20260920-143123-526a551c6a9f`. Stałe ścieżki, UWSM i limit pięciu buildów
opisane poniżej pozostają aktualne.

Print Screen i `:screenshot` uruchamiają wybór zakresu; Q/Escape anuluje.
Usunięto stare przypisanie samego Print do `quickshell-de:screenshot-open`
z `~/.config/hypr/keybinds.lua` i źródła chezmoi; skróty z modyfikatorami
pozostawiono. Nowy Print jest rejestrowany przez adapter klawiatury Putkina.

Odbiór **PASS**: paczka 135 QML bez błędów, zgodność sum 272 plików,
jedna instancja PID 284556, `putkin.service active/running`, jeden właściciel
powiadomień. Skróty zastosowane, konfiguracja Hyprlanda i log QML bez błędów,
gotowość blokady/idle i Caffeinate „Praca w tle” zachowane.
[Odbiór](evidence/screenshot-activation.json),
[zmiana konfiguracji](evidence/screenshot-activation-config.diff),
[testy i ograniczenia](status.md#screenshot--2026-09-20).
Powrót do poprzedniego runtime: `scripts/install --restore --activate`.

## Domyślne `qs`, UWSM i pięć buildów — 2026-09-20

Uruchamianie:

```sh
qs
```

`~/.local/bin/qs` uruchamia domyślną konfigurację jako `putkin.service`
przez `uwsm app -s s -t service`. Kolejne `qs` zachowuje działającą
instancję. Proces pozostaje w usłudze, bez `--daemonize`; wyjście z terminala
nie kończy shella. Argumenty, np. `qs ipc call session status`, `qs log`
i `qs --help`, są przekazywane do zwykłego Quickshella.

Stałe ścieżki (z uwzględnieniem XDG):

```text
~/.config/quickshell -> ~/.local/share/putkin/current
~/.local/share/putkin/current -> releases/<build>
~/.local/share/putkin/previous -> releases/<poprzedni build>
```

Quickshell 0.3.1 identyfikuje instancję ścieżką uruchomienia. Dlatego
autostart, skróty i pomocnik blokady używają `~/.config/quickshell`, bez
nazwy buildu. Samo dowiązanie `shell.qml` nie wystarcza do względnych
importów. Próba na prawdziwym Quickshellu potwierdza działanie dowiązania
całego katalogu i stabilną tożsamość IPC.

Aktualizacja z repozytorium i powrót:

```sh
scripts/install --dry-run
scripts/install --activate
scripts/install --restore --activate
```

Instalator kopiuje tylko runtime do stagingu, sprawdza QML, składnię Python
i sumy plików, a następnie publikuje kompletny katalog i atomowo zmienia
`current`. Identyczny kod wykorzystuje istniejący build. Zachowuje **pięć
buildów łącznie**, wliczając aktywny i poprzedni; usuwa starsze katalogi
oraz odpowiadające im dawne `update-*` / `switch-*`. Nie tworzy tarballi
ani kolejnej kopii konfiguracji przy każdej aktualizacji. `settings.json`,
`keyboard.json` i historia launchera pozostają w osobnych katalogach Putkin.

`--activate` zatrzymuje dokładnie rozpoznaną instancję przed uruchomieniem
nowej. Odmawia podczas blokady lub operacji sesji, zachowuje tryb Caffeinate,
sprawdza gotowość i właściciela powiadomień. Błąd uruchomienia przywraca
poprzedni kod, konfigurację domyślną i ścieżkę instancji. Zmiana wskazania
nie przeładowuje działającej instancji; dlatego aktualizacja aktywnego
shella wymaga kontrolowanego przełączenia.

`--destination /tmp/putkin-test` tworzy wyłącznie prywatne
`config/data/state/bin` i odmawia `--activate`. `--source KATALOG` wybiera
konkretne źródła runtime. `--restore NAZWA` wybiera zachowany build z
manifestem instalatora; starsze paczki bez manifestu nie są automatycznie
uznawane za sprawdzone. `--no-prune` odracza sprzątanie podczas odbioru
pierwszej migracji; zwykła aktualizacja zawsze stosuje limit pięciu.

Pierwsza migracja zachowuje **jedną** wcześniejszą konfigurację innego
shella w `~/.config/quickshell.previous`. W tym środowisku zawiera ona nadal
używany helper SSH askpass; jego wpis fish i źródło chezmoi wskazują nową
lokalizację. Tapeta jest zapisana w `~/.config/putkin/launch.json`.
Autostart Hyprlanda wywołuje `~/.local/bin/qs`; pliki Lua oraz ich źródła
chezmoi mają stałe ścieżki. Na innym koncie należy dołączyć ten sam start
do istniejącego `hl.on("hyprland.start", ...)` i fragmenty konfiguracji
z `~/.config/quickshell/config/`, używając domyślnej ścieżki także dla IPC.
Instalator nie przepisuje samodzielnie obcej konfiguracji Hyprlanda.

Stan i logi:

```sh
systemctl --user status putkin.service
journalctl --user -u putkin.service
qs list --all
```

[Testy instalatora](evidence/default-install-tests.log),
[plan migracji](evidence/default-install-plan.json),
[dokładna zmiana konfiguracji](evidence/default-install-config.diff),
[odbiór aktywnej instalacji](evidence/default-install-activation.json).
Starsze sekcje poniżej opisują historię. Ich polecenia `update-…/restore`
nie zastępują obecnego `scripts/install --restore`; usunięte archiwa
nie są już dostępnymi punktami powrotu.

## Natywna blokada i bezczynność — 2026-09-20

Aktywne wydanie: **`20260920-native-session-9a3db25af706`**, 265 plików runtime.
Zastępuje `20260920-signal-chat-897d94e15725`, zachowując jego zmiany ikon.
Jedna instancja Quickshell obsługuje pasek, panele, WlSessionLock/PAM
oraz IdleMonitor. Dotychczasowy pomocnik D-Bus nadal obsługuje logind;
nie ma drugiej instancji shella ani demona Hypridle.

Po odblokowaniu pulpitu przez użytkownika zatrzymano poprzednią instancję
przed uruchomieniem nowej. Hypridle jest zatrzymany i wyłączony; usunięto
również jego zarządzany przez chezmoi wpis graphical-session.target.wants.
Sześć plików konfiguracji (live i źródła chezmoi) wskazuje nowe wydanie.
Stare pliki Hyprlock/Hypridle oraz zainstalowane pakiety zachowano do powrotu.
Systemowe pliki PAM pozostają bez zmian; pliki wydania włączają system-auth.

Odbiór **PASS**: jedna instancja PID 265056, jeden serwer powiadomień,
ScreenSaver i delay FD pomocnika sesji, gotowość blokady i automatyki,
pasek/tapeta na każdym ekranie, ustawienia, panele i skróty. Hyprland
oraz QML bez błędów. Caffeinate zachował „Pracę w tle”; po zakończeniu
aktualizacji dim/DPMS/lock są dozwolone, a sleep nadal wstrzymany tym trybem.
Hasła, skanera i fizycznego snu hosta nie testowano.

[Plan](evidence/native-session-activation-plan.json),
[test paczki i powrotu](evidence/native-session-package-test.log),
[aktywacja](evidence/native-session-activation.json),
[stan po zwolnieniu inhibitora aktualizacji](evidence/native-session-live.json),
[pełne wyniki](status.md#blokada-i-bezczynność-w-jednej-instancji--2026-09-20).

Powrót z odblokowanego pulpitu:

```sh
/home/attntd/.local/state/putkin/update-20260920-native-session-9a3db25af706/restore
```

Skrypt odmawia restartu zablokowanej sesji i nadpisania późniejszych edycji.
Przywraca poprzednie wydanie, konfigurację i autostart Hypridle wraz ze
źródłem chezmoi, zachowując bieżący tryb Caffeinate. Przenośny instalator
etapu 13 nadal jest odrębnym zakresem.


## Signal: Chat bubble i Chat — 2026-09-20

Aktywne wydanie: **`20260920-signal-chat-897d94e15725`**, 261 plików runtime.
Zastępuje `20260920-charging-material-41a71d98cd09`. Launcher używa
Chat bubble; tray przełącza Chat bubble / Chat według oznaczenia nowych
wiadomości Signala. Kolor, obrys, rozmiar i padding pozostają stałe.
Pakiet zawiera wyłącznie korektę ikon na bazie poprzedniego wydania;
równoległa migracja blokady i bezczynności pozostaje poza tym wdrożeniem.

Odbiór: **PASS** — jedna instancja PID 243441, właściciel powiadomień,
pasek, tapeta, Ustawienia, panele, launcher i skróty. Hypridle PID 243433
aktywny, posiada ScreenSaver. Caffeinate zachował tryb „Praca w tle”.
Log QML i konfiguracja Hyprlanda bez błędów. Ustawienia, blokada, audio
i istniejące różnice chezmoi/Zen zachowane.
[Plan](evidence/signal-chat-activation-plan.json),
[pakiet i przywracanie](evidence/signal-chat-package-test-final.log),
[odbiór](evidence/signal-chat-activation.json),
[testy i ograniczenia](status.md#signal-chat-bubble-i-chat--2026-09-20).

Powrót do poprzedniego wydania i ośmiu konfiguracji, z ochroną późniejszych
edycji i zachowaniem bieżącego trybu Caffeinate:

```sh
/home/attntd/.local/state/putkin/update-20260920-signal-chat-897d94e15725/restore
```

## Oryginalna ikona ładowania i szersze pole — 2026-09-20

Wcześniejsze wydanie: **`20260920-charging-material-41a71d98cd09`**, 260 plików runtime.
Zastępuje `20260920-bar-alignment-221eccd10c8c`; zmienia sześć plików i usuwa
osiem lokalnych SVG. Przywraca oryginalne Material Charging … 2 z piorunkiem
po prawej. Wysokość korpusu baterii wynosi 10 px w obu stanach; pole
przycisku rozszerza się 32 → 36 px, z paddingiem 6/5 px i bez zmiany
proporcji oryginalnej ścieżki.

Odbiór: **PASS** — jedna instancja PID 231654, właściciel powiadomień,
pasek, tapeta, Ustawienia, panele, launcher i skróty. Hypridle PID 231646
aktywny, posiada ScreenSaver. Log QML i konfiguracja Hyprlanda bez błędów.
Zachowano ustawienia, blokadę, audio i istniejące różnice chezmoi w
Hyprlandzie/Zen. Osiem konfiguracji zmienia tylko ścieżki wydania.
[Plan](evidence/charging-material-activation-plan.json),
[pakiet i przywracanie](evidence/charging-material-package-test.log),
[odbiór](evidence/charging-material-activation.json),
[log](evidence/charging-material-live.log),
[testy i ograniczenia](status.md#oryginalna-ikona-ładowania-i-szersze-pole--2026-09-20).

Powrót do poprzedniego wydania i ośmiu konfiguracji, z ochroną późniejszych
edycji, przełączeniem shella i restartem Hypridle:

```sh
/home/attntd/.local/state/putkin/update-20260920-charging-material-41a71d98cd09/restore
```

## Centrowanie paska i obrys baterii — 2026-09-20

Wcześniejsze wydanie: **`20260920-bar-alignment-221eccd10c8c`**, 268 plików runtime.
Zastępuje `20260920-bar-icons-399655afcfb6`; zmienia osiem plików i dodaje
osiem SVG ładowania. Ikony mają 20 px, padding 6 px poziomo i 5 px pionowo,
wyśrodkowany nad dolnym separatorem. Zegar centruje widoczny obrys znaków.
Ładowanie zachowuje wielkość i poziom baterii, dodając wewnętrzny piorunek.

Odbiór: **PASS** — jedna instancja PID 226043, właściciel powiadomień,
pasek 32 px, tapeta, Ustawienia, panele, launcher i skróty. Hypridle
PID 226035 aktywny, posiada ScreenSaver. Log QML i konfiguracja Hyprlanda
bez błędów. Zachowano ustawienia, blokadę, audio i istniejące różnice
chezmoi w Hyprlandzie/Zen. Osiem konfiguracji zmienia tylko ścieżki wydania.
[Plan](evidence/bar-alignment-activation-plan.json),
[pakiet i przywracanie](evidence/bar-alignment-package-test.log),
[odbiór](evidence/bar-alignment-activation.json),
[log](evidence/bar-alignment-live.log),
[testy i ograniczenia](status.md#centrowanie-paska-i-stały-obrys-ładowania--2026-09-20).

Powrót do poprzedniego wydania i ośmiu konfiguracji, z ochroną późniejszych
edycji, przełączeniem shella i restartem Hypridle:

```sh
/home/attntd/.local/state/putkin/update-20260920-bar-alignment-221eccd10c8c/restore
```

## Rozmiar i kolor ikon paska — 2026-09-20

Wcześniejsze wydanie: **`20260920-bar-icons-399655afcfb6`**, 260 plików runtime.
Zastępuje `20260920-material-icons-229766e3f287`; zmienia sześć plików.
Ikony topbara mają 20 px, równy padding 6 px i stały kolor daty/czasu
`#cdd6f4` niezależnie od stanu.

Odbiór: **PASS** — jedna instancja PID 220092, właściciel powiadomień,
pasek, tapeta, Ustawienia, panele, launcher, skróty i Hypridle. Konfiguracja
Hyprlanda i log QML bez błędów. Zachowano ustawienia i istniejące różnice
chezmoi. Osiem konfiguracji zmienia wyłącznie ścieżki wydania.
[Plan](evidence/bar-icons-activation-plan.json),
[pakiet i przywracanie](evidence/bar-icons-package-test.log),
[odbiór](evidence/bar-icons-activation.json), [log](evidence/bar-icons-live.log).

Powrót do poprzedniego wydania i ośmiu konfiguracji z ochroną późniejszych
edycji, przełączeniem shella i restartem Hypridle:

```sh
/home/attntd/.local/state/putkin/update-20260920-bar-icons-399655afcfb6/restore
```

## Material Symbols — 2026-09-20

Wcześniejsze wydanie: **`20260920-material-icons-229766e3f287`**, 260 plików runtime.
Zastąpiło `20260920-fingerprint-603608293d62`. Ujednolica ikony Quickshell:
lokalne wektory Material Symbols Outlined, pojedynczy kolor Catppuccin,
stały rozmiar i padding dla każdej sekcji oraz dopasowane Signal/Tether.
Obejmuje wskazane stany baterii, powiadomień i rodzinę Network WiFi.
Zachowuje wcześniej wdrożoną integrację odcisku w zewnętrznym Hyprlocku.

Osiem konfiguracji pulpitu i chezmoi zmienia wyłącznie ścieżkę wydania.
Stary shell zatrzymano przed nowym; działa jedna instancja PID 216450,
będąca właścicielem powiadomień. Potwierdzono pasek, tapetę, Ustawienia,
launcher, pozostałe panele, skróty i działanie Hypridle. Log QML
i konfiguracja Hyprlanda bez błędów. Ustawienia, klawiatura, blokada,
audio i istniejące różnice chezmoi dotyczące Hyprlanda/Zen zachowane.

[Plan](evidence/material-icons-activation-plan.json),
[pakiet i przywracanie](evidence/material-icons-package-test.log),
[odbiór](evidence/material-icons-activation.json),
[log QML](evidence/material-icons-live.log),
[testy i ograniczenia](status.md#material-symbols-w-całym-shellu--2026-09-20).

Powrót do poprzedniego wydania i zapisanych ośmiu konfiguracji, z ochroną
późniejszych edycji. Przywracanie przełącza shell i restartuje Hypridle:

```sh
/home/attntd/.local/state/putkin/update-20260920-material-icons-229766e3f287/restore
```

## Glif odcisku — 2026-09-20

Wcześniejsze wydanie: **`20260920-fingerprint-603608293d62`**, 171 plików runtime.
Zastąpiło `20260920-monochrome-icons-126a9cb93feb`; różnica obejmuje cztery
pliki blokady. Hyprlock pokazuje glif Nerd Font wewnątrz pola hasła,
z kolorami Catppuccin dla stanu wyjściowego, sukcesu i błędu.

Osiem konfiguracji pulpitu i chezmoi zmienia wyłącznie ścieżki wydania.
Menu, skrót blokady oraz Hypridle korzystają z nowego launchera.
Stary shell zatrzymano przed nowym; potwierdzono jedną instancję,
właściciela powiadomień, pasek, tapetę, Ustawienia, panele i skróty.
Hypridle zrestartowano i potwierdzono własność nazwy ScreenSaver.
Log QML, konfiguracja Hyprlanda i bieżący dziennik Hypridle bez błędów.
Ustawienia, klawiatura, uwierzytelnianie i audio zachowane, podobnie jak
wcześniejsza lokalna reguła Zen i jej różnica względem źródła chezmoi.
Nie uruchamiano blokady ani uwierzytelniania aktywnej sesji.

[Plan](evidence/fingerprint-activation-plan.json),
[test pakietu i przywracania](evidence/fingerprint-package-test.log),
[odbiór](evidence/fingerprint-activation.json),
[ścieżki blokady](evidence/fingerprint-lock-entrypoints.json),
[log QML](evidence/fingerprint-live.log),
[dziennik Hypridle](evidence/fingerprint-hypridle.log).

Powrót do poprzedniego wydania i zapisanych ośmiu konfiguracji, z ochroną
późniejszych edycji. Przywracanie przełącza shell i restartuje Hypridle:

```sh
/home/attntd/.local/state/putkin/update-20260920-fingerprint-603608293d62/restore
```

## Ikony launchera — 2026-09-20

Wcześniejsze wydanie: **`20260920-launcher-icons-336f43911540`**, 169 plików runtime.
Launcher wyświetla kolorowe ikony aplikacji z Papirus-Dark i zachowuje
glif Nerd Font przy braku ikony. Zawiera też wcześniejszą poprawkę
powrotu fokusu w opcjach Caffeinate.

Stary shell zatrzymano przed nowym. Potwierdzono jedną instancję,
właściciela powiadomień, pasek, tapetę, Ustawienia, panele, skróty
i otwarcie/zamknięcie zwykłego launchera. Ustawienia i klawiatura zachowane;
log QML, konfiguracja Hyprlanda i chezmoi bez błędów.
[Plan](evidence/launcher-icons-activation-plan.json),
[odbiór](evidence/launcher-icons-activation.json),
[log](evidence/launcher-icons-live.log).

Powrót do poprzedniego wydania, z ochroną późniejszych edycji:

```sh
/home/attntd/.local/state/putkin/update-20260920-launcher-icons-336f43911540/restore
```

## Fokus Caffeinate — 2026-09-20

Poprzednie wydanie: **`20260920-caffeinate-focus-5367ba0cec0c`**, 169 plików runtime.
Naprawia powrót przez `k` z „Pracy w tle” do „Prezentacji”, Caffeinate
oraz wyższych kafelków, bez zamykania opcji przez Escape.

Zatrzymano poprzedni shell przed startem nowego. Potwierdzono jedną
instancję i właściciela powiadomień, pasek, tapetę, panele, skróty oraz
Ustawienia. Konfiguracja Hyprlanda, chezmoi i log QML bez błędów.
Ustawienia, klawiatura i audio zachowane. Sześć plików konfiguracji
zmienia wyłącznie ścieżkę wydania; runtime różni się jednym plikiem QML.
[Plan](evidence/caffeinate-focus-activation-plan.json),
[odbiór](evidence/caffeinate-focus-activation.json),
[log](evidence/caffeinate-focus-live.log).

Powrót do poprzedniego wydania, z ochroną późniejszych edycji:

```sh
/home/attntd/.local/state/putkin/update-20260920-caffeinate-focus-5367ba0cec0c/restore
```

## Ramki Hyprlanda — 2026-09-20

Poprzednie wydanie: **`20260920-window-borders-48f2f2f6ecec`**, 169 plików runtime.
Kwadratowe ramki 2 px używają gradientu i akcentów Shella. Synchronizacja
obejmuje podgląd, anulowanie, zapis i oba reloady; nie wymaga nowego procesu.
Nieaktywna ramka jest neutralna, a warianty grup korzystają z tej samej palety.

Jedna instancja PID 136740 jest właścicielem powiadomień. Zatrzymano stary
proces przed startem nowego. Sześć plików Hyprlanda i chezmoi wskazuje nowe
wydanie; zaktualizowano bazową paletę i oba istniejące promienie narożników.
Ustawienia i klawiatura zachowane, stan audio niezmieniony, Caffeinate off.
Konfiguracja, log QML oraz chezmoi są czyste. Odczyt Lua potwierdził ramki.

[Przygotowanie](evidence/window-borders-prepare.log), [plan](evidence/window-borders-activation-plan.json),
[raport aktywacji](evidence/window-borders-activation.json), [log](evidence/window-borders-live.log),
[zmiany konfiguracji](evidence/window-borders-config.diff).

Powrót do poprzedniego wydania i wyglądu ramek, z ochroną późniejszych edycji:

```sh
/home/attntd/.local/state/putkin/update-20260920-window-borders-48f2f2f6ecec/restore
```

## Przekątna i fokus wierszy — 2026-09-20

Poprzednie wydanie: **`20260920-diagonal-rows-16d3bbc8db65`**, 167 plików runtime.
Gradient całej grupy ma równy udział obu osi, od lewego górnego do prawego
dolnego rogu także na szerokich powierzchniach. Fokus jasności i temperatury
obejmuje pełne wiersze Quick Menu, tak jak fokus głośności.

Jedna instancja PID 131347 jest właścicielem powiadomień. Stary proces
zatrzymano przed nowym. Sześć konfiguracji Hyprlanda i chezmoi wskazuje
nowe wydanie; ustawienia i skróty zachowano. Odbiór paneli nie zmienił
stanu audio. Caffeinate pozostało wyłączone. Konfiguracja, log QML
i chezmoi są czyste.

[Przygotowanie](evidence/diagonal-rows-prepare.log), [plan](evidence/diagonal-rows-activation-plan.json),
[raport aktywacji](evidence/diagonal-rows-activation.json), [log](evidence/diagonal-rows-live.log),
[zmiany konfiguracji](evidence/diagonal-rows-config.diff).

Powrót do poprzedniego wydania z ochroną późniejszych edycji:

```sh
/home/attntd/.local/state/putkin/update-20260920-diagonal-rows-16d3bbc8db65/restore
```

## Gradient grup i ikony modułów — 2026-09-20

Poprzednie wydanie: **`20260920-accent-groups-be2213f6b4c0`**, 167 plików runtime.
Wspólny gradient paska i każdego panelu biegnie od lewego górnego do
prawego dolnego rogu. Aktywne Wi-Fi, Bluetooth i bateria mają kontrastowe
ikony; fokus pola launchera koloruje wyłącznie jego własną ramkę.

Jedna instancja PID 124179 jest właścicielem powiadomień. Stary proces
zatrzymano przed nowym. Zmieniono sześć ścieżek konfiguracji Hyprlanda
oraz chezmoi; ustawienia i skróty zachowano. Odbiór paneli nie zmienił
stanu audio. Caffeinate pozostało wyłączone. Konfiguracja, log QML
i chezmoi są czyste.

[Przygotowanie](evidence/accent-groups-prepare.log), [plan](evidence/accent-groups-activation-plan.json),
[raport aktywacji](evidence/accent-groups-activation.json), [log](evidence/accent-groups-live.log),
[zmiany konfiguracji](evidence/accent-groups-config.diff).

Powrót do poprzedniego wydania z ochroną późniejszych edycji:

```sh
/home/attntd/.local/state/putkin/update-20260920-accent-groups-be2213f6b4c0/restore
```

## Kafelki i Caffeinate — 2026-09-20

Poprzednie wydanie: **`20260920-toggle-tiles-7a84bdec0b46`**, 164 sprawdzone
pliki runtime. Zawiera układ kafelków w dwóch kolumnach, DND, automatyczny
suwak temperatury, Caffeinate z dwoma trybami, poprawione ramki fokusu
oraz historię powiadomień transient, w tym VoxType.

Jedna instancja PID 107656 jest właścicielem powiadomień. Stary proces
zatrzymano przed nowym. Trzy pliki Hyprlanda i ich źródła chezmoi wskazują
nowe wydanie; ustawienia i klawiatura zachowane. Hypridle.conf nie zmieniano.
Caffeinate uruchomiło się wyłączone, bez błędu. Konfiguracja Hyprlanda,
log QML oraz chezmoi są czyste.

[Przygotowanie](evidence/toggle-tiles-prepare.log), [plan](evidence/toggle-tiles-activation-plan.json),
[raport aktywacji](evidence/toggle-tiles-activation.json), [log QML](evidence/toggle-tiles-live.log),
[zmiany konfiguracji](evidence/toggle-tiles-config.diff).

Powrót do poprzedniego wydania, z kontrolą późniejszych edycji plików:

```sh
~/.local/state/putkin/update-20260920-toggle-tiles-7a84bdec0b46/restore
```

## Quick Menu i centrum powiadomień — 2026-09-20

Poprzednie wydanie: **`20260920-quick-menu-2062d4d22d06`** w
`~/.local/share/putkin/releases/`, 159 sprawdzonych plików runtime.
Zawiera wspólny wiersz audio, rozróżnialne nazwy urządzeń, kafelki radiowe,
osobne moduły Wi-Fi/Bluetooth i centrum powiadomień z DND.

Autostart i skróty wskazują nowe wydanie w trzech konfiguracjach Hyprlanda
oraz ich źródłach chezmoi. Stary shell zatrzymano przed nowym; działa jeden
proces (PID 92168), będący właścicielem powiadomień. Ustawienia i plik
klawiatury zachowano, odbiór paneli nie zmienił poziomu audio. Nazwa
potwierdzonego wyjścia: „Wbudowane głośniki”. Logi QML i konfiguracja
Hyprlanda bez błędów; `chezmoi status` pusty.

[Plan](evidence/quick-menu-activation-plan.json),
[przygotowanie i test przywrócenia](evidence/quick-menu-prepare.log),
[odbiór aktywnej sesji](evidence/quick-menu-activation.json),
[zmiany konfiguracji](evidence/quick-menu-config.diff),
[log](evidence/quick-menu-live.log).

Powrót do `20260919-mouse-focus-d40d745288bc`:

```sh
/home/attntd/.local/state/putkin/update-20260920-quick-menu-2062d4d22d06/restore
```

Procedura przywraca konfiguracje Hyprlanda i źródła chezmoi, chroniąc
późniejsze edycje. Kopie i plan są w tym samym katalogu stanu. Historia
powiadomień jest wyłącznie w pamięci; restart procesu ją czyści.


## Kliknięcia bez ramki fokusu — 2026-09-19

Wdrożono wtedy **`20260919-mouse-focus-d40d745288bc`** w
`~/.local/share/putkin/releases/`. Zawiera 155 plików runtime, zgodnych
ze sprawdzonymi źródłami, oraz wspólną obsługę wejścia i ramki fokusu.
Przełączono na wyraźne polecenie użytkownika „przelacz”.

Autostart i skróty wskazują nowe wydanie w trzech plikach Hyprlanda
oraz odpowiadających im źródłach chezmoi. Ustawienia i plik klawiatury
zachowano. Poprzednią instancję zatrzymano przed uruchomieniem nowej.
Potwierdzono jedną instancję, właściciela powiadomień, pasek 32 px,
tapetę, 7 skrótów, fokus paska, okno Ustawienia i IPC paneli.
Log QML i konfiguracja Hyprlanda bez błędów; `chezmoi status` pusty.

[Plan](evidence/mouse-focus-activation-plan.json),
[przygotowanie i test przywrócenia](evidence/mouse-focus-prepare.log),
[odbiór aktywnej sesji](evidence/mouse-focus-activation.json),
[log](evidence/mouse-focus-live.log).

Powrót do `20260917-settings-keyboard-cc7addc79750`:

```sh
/home/attntd/.local/state/putkin/update-20260919-mouse-focus-d40d745288bc/restore
```

Procedura przywraca konfigurację i źródła chezmoi; chroni późniejsze
edycje użytkownika. Kopie i plan są w tym samym katalogu stanu.

## Przywrócenie po end-4 — 2026-09-19

Przywrócono wtedy **`20260917-settings-keyboard-cc7addc79750`** z oficjalnym
`quickshell 0.3.1-1`. Przywrócono wcześniejsze ustawienia sesji i zapisano
je w chezmoi. Usunięto end-4 bez tworzenia kopii; końcowa lista pakietów
nie zawiera `illogical-impulse-*`. Ustawienia Putkina zachowano.
[Wyniki i zakres sprawdzenia](status.md#przywrócenie-po-end-4--2026-09-19).

## Ustawienia i Klawiatura — aktualizacja 2026-09-17

Wdrożono wtedy **`20260917-settings-keyboard-cc7addc79750`**. Zawiera osobne okno
Ustawienia, 49 gotowych działań ze skrótami i komendami `:`, chip „Komenda”
oraz nagłówek „Ostatnie”. Pakiet ma 153 pliki runtime; trzy zmiany
konfiguracji Hyprlanda dotyczą wyłącznie ścieżki wydania. Test przywrócenia
kopii i ochrony późniejszych edycji przeszedł. [Wyniki](status.md),
[plan](evidence/settings-keyboard-activation-plan.json).

Aktualizację uruchomiono po wyraźnej zgodzie użytkownika. Jedna instancja
shella i właściciel powiadomień, aktywne skróty bez błędu, natywne okno
Ustawienia, oba tryby launchera i panel audio potwierdzone w działającej sesji.
Ustawienia i poziom wyjścia pozostały niezmienione;
[odbiór](evidence/settings-keyboard-activation.json).
Powrót do poprzedniej wersji:

```sh
/home/attntd/.local/state/putkin/update-20260917-settings-keyboard-cc7addc79750/restore
```

Skrypt chroni późniejsze edycje konfiguracji użytkownika. Nie usuwa zapisów
`keyboard.json`; poprzednia wersja ich nie odczytuje. Restart shella czyści
sesyjną historię schowka zgodnie z kontraktem launchera.

## Panel audio i skróty launchera — aktualizacja 2026-09-17

Poprzednio działała wersja **`20260917-audio-launcher-2cf1bad7b39c`**. Super+V otwiera schowek,
Super+: komendy (Super+Shift+średnik na PL/US). Niepełne `:w` nie pokazuje
podpowiedzi. Ikona głośnika otwiera osobny panel z głośnikiem, mikrofonem
i wyborem wejść/wyjść. [Testy](status.md),
[odbiór aktywnej sesji](evidence/audio-launcher-activation.json).

Opublikowano pełne 142 pliki runtime; trzy konfiguracje Hyprlanda wskazują
nowe wydanie. Jeden shell i właściciel powiadomień, ustawienia oraz poziom
wyjścia bez zmian, brak błędów. Powrót do poprzedniej wersji:

```sh
/home/attntd/.local/state/putkin/update-20260917-audio-launcher-2cf1bad7b39c/restore
```

Skrypt chroni późniejsze edycje konfiguracji użytkownika. Restart shella
czyści sesyjną historię schowka zgodnie z kontraktem launchera.

## Komendy workspace — aktualizacja 2026-09-17

Po dodaniu komend workspace działała wersja **`20260917-workspace-commands-ca6230ec4aef`**.
Launcher obsługuje `:wN`/`:mwN` i Enter, z 0 jako workspace 10.
Pełny runtime 137 plików, 7 zmienionych plików produkcyjnych;
[testy i odbiór](status.md), [aktywacja](evidence/workspace-commands-activation.json).

Zaktualizowano ścieżki wydania w trzech konfiguracjach Hyprlanda. Stary shell
zatrzymano przed uruchomieniem nowego. Zachowano ustawienia i jeden serwer
powiadomień. Powrót do poprzedniego wydania z ochroną późniejszych edycji:

```sh
/home/attntd/.local/state/putkin/update-20260917-workspace-commands-ca6230ec4aef/restore
```

## Bateria bez dodatkowych stanów — aktualizacja 2026-09-17

Po uproszczeniu działała wersja **`20260917-battery-minimal-8edd9469b482`**: bez separatora,
tekstu stanu przy procencie i napisu „Zmiana…”. Pełny runtime 137 plików,
jeden zmieniony widok; [testy i odbiór](status.md) przeszły.

Powrót do poprzedniego wyglądu z ochroną późniejszych edycji konfiguracji:

```sh
/home/attntd/.local/state/putkin/update-20260917-battery-minimal-8edd9469b482/restore
```

## Uproszczenie baterii — aktualizacja 2026-09-17

Po pierwszym uproszczeniu działała wersja **`20260917-battery-clean-634ac9ebdd59`**: usunięte dodatkowe
napisy i ×, tekst w przyciskach wyśrodkowany w pionie. Pełny runtime
137 plików; zmieniony jeden widok. Odbiór sesji, parser i testy przeszły.
[Wyniki](status.md), [aktywacja](evidence/battery-clean-activation.json).

Powrót do panelu przed korektą (`20260917-battery-3028dc9e5e77`),
z ochroną późniejszych edycji trzech konfiguracji:

```sh
/home/attntd/.local/state/putkin/update-20260917-battery-clean-634ac9ebdd59/restore
```

## Panel baterii — aktualizacja 2026-09-17

Po dodaniu panelu działała wersja **`20260917-battery-3028dc9e5e77`**: osobny panel pod ikoną
baterii, procent/pasek/czas i tryby pracy. Launcher Super+Spacja pozostaje
dostępny. [Obsługa](battery-tray.md), [wyniki](status.md).

Pełny runtime zawiera 137 plików. Zmieniono ścieżki wydania w trzech
konfiguracjach: `hyprland.lua`, `autostart.lua`, `modules/system_binds.lua`.
Ustawienia, skróty aplikacji, Hypridle i konfiguracja blokady są niezmienione.
Profil zasilania pozostał Oszczędny. Powrót do poprzedniej wersji:

```sh
/home/attntd/.local/state/putkin/update-20260917-battery-3028dc9e5e77/restore
```

Skrypt chroni późniejsze edycje konfiguracji i przywraca launcherowe wydanie
`20260917-launcher-769491c1e9b8`. Automatyczny rollback został faktycznie
wykonany po błędnym założeniu weryfikatora o szerokości warstwy; końcowa
aktywacja i odbiór przeszły. [Dowód](evidence/battery-activation.json).

## Launcher — aktualizacja 2026-09-17

Po dodaniu launchera działała wersja **`20260917-launcher-769491c1e9b8`**. Launcher jest pod
`Super+Spacja`; prefiksy `:a `, `:f `, `:c ` wybierają aplikacje, pliki
i schowek. [Obsługa](launcher.md), [wyniki](status.md).
Opublikowano kompletny runtime 133 plików. Autostart i skróty IPC wskazują
nową wersję; usunięto starszy wpis Super+Spacja. Ustawienia wyglądu,
Hypridle i konfiguracja blokady pozostały niezmienione.

Powrót przywraca poprzedni proces i cztery pliki konfiguracji, sprawdzając,
czy od przełączenia nie zostały zmienione:

```sh
/home/attntd/.local/state/putkin/update-20260917-launcher-769491c1e9b8/restore
```

Kopia poprzednia to `20260917-icons-cd3b25f5725c`. Automatyczny rollback
został faktycznie wykonany podczas pierwszej próby (błąd weryfikatora Lua,
bez błędu runtime); końcowa próba przeszła. To aktualizacja tej sesji,
nie przenośny instalator etapu 13.


## Ikony i numery workspace’ów — 2026-09-17

Przed dodaniem launchera działała wersja **`20260917-icons-cd3b25f5725c`** w `~/.local/share/putkin/releases/`.
Pełny runtime zawiera 126 plików; trzy zmienione źródła wyrównują optycznie
Wi-Fi/audio i zastępują kropkę zajętego workspace’u akcentowanym numerem
o wadze SemiBold. [Plan i sumy](evidence/12-icons-workspaces-plan.json),
[odbiór aktywnej sesji](evidence/12-icons-workspaces-verification.json).

Autostart, skróty, reguły warstw i Hypridle wskazują nową kopię.
Zmieniono wyłącznie ścieżki wydania w czterech plikach konfiguracji;
`settings.json` pozostał identyczny. Powrót do poprzedniego wyglądu:

```sh
/home/attntd/.local/state/putkin/update-20260917-icons-cd3b25f5725c/restore
```

Kopie czterech plików są w `before/` i `after/` obok skryptu. Skrypt
chroni późniejsze edycje użytkownika. Dalsze wycofywanie wcześniejszych
aktualizacji wymaga zachowania kolejności opisanej poniżej.

## Aktualizacja wyglądu — 2026-09-16

Po tej aktualizacji działała wersja **`20260916-visual-3d0c562aa347`** w `~/.local/share/putkin/releases/`.
126 plików runtime odpowiada źródłom i manifestowi.
[Plan i sumy](evidence/12-visual-plan.json),
[odbiór aktywnej sesji](evidence/12-visual-verification.json).

Zmiana obejmuje autostart, ścieżki IPC w skrótach, regułę `no_anim` tylko
dla warstw Putkin oraz wygląd Hyprlock. Super+Shift+L i `lock_cmd` Hypridle
korzystają z `scripts/lock-session` nowej instalacji. Launcher czyta zapisane
akcenty i ograniczenie ruchu przed każdym uruchomieniem blokady. Oryginalny
blok `auth` został zachowany w `~/.config/putkin/hyprlock-auth.conf`.
Konfiguracji systemowego PAM nie zmieniano. Hypridle został przeładowany.

Rollback tej aktualizacji (powrót przed poprawkę toastu startowego):

```sh
/home/attntd/.local/state/putkin/update-20260916-visual-3d0c562aa347/restore
```

Powrót całej korekty wyglądu wymaga następnie rollbacku pierwszej aktualizacji:

```sh
/home/attntd/.local/state/putkin/update-20260916-visual-967a46b681fe/restore
```

Każdy skrypt chroni późniejsze zmiany użytkownika i odmawia ich nadpisania.
Kopie sześciu plików są w `before/` i `after/` obok skryptu.
`settings.json` pozostaje niezmieniony. Poniższy opis dotyczy pierwotnego
przełączenia na Putkin i jego osobnego powrotu do poprzedniego shella.


2026-09-16, na polecenie użytkownika „no to przelacz mnie na nowy shell”,
przełączono działającą sesję Hyprlanda. Później użytkownik potwierdził
podstawowe działanie sprzętu, blokady ekranu, uśpienia i wybudzenia
oraz wizualne włączenie i wyłączenie Night Light.
[Etap 12 ukończono](validation.md), z zachowaniem opisanych granic testów.
To przełączenie lokalne;
przenośny instalator z pełnego etapu 13 nie jest jeszcze zaimplementowany.

## Aktywna instalacja

Kompletny runtime (110 plików) opublikowano przez staging i pojedyncze
przemianowanie katalogu do:

```text
~/.local/share/putkin/releases/20260916-5132708bd8f7/
```

Katalog zawiera kod, ikony, launcher blokady i fragment skrótów Lua.
Nie zawiera testów, dokumentacji, planów, `.git` ani ustawień użytkownika.
Sumy wszystkich plików sprawdzono przed publikacją i po uruchomieniu.
Istniejący `~/.config/putkin/settings.json` pozostał identyczny bajtowo.
Nie importowano ustawień quickshell-de.

Autostart używa `uwsm app`, `quickshell --no-duplicate --daemonize`
i jawnego `--path` do powyższego `shell.qml`. Dotychczasowa tapeta
`Cloudsnight.jpg` jest przekazywana przez `PUTKIN_WALLPAPER`.
Przyszłe zmiany repozytorium nie przeładują tej opublikowanej kopii.
Aktualizacja powinna opublikować kolejny kompletny katalog i wykonać
kontrolowany restart; nie edytować plików aktywnej wersji pojedynczo.

Odwracalne zmiany obejmują dokładnie:

- `~/.config/hypr/autostart.lua` — start Putkin zamiast domyślnego `qs`.
- `~/.config/hypr/hyprland.lua` — fragment menu z instalacji Putkin.
- `~/.config/hypr/modules/system_binds.lua` — wejście na pasek,
  powiadomienia i IPC audio/jasności; bez aktywacji skrótów Putkin na blokadzie.

Skróty:

| Skrót | Funkcja |
| --- | --- |
| Super+B, Super+Shift+B, Super+Tab | Nawigacja po pasku |
| Super+Shift+Q | Quick Settings |
| Super+Shift+P | Menu zasilania |
| Super+N, Super+Shift+N | Wejście w widoczne powiadomienia |
| Klawisze głośności i jasności | Odpowiednie IPC Putkin |

W panelach i pasku: h/j/k/l, Enter i Escape. Ustawienia wyglądu są
dostępne z Quick Settings. Nie zmieniono przypisań terminala, aplikacji,
nawigacji oknami ani istniejącego Hypridle/Hyprlock. Poprzednia instalacja
została zachowana. Jej launcher pod Super+Spacja i skróty zrzutów Print
nie mają odpowiedników w obecnym Putkin i po zatrzymaniu starego shella
nie działają. Dotychczasowy helper blokady zachowano; ma samodzielny
fallback Hyprlock. Blokady ani uśpienia nie wywoływano podczas przełączenia.

## Powrót

W terminalu bieżącej sesji:

```sh
~/.local/state/putkin/switch-20260916-5132708bd8f7/restore
```

Skrypt zatrzymuje wyłącznie instancję tej wersji Putkin, przywraca trzy
pliki z kopii, przeładowuje konfigurację Hyprlanda i uruchamia poprzedni
shell. Sprawdza odzyskanie nazwy powiadomień. Nie usuwa żadnej instalacji
i nie zmienia settings.json. Jeśli któryś z trzech plików był później
edytowany, odmawia nadpisania go przed zatrzymaniem shella i wskazuje kopię.
W tym samym katalogu znajdują się `before/`, `after/`, plan oraz logi.

Późniejsze uruchomienie hyprsunset ma osobną konfigurację i
[instrukcję wycofania](desktop.md#aktywacja-lokalna-2026-09-16).
Skrypt powrotu shella nie zmienia stanu tej usługi.

## Wyniki i granice odbioru

- `scripts/check`: 137 QML, zero błędów. Lua: wykonano rejestrację
  66 skrótów, sprawdzono brak kolizji, właściwe polecenia, autostart,
  zachowanie terminala/blokady i cytowanie ścieżek z apostrofem/spacją.
- Odbiór aktywnej sesji: jedna instancja Putkin, jeden właściciel
  `org.freedesktop.Notifications`, brak warstw starego shella,
  pasek 32 px i tapeta na eDP-1 (2880×1800, skala 1,5).
- Ustawienia i Quick Settings: odpowiedź `ok`, widoczna warstwa po końcu
  animacji (368×672 i 368×1004), następnie zniszczenie po zamknięciu.
  Wejście/wyjście z paska działa; załadowano 12 powiązań z Putkin.
- Odczyt fizycznego audio i backlight dostępny. Nie zmieniano poziomów,
  sieci, Bluetooth ani zasilania. Log Putkin i `hyprctl configerrors`
  bez błędów. Przyszłego logowania/autostartu nie sprawdzano przez wylogowanie.
- Rollback sprawdzono na plikach tymczasowych (także ochrona późniejszych
  edycji i powtórne wykonanie) oraz faktycznie podczas pierwszego startu.
  Początkowa procedura miała dwa błędy: specjalny tekst pustej listy
  instancji zamiast JSON oraz zmienną raportu poza zakresem. Drugi błąd
  uruchomił poprawny powrót do starej konfiguracji; oba poprawiono,
  następnie ponownie skutecznie uruchomiono Putkin.

Dowody: [aktywacja](evidence/13-activation.json),
[odbiór sesji](evidence/13-switch-verification.json),
[sumy runtime](evidence/13-runtime-sha256.json),
[log Putkin](evidence/13-putkin.log),
[bramka](evidence/13-switch-check.log),
[skrótów](evidence/13-switch-bindings.log),
[test rollbacku](evidence/13-switch-restore-test.log).

Pełny etap 13 nadal wymaga instalatora `--dry-run`, `--destination`,
`--restore`, przenośnej kontroli zależności oraz testów aktualizacji,
przerwania publikacji, błędów kopiowania/walidacji i ścieżek ze spacjami.
Tych kryteriów nie zastępuje obecne lokalne przełączenie.

API sprawdzone dla lokalnego Quickshell 0.3.1 i Hyprlanda 0.56.2:
[wybór konfiguracji i autoreload](https://quickshell.org/docs/v0.3.1/guide/introduction/),
[oficjalny przykład Lua 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/example/hyprland.lua)
oraz lokalne `--help` Quickshell/uwsm. Jawne `--path` omija nadrzędny
`~/.config/quickshell/shell.qml` należący do starej instalacji.
