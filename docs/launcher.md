# Launcher — rozszerzenie 2026-09-17

`Super+Spacja` / `launcher toggle` otwiera jeden panel na aktywnym monitorze.
`Super+V` / `launcher openClipboard` otwiera od razu filtr Schowek.
`Super+;` / `launcher openCommands` otwiera chip „Komenda” i puste pole
z fokusem, bez Shift. Oba skróty
zmieniają tryb również w już otwartym launcherze i przywracają fokus pola.
Wyszukiwanie bez prefiksu łączy aplikacje, pliki oraz schowek. Puste pole
pokazuje ostatnio wywołane pozycje pod nagłówkiem „Ostatnie”. Wpisz `:a `, `:f ` lub `:c `, aby
zamienić prefiks w etykietę Aplikacje, Pliki lub Schowek. `: ` wybiera
historię. Etykietę usuwa kliknięcie; Backspace w pustym polu odtwarza prefiks.
Lista z filtrem nie ma dodatkowego nagłówka. Schowek pokazuje wyłącznie
jedną linię treści w wierszu 36 px, bez ikony i podpisu „Schowek”. Ikony
oraz dotychczasowa wysokość wierszy aplikacji pozostają. Opis aplikacji
lub ścieżka pliku jest w tej samej linii co nazwa, wyrównany do prawej.
Zajmuje najwyżej 45% szerokości zawartości wiersza; długi tekst jest skracany,
z pozostawieniem miejsca na nazwę. Komendy nadal pokazują sam opis działania.

Enter aktywuje wybraną pozycję. Strzałki wybierają wynik bez opuszczania
pola. Escape/Tab z pola przechodzą do listy: `j/k` wybierają, `h` przechodzi
do filtra/pola, `/` lub `i` wracają do wpisywania. `l` przechodzi do
widocznego podglądu, a gdy go nie ma — do pola. Kolejny Escape
zamyka panel; pusta lista zamyka się pierwszym Escape. Home/End w liście
pozwalają dojść do pierwszej/ostatniej pozycji. `q` zamyka panel z listy lub
filtra; w polu wyszukiwania pozostaje zwykłą literą, podobnie jak hjkl.
Wpis schowka jest kopiowany; użytkownik sam wkleja go do wybranej aplikacji.

## Położenie, lista i przejścia — 2026-09-22

Środek pola wyszukiwania leży na połowie wysokości aktywnego ekranu.
Lista rozwija się pod nim; liczba wyników i podgląd nie przesuwają pola
w pionie. Maksymalnie pięć wierszy mieści się w przewijanej liście
(260 px aplikacji/plików albo 180 px schowka). Na małym ekranie dostępna
wysokość dodatkowo ogranicza listę. Wyniki mieszane uwzględniają wysokość
najkrótszego wiersza, aby po przewinięciu nie pokazać ich więcej niż pięć.
Kółko, przeciąganie suwaka i dotychczasowa nawigacja klawiaturą docierają
do wszystkich wyników. Suwak ma kwadratowe końce, kolory Mocha i wspólny
gradient akcentu przy wskazaniu lub przeciąganiu.

Sekcja wyników wraz z tłem oraz podgląd tekstu/obrazu mają fade 200 ms
InOutCubic. Poprzednia zawartość wygasa przed wymianą modelu, wymiarów lub
źródła obrazu; nowa pojawia się po przygotowaniu układu i obrazu.
Szybkie wpisywanie pokazuje najnowsze zapytanie po zakończeniu wygaszania.
Pole wyszukiwania pozostaje dostępne. Zamknięcie zwalnia utrzymywaną
klatkę podglądu po fade; backend od razu anuluje odczyt i usuwa swój wynik.

## Podgląd schowka — 2026-09-20

Wybrany klawiaturą lub najechaniem wskaźnika wpis schowka ma podgląd po
prawej stronie launchera, z tym samym górnym brzegiem. Ramka jest kwadratowa,
domyślnie 320 × 320 px, z odstępem 8 px od listy. Obraz zachowuje proporcje;
tekst jest dosłowny, zawija się i przewija. `l`/Tab wchodzi do podglądu,
`j/k` przewija, `h`/Escape/`q` wraca do listy, Enter kopiuje wybrany wpis.
Samo wybranie pozycji niczego nie kopiuje ani nie zmienia historii.

Główna lista zachowuje szerokość do 640 px. Miejsce na opcjonalny podgląd
jest rezerwowane przy otwieraniu, więc jego pojawienie się nie przesuwa
grupy. W razie potrzeby grupa zaczyna bliżej lewej krawędzi, a podgląd
zmniejsza się do dostępnego miejsca. Jeśli nie
mieści się kwadrat co najmniej 160 px, podgląd znika. Obie ramki używają
jednego gradientu grupy; natywna maska wejścia obejmuje tylko te prostokąty.
Ramki fokusu pojawiają się wyłącznie przy nawigacji klawiaturą.

Pomocnik dekoduje tylko wybraną pozycję z prywatnego cliphist, asynchronicznie
i z anulowaniem poprzedniego odczytu. Rewizja oraz ID odrzucają spóźnione
odpowiedzi. Tekst ma limit podglądu 32 768 znaków, niezależny od skrótu
160 znaków w liście; kopiowanie nadal zachowuje cały wpis do 2 MiB. Obraz
trafia do Qt jako adres data, bez dodatkowego pliku; Qt używa
sourceSize 640 × 640 i `cache: false`. Zmiana wyboru,
filtru lub zamknięcie usuwa poprzednią treść serwisu; widok zachowuje
poprzednią klatkę tylko na czas wygaszania. Brak nowych podpisów,
podpowiedzi i tooltipów.

## Komendy workspace

W pustym polu bez aktywnego filtra wpisz `:wN` albo `:mwN`, gdzie N jest
jedną cyfrą 0–9, i zatwierdź Enterem (lub kliknij wynik). `:w3` przełącza
na workspace 3 na monitorze launchera; `:mw3` przenosi tam okno aktywne
przed otwarciem panelu, bez przełączania widoku. `0` oznacza workspace 10,
zgodnie z obecną konfiguracją skrótów. Nowy workspace może powstać, nawet
gdy jego numeru nie ma jeszcze w pasku. Wielkość liter nie ma znaczenia.

Niepełna lub niepoprawna komenda workspace pozostawia pustą listę, bez tekstu
pomocniczego. Sam `:` rozpoczyna tryb komend i pokazuje zapisane komendy;
`: ` nadal wybiera historię. Aktywny filtr
zachowuje dosłowne wyszukiwanie, np. `:c :w3` znajduje tekst w schowku.
Komendy nie trafiają do historii aplikacji/plików ani pomocnika Python.
W trybie z chipem „Komenda” dwukropek jest dodawany do zapytania wewnętrznie;
w polu wystarcza `w3`, `mw3` lub skonfigurowana nazwa komendy. Usunięcie
chipa przywraca zwykłe wyszukiwanie. Puste pole w tym trybie pokazuje zapisane
komendy z sekcji „Klawiatura”. Lista zawęża się według początku nazwy bez
rozróżniania wielkości liter, np. `:sl` lub `sl` w trybie „Komenda” pokazuje
„Uśpij”. Dokładne dopasowanie jest pierwsze, pozostałe są alfabetyczne według
nazwy komendy. Enter lub kliknięcie uruchamia wybraną podpowiedź przez wspólny
`ActionController`, także przed wpisaniem całej nazwy. Wiersz komendy zawiera
tylko opis działania, bez dodatkowego podpisu `:nazwa`. Prefiksy `:a`, `:f`
i `:c` stają się filtrami dopiero po spacji.
[Ustawienia skrótów i komend](keyboard.md).

Domyślnie dostępne są `shutdown` i `poweroff` (wyłączenie), `sleep`
(uśpienie), `hibernate` (hibernacja), `lock` (blokada), `reboot` (restart)
oraz `settings` (ustawienia). W zwykłym launcherze wpisz `:shutdown` itd.;
w trybie „Komenda” samą nazwę. Restart i wyłączenie otwierają potwierdzenie
wybranej operacji z fokusem na Anuluj. Uśpienie i hibernacja czekają na
potwierdzoną przez kompozytor blokadę. Niedostępna operacja zgłasza błąd.
`shutdown` i `poweroff` wskazują jedną pozycję „Wyłącz komputer”, także na
pełnej liście komend. Obie nazwy i ich części nadal są dopasowywane.

`powersaver`, `balanced` i `performance` ustawiają profil oszczędny,
zrównoważony lub wydajności, korzystając ze wspólnej obsługi panelu baterii.
Potwierdzony przez system profil jest od razu widoczny w tym panelu.
Niedostępny profil lub trwająca zmiana zgłasza błąd.

`LauncherService` otrzymuje ten sam `WorkspaceService` co pasek. PanelHost
przekazuje monitor, a serwis zapamiętuje natywny obiekt okna przed pobraniem
fokusu przez panel. Zamknięte okno lub niedostępny Hyprland daje błąd;
nie wybiera innego okna w zastępstwie. Stan natywnego workspace/okna
potwierdza wynik z limitem 2 s. Powtórny Enter w trakcie oczekiwania nie
wysyła kolejnej akcji. Spóźnione potwierdzenie nie zamyka nowej sesji panelu.
Komendy działają również przy niedostępnym pomocniku wyszukiwania.

Hyprland dopasowuje symbol bazowy osobno od modyfikatorów: zapis
skrótu to `SUPER + semicolon`.
[Implementacja dopasowania v0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/managers/KeybindManager.cpp).

## Stan i granice

- Ikony aplikacji (2026-09-20): wspólne Material Symbols Outlined, pole SVG
  24 px z paddingiem 4 px, kolor `Theme.text`. `Icons.launcher` dobiera
  lokalny symbol według ID, nazwy, pola Icon i kategorii DesktopEntry.
  Signal/Tether mają własne dopasowane SVG. Nieznane wpisy dostają `apps`;
  pliki, komendy i wyszukiwanie korzystają z tej samej geometrii.
  Zwarte wiersze schowka nie pokazują ikony.
  Ikony aplikacji i motywy systemowe nie są ładowane ani przetwarzane.
- Jeden `LauncherService` z jawnym `LauncherBackend`, wspólny `PanelHost`,
  koordynator i natywny grab. Widok nie importuje Quickshell.Io i nie uruchamia
  komend. Korzeń dodaje tylko instancje oraz przekazanie zależności.
- `LauncherQuery.js` przenosi parser, ranking i łączenie wyników poprzednika.
  Brak zależności runtime od `../putpuccin`; nie przenosimy poleceń `:!`,
  kontekstu terminala ani pozostałych usług starego shella.
- Katalog aplikacji: `DesktopEntries.applications`, z odrzuceniem NoDisplay.
  Ranking nazwy, genericName, słów kluczowych i opisu; historia przed resztą
  aplikacji przy pustym `:a `. Uruchomienie używa natywnego argv i katalogu
  roboczego; Terminal=true korzysta z obecnego w środowisku Kitty.
  Potwierdzenie oznacza start procesu/brak natychmiastowego błędu, nie
  gwarancję, że zewnętrzna aplikacja utworzyła okno.
- Pliki: `fd 10.5.0`, katalog domowy, zwykłe pliki bez ukrytych katalogów,
  bez przekraczania systemu plików, maksymalnie 100 trafień. Dosłowny wzorzec,
  debounce 140 ms, deadline 3 s, anulowanie i rewizje odrzucające stare wyniki.
  `xdg-open` dostaje osobny argument; tekst nie trafia do powłoki.
- `${XDG_STATE_HOME:-~/.local/state}/putkin/launcher.json`: do 100 unikalnych
  identyfikatorów aplikacji i ścieżek plików. Zapis atomowy, plik 0600,
  nowy katalog 0700; błędny/obcy schemat pozostaje nietknięty. Historia
  bieżącej sesji działa także przy błędzie zapisu; błąd trafia do toastu.
- Schowek: dwa zdarzeniowe `wl-paste --watch` (text/image), `cliphist 0.7.0`,
  prywatny katalog w XDG_RUNTIME_DIR. Limit 100 wpisów po 2 MiB, pomijanie
  `CLIPBOARD_STATE=sensitive/nil/clear`; treści bez takiego oznaczenia mogą
  trafić do historii. Bez trwałego zapisu treści/ID schowka w historii MRU.
  Przeszukiwana jest reprezentacja `cliphist list` (podgląd do 160 znaków),
  przywrócenie zachowuje oryginalne bajty i rozpoznany MIME. Wybrany wpis
  ma osobny podgląd tekstu lub obrazu opisany wyżej. Brak automatycznego wklejania.
- Jedno dziecko Python obsługuje JSON na stdin/stdout bez pollingu. Wyszukiwanie
  jest asynchroniczne, a operacje schowka mają limity czasu. Odczyt listy tylko
  przy widocznym launcherze. EOF/SIGTERM/reload zwalniają watchery, aktualnego
  właściciela wl-copy i prywatną bazę. Restart/reload czyści schowek launchera;
  własność przywróconego wpisu wl-copy również kończy się z procesem.
- Brak narzędzia nie blokuje pozostałych źródeł. Błędy operacji pokazuje wspólne
  `ErrorNotifications`. Po awarii całego pomocnika konieczny restart shella.

## API sprawdzone przed użyciem

Podgląd ponownie sprawdzony na lokalnym Qt 6.11.2 / Quickshell 0.3.1,
Pythonie 3.14.7 oraz cliphist 0.7.0. Oficjalne API:
[Image](https://doc.qt.io/qt-6.11/qml-qtquick-image.html),
[Text](https://doc.qt.io/qt-6.11/qml-qtquick-text.html),
[ScrollView](https://doc.qt.io/qt-6.11/qml-qtquick-controls-scrollview.html),
[Control](https://doc.qt.io/qt-6.11/qml-qtquick-controls-control.html),
[HoverHandler](https://doc.qt.io/qt-6.11/qml-qtquick-hoverhandler.html),
[Region](https://quickshell.org/docs/v0.3.1/types/Quickshell/Region/),
[base64](https://docs.python.org/3.14/library/base64.html).

Lokalnie: Quickshell 0.3.1, Qt 6.11.2, Python 3.14.7, fd 10.5.0,
wl-clipboard 2.3.0, cliphist 0.7.0. Oficjalne dokumenty:
[DesktopEntries](https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntries/),
[DesktopEntry](https://quickshell.org/docs/v0.3.1/types/Quickshell/DesktopEntry/),
[Process](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/),
[SplitParser](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/SplitParser/),
[TextField](https://doc.qt.io/qt-6.11/qml-qtquick-controls-textfield.html),
[ListView](https://doc.qt.io/qt-6.11/qml-qtquick-listview.html),
[asyncio subprocess](https://docs.python.org/3.14/library/asyncio-subprocess.html),
[wl-clipboard 2.3.0](https://github.com/bugaevc/wl-clipboard/blob/v2.3.0/data/wl-clipboard.1),
[cliphist 0.7.0](https://github.com/sentriz/cliphist/tree/v0.7.0).
Opcje fd sprawdzone przez `fd --help` z zainstalowanego pakietu 10.5.0;
wersjonowane repozytorium upstream nie było dostępne przez narzędzie WWW.

Rozszerzenie workspace: ponownie sprawdzone Qt 6.11.2, Quickshell 0.3.1
i Hyprland 0.56.2. Lokalny plik `quickshell-hyprland-ipc.qmltypes` potwierdza
typ `HyprlandToplevel` dla `activeToplevel`, pola `address`/`workspace`
oraz sygnał `workspaceChanged`.
[Hyprland](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/),
[HyprlandToplevel](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandToplevel/),
[dispatchery v0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsDispatchers.cpp),
[selektor okna v0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsInternal.cpp).
Ruch używa `hl.dsp.window.move` z `follow = false` i sprawdzonym adresem
żywego obiektu; starszy tryb konfiguracji używa `movetoworkspacesilent`.

## Sprawdzenie

Wersja aktywna i wyniki testów: [odbiór](status.md),
[wycofanie aktualizacji](install.md).

`scripts/check`, `scripts/test`, `scripts/test-launcher-integration`.
Podglądy: `scripts/preview --scenario launcher|launcherApps|launcherFiles|launcherClipboard`.
Tekst i obraz: `launcherClipboardText` / `launcherClipboardImage`.
Komendy: scenariusze `launcherWorkspace` i `launcherMove` oraz
`scripts/test-bar-integration` (natywne modele/dispatchery, prywatna atrapa Hyprlanda).
Testy używają prywatnych HOME/XDG/D-Bus, offscreen oraz atrap wl-paste,
wl-copy i uruchamianych aplikacji; `DesktopEntries`, `fd`, `cliphist`, proces,
IPC i LazyLoader są rzeczywiste. Wyniki i granice odbioru: [status](status.md).
