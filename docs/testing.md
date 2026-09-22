# Testowanie Putkin

## Instalator, Signal i dotfiles — 2026-09-22

```sh
scripts/check
python3 -m unittest discover -s tests -p test_install.py -v
python3 -m unittest discover -s tests -p test_dotfiles.py -v
python3 -m unittest discover -s tests -p test_clean_slate.py -v
python3 -m unittest discover -s tests -p test_signal_bootstrap.py -v
python3 -m unittest discover -s tests -p test_install_preflight.py -v
python3 -m unittest discover -s tests -p test_signal_release.py -v
```

Dotfiles: świeży cel i aktualizacja, lokalna edycja, `seed`, backup/restore,
przerwanie procesu między zapisami, odtworzenie dowiązań bez odczytu ich
zewnętrznych celów, ścieżki ze spacjami/znakami shella, domyślny i nowy profil
Zen, eksport zmienionych preferencji, canary klucza/tokena/cookies oraz
odrzucanie niedozwolonych ścieżek. Nie ma skanowania całego HOME ani eksportu
profilu przeglądarki. Nowe pozycje katalogu wymagają przeglądu treści.

Bootstrap: zweryfikowane pobranie, ponowne użycie offline, zła suma,
niepełne pobranie, puste cache w dry-run i odrzucenie wskazanego złego runtime.
Osobny odbiór rzeczywistego buildera odtwarza dokładny pin dystrybucji;
`scripts/test-signal-cli` wykonuje realne JSON-RPC bez konta/sieci,
a `scripts/test-signal-release --package KATALOG --output RAPORT` testuje
bridge/CLI/JRE z zainstalowanego wydania.

Preflight: produkcyjne importy są kompilowane w prawdziwym Quickshellu,
a nie wyszukiwane w źródłach jako substytut testu. Celowo brakujący moduł
musi dać błąd. Nie tworzymy PanelWindow ani produkcyjnych adapterów;
offscreen nie udostępnia backendu natywnych paneli. Pełną strukturę QML
sprawdza `scripts/check`. Prawdziwy Hyprland sprawdza poprawną i celowo
błędną konfigurację przez `--verify-config`; nie uruchamia kompozytora.
Obie próby mają prywatne XDG, przestrzenie PID/montowań/sieci i brak PAM,
systemowego D-Bus oraz sprzętu hosta. Bubblewrap jest wymagany.

Start: ostrzeżenie traya zostaje zgłoszone bez wycofywania gotowego shella;
TypeError, utrata procesu, obcy właściciel powiadomień i brak gotowości
nadal powodują błąd. Testy zachowują blokadę sesji, odtworzenie poprzedniej
instancji i odmowę downgrade’u zmigrowanej historii Signal.
Rzeczywistej aktywacji na drugim komputerze nie zastępuje test katalogu `/tmp`.
[Wyniki](status.md#instalacja-przenośna-i-modułowe-dotfiles--2026-09-22).

`--clean-slate`: rzeczywiste usunięcie dawnych niezarządzanych plików,
reset lokalnych edycji i `seed`, zachowanie kluczy, tokenów i danych profilu
również na poziomie inode/mtime; brak sekretów w backupie testowych zakresów.
Testy obejmują lokalne oraz systemowe wpisy autostartu, maski usług i ich
powiązania, dowiązania do zewnętrznych danych, nieudany backup, przerwanie
procesu podczas kasowania i zapisu oraz błąd po publikacji nowego domyślnego
Quickshella. Osobno sprawdzane są dry-run, sprzeczne flagi, nietypowe nazwy
w katalogu Zen oraz odmowa przy nakładaniu XDG backup/runtime na czyszczony
katalog. Pełny prywatny przebieg: clean install → kontrola 173 plików →
restore całej kopii → kolejny clean install. Żaden test nie czyści konfiguracji
hosta. [Wyniki](status.md#tryb-clean-slate--2026-09-22).

## Okna uwierzytelniania — 2026-09-20

`python3 -m unittest discover -s tests -p test_authentication.py -v`
sprawdza Assuan: UTF-8, escaping, porcje danych, błędy i timeout,
potwierdzenie/odmowę/anulowanie, reset oraz jawne odrzucenie nieobsługiwanych
wymagań tworzenia hasła. Nie uruchamia agentów użytkownika.

`python3 scripts/test-icons --file tst_authentication.qml` testuje wejście
Qt, hjkl/Enter/Escape oraz `q` poza polem hasła, fokus myszy/klawiatury, czyszczenie sekretów,
zmianę tożsamości, kolejkę i blokadę. Rozróżnia niedopasowanie, błąd
czytnika oraz sukces odcisku i hasła. Używa atrap i prywatnych XDG/D-Bus.
Odliczanie ma test wypełnienia, glifu po prawej, niezmiennej geometrii,
ramki klawiatury po przejściu do hasła i jej usunięcia myszą. Sprawdza
wcześniejsze żądanie hasła, brak fałszywego przejścia po samym zegarze,
zatrzymanie przy anulowaniu, ponowienie i odczyt konfiguracji timeout.

`python3 scripts/test-wayland --nested --authentication --output artifacts/authentication-wayland`
sprawdza produkcyjny widok, Socket/IPC i natywny PolkitAgent/AuthFlow przez
prawdziwe libpolkit. W prywatnych przestrzeniach PID/montowań/sieci działa
atrapa authority, zastąpiony protokół helpera Polkit oraz fixture identyfikacji
sesji systemd. `/etc/pam.d` i `/usr/lib/pam.d` są zamaskowane. Żaden test
nie używa PAM ani czytnika hosta. Prawdziwy GPG agent dostaje osobny GNUPGHOME,
nowo utworzony klucz testowy i Pinentry Putkina; podpis jest weryfikowany,
a agent kończony. Klucze użytkownika nie są odczytywane.

Odbiór obejmuje anulowanie i SIGTERM, kolory odcisku z utrwaleniem zielonej
klatki przed wspólnym fade, obie odmiany reloadu, ponowną rejestrację,
zwolnienie gniazd i brak błędów QML. Zrzuty dotyczą prywatnego wyjścia.
Prywatna konfiguracja określa timeout 2 s, a atrapa helpera po tym czasie
wysyła rzeczywisty protokół timeout → żądanie hasła. Wtype potwierdza
możliwość natychmiastowego wpisania hasła bez kliknięcia pola.

## Odzyskiwanie aktywnego workspace — 2026-09-20

`scripts/test-bar-integration` wykonuje cztery scenariusze: Hyprlang i Lua,
każdy ze zwykłą odpowiedzią oraz pierwszym `j/monitors` podzielonym na dwa
zapisy gniazda. Weryfikuje odzyskanie aktywnych numerów i skupionego monitora,
`focusedmon` z nieznanym workspace, przełączenie na drugi monitor, komendy
launchera, brak odpytywania w spoczynku, hotplug, EOF i odczyt `bar status`.
Wszystkie gniazda, XDG i D-Bus są prywatne; działają natywne modele Quickshella.
`tst_bar.qml` uzupełnia odbiór o kliknięcia, klawisze i oznaczenia w UI.

## Interakcje powiadomień — 2026-09-20

`python3 scripts/test-icons --file tst_notifications.qml --log /tmp/putkin-notifications-qml.log`
sprawdza kliknięcia w nagłówek, tytuł i treść, oba Entery, wybór akcji
domyślnej i brak akcji, `i/Escape`, przejście do następnej karty i powrót,
zachowanie rozwinięcia, obsługę myszy bez ramki, przewijanie kółkiem nad
krótką/długą/rozwiniętą treścią i dojście do ostatniej z 20 kart.
Rozwinięcie sprawdzane jest również przy 320×220 i dla biernych toastów.
Testy używają prawdziwego wejścia Qt oraz produkcyjnych widoków z atrapami,
w prywatnych XDG/D-Bus. Regresja współdzielonych kontrolek i paneli:
`tst_quick_menu.qml`, `tst_panels.qml`, `tst_launcher.qml`, `tst_material_icons.qml`.

## Stabilny fade — 2026-09-20

`tests/qml/tst_fade.qml` porównuje piksele ramki, tekstu i aktywnego kafelka
przy opacity 0,25 / 0,5 / 0,75 z pojedynczym złożeniem obrazu końcowego
na tle. Sprawdza oczekiwanie na gotowość, stałą geometrię podczas fade,
zamknięcie przed przygotowaniem, zmianę strony, ponowne otwarcie podczas
zanikania oraz zagnieżdżone przejścia i zakończenie pracy klatkowej.
Zanikanie zachowuje ostatnią wyrenderowaną klatkę także po wyłączeniu
kontrolek i utracie fokusu; test pikseli obejmuje panel i zwijaną kolumnę.
`tst_quick_menu.qml` sprawdza położenie treści przy zwijaniu sekcji,
w tym wybór trybu Caffeinate i granice przewijania przy trzech wysokościach.
Testy ustawień obejmują brak opcji ruchu, nawigację po jej usunięciu i
odczyt starych booleanów bez zapisu, z ich usunięciem przy jawnym zapisie.

GPU sprawdza `python3 scripts/test-fade-wayland --nested --scale 1`
(również `--scale 1.25`). Runner używa prywatnych przestrzeni PID,
montowań i sieci, XDG, D-Bus i zagnieżdżonego Hyprlanda. Udostępnione są
wyłącznie gniazdo Waylanda rodzica i węzeł renderera GPU; domeny sprzętu
i sesji w widokach są atrapami. Zapisuje logi, raport i wynik sprzątania.
Uruchamia też produkcyjne okno panelu i wybiera tryb Caffeinate przez
klawiaturę. Podczas zwijania natywna warstwa musi zachować rozmiar:
zmniejszanie bufora Waylanda powodowało pojedynczą przeskalowaną klatkę.
Wynik i próbki geometrii zapisuje w `native-collapse.json`.
Wcześniejsze testy opcji ograniczania ruchu opisują historyczny kontrakt.

## Lista i podgląd launchera — 2026-09-20, korekta 2026-09-22

`python3 scripts/test-icons --file tst_launcher.qml --log artifacts/launcher-preview-qml.log`
sprawdza prawdziwe wejście Qt: brak powtórzonych nagłówków, wiersze schowka
36 px bez ikony/podpisu, wybór wskaźnikiem i klawiaturą, brak kopiowania
przez podgląd, l/h, j/k i Enter, dosłowny tekst i proporcje obrazu, ramkę
wyłącznie przy klawiaturze, spóźnione odpowiedzi oraz sześć rozmiarów ekranu.
Korekta obejmuje środek pola przy pięciu rozdzielczościach od 320×220 do
1920×1080, limit pięciu wierszy, Home/End, prawdziwe kółko i przeciąganie
suwaka. Testy zmian zapytania i tekst → obraz sprawdzają pośrednie opacity,
zachowanie starej zawartości i geometrii do opacity 0, wybór najnowszego
zapytania oraz zwolnienie podglądu po fade. `tst_fade.qml` sprawdza ten sam
kontrakt bez launchera, w tym przerwaną wymianę i zatrzymanie pracy klatkowej.

`python3 -m unittest discover -s tests -p test_launcher.py -v` dekoduje
prawdziwe wpisy cliphist: wieloliniowy UTF-8, PNG, limit tekstu, zły/usunięty
ID, ukryty launcher oraz anulowanie i zebranie procesu dekodera.
`scripts/test-launcher-integration` łączy produkcyjne QML/JSON/Process,
cliphist i Qt Image z atrapami watcherów i właściciela schowka. Sprawdza
pełny tekst, zmianę tekst ↔ obraz, geometrię, brak kopii przy podglądzie,
zwolnienie treści po zamknięciu i sprzątanie po reloadzie.

`scripts/test-wayland --nested --launcher-preview --output artifacts/launcher-preview-wayland`
uruchamia produkcyjne okno panelu na prywatnym kompozytorze, z atrapami
schowka i sprzętu. Wtype oraz prywatny wskaźnik sprawdzają fokus, przewijanie,
kliknięcie wewnątrz podglądu, poza krótszą listą i w przerwie pomiędzy
ramkami, skalę 1,5 oraz pojedynczą aktywację Enterem. Zrzuty dotyczą tylko
prywatnego wyjścia. Korekta dodaje natywne centrowanie pola w obu skalach,
20 aplikacji w liście pięciu wierszy, dojście do ostatniej i zapis pośrednich
klatek opacity oraz geometrii przy zmianie wyników i podglądu.
Pełna regresja QML obejmuje pozostałych użytkowników
`PanelSurface`. [Rzeczywiste wyniki](status.md).

## Domyślne qs i retencja buildów — 2026-09-20

```sh
scripts/check
python3 -m unittest discover -s tests -p test_install.py -v
scripts/install --dry-run --destination /tmp/putkin-install-preview
```

`test_install.py` sprawdza rzeczywiste pliki: staging i instalację przez
CLI, ponowną instalację bez nowego buildu, osiem aktualizacji z limitem
pięciu, powrót przez CLI, zachowanie ustawień, błąd kopiowania/walidacji,
uszkodzoną paczkę, ścieżki ze spacjami/metaznakami i przerwanie procesu
tuż przed oraz po atomowej publikacji. Osobny scenariusz awarii aktywacji
odtwarza poprzednią konfigurację domyślną i tożsamość instancji na atrapach.
Dry-run nie zmienia nowego ani istniejącego celu. Retencja chroni aktywny
i poprzedni build, obce dowiązania i stan aplikacji.

Prawdziwy Quickshell działa tylko z małym obiektem IPC, prywatnymi XDG,
D-Bus i renderowaniem offscreen. Test sprawdza wykrywanie domyślnego
katalogu, względne importy, brak duplikatu i brak reloadu po zmianie
`current`. Atrapy executable sprawdzają UWSM service, przekazanie tapety
bez interpretacji przez shell, zwykłe IPC i stałą ścieżkę helpera blokady.
Żaden z tych testów nie uruchamia pełnego shella, blokady ani PAM hosta.
Sandbox blokujący socket prywatnego D-Bus wymaga rozszerzonych uprawnień
wyłącznie do tej izolowanej próby; błąd pozostaje widoczny w logu.

Odbiór instalacji na pulpicie jest oddzielny: dokładnie jedna instancja,
`putkin.service` w slice UWSM, powtórne `qs` z tym samym PID, właściciel
powiadomień, pasek/tapeta, Ustawienia, gotowość blokady, Caffeinate i
zachowane pliki użytkownika. Test nie wywołuje locka, snu ani logowania.
Wyniki i ograniczenia: [status](status.md).

## Screenshot — 2026-09-20

```sh
scripts/check
python3 -m unittest discover -s tests -p test_screenshot.py -v
python3 scripts/test-icons --file tst_screenshot.qml --log artifacts/screenshot-qml.log
python3 scripts/test-icons --all-qml --log artifacts/screenshot-all-qml.log
python3 scripts/test-wayland --nested --screenshot --output artifacts/screenshot-wayland
```

QtTest wykonuje rzeczywiste przeciągnięcia i klawisze produkcyjnych widoków
z atrapą adaptera: oczekiwanie na Enter i odmapowanie, Q/Escape przed/po,
W z zapamiętanym oknem, brak okna, brak zakresu, zmiana ekranów, blokada,
podwójne zatwierdzenie, spóźniony wynik, zapis/błąd/ponowienie oraz fokus
myszy/klawiatury. Sprawdza również migrację poprzedniego katalogu skrótów.
Testy Python uruchamiają rzeczywisty pomocnik z atrapami grim/hyprctl/wl-copy;
porównują bajty PNG, skalę/obrót/ujemną pozycję, prawa i unikalność plików,
awarie, zachowanie schowka oraz sprzątanie plików i procesu po SIGTERM.

`--screenshot` używa istniejącego izolowanego runnera Waylanda. Produkcyjne
okna i adapter działają w prywatnym kompozytorze oraz schowku; pozostałe
domeny są atrapami. Wtype uruchamia Print i wpisuje `:screenshot`, klient
virtual-pointer przeciąga obszar. Test porównuje rzeczywiste wymiary i
bajty schowka/zapisu, pływający podgląd i jego natywny fokus, czysty obraz
po zniknięciu nakładki, także przy animacjach kompozytora, oraz skalę 1,25
z ujemną pozycją monitora. Dwa cykle soft reload, hard reload Quickshella
i reload konfiguracji Hyprlanda kończą się rzeczywistym Print/Enter:
porównaniem pikseli z nieruchomym oknem odniesienia, kontrolą PNG w schowku,
sprzątania, jednej rejestracji Print oraz braku ostrzeżeń runtime.
Pliki i procesy testowe są usuwane. Pomiar czasu
obejmuje narzut IPC/wtype i odczytu schowka, nie jest benchmarkiem sprzętu.

## Natywna blokada i bezczynność — 2026-09-20

```sh
scripts/check
scripts/test
scripts/test-session-integration --output artifacts/native-session.json
scripts/test-wayland --nested --native-session --output artifacts/native-session-wayland
```

`tst_lock_idle.qml` testuje produkcyjną logikę i pole hasła: secure przed
rozmową PAM, odrzucenie starego wyniku, wstrzymanie uwierzytelniania przed
snem, dosłowne hjkl, Enter/Escape, fokus tylko z klawiatury, reset błędu
po 2 s, dim/restore tego samego urządzenia, brak backlight i oba tryby
Caffeinate. Wszystkie zdarzenia i urządzenia są atrapami.

`--native-session` uruchamia prawdziwe WlSessionLock, PamContext i IdleMonitor
w prywatnym Hyprlandzie. bwrap izoluje PID, oba D-Bus i urządzenia, maskuje
`/etc/pam.d` oraz `/usr/lib/pam.d`. Kompilowana `session_pam_fixture.c`
odmawia startu poza tą izolacją. Znane testowe hasło i sterowane wyniki
odcisku nigdy nie używają konta, PAM ani skanera hosta.

Test wysyła rzeczywiste klawisze przez wtype, sprawdza odrzucenie złego
hasła, sukces obu rozmów PAM, reset koloru odcisku, hotplug ekranów,
odroczenie reloadu podczas blokady i reload po odblokowaniu. Skrócone
progi 2/3/4/8 s sprawdzają prawdziwe zdarzenia idle, dim na atrapie jasności,
DPMS potwierdzone stanem monitorów kompozytora, blokadę oraz wywołanie snu
wyłącznie w atrapie logind. Inhibitory powstrzymują właściwe progi.
Na końcu zakończenie klienta musi pozostawić kompozytor zablokowany.
Zrzuty, raport i kontrola usunięcia procesów są zapisywane w katalogu wyniku.

Dawne testy Hyprlocka i Hypridle oraz opcje `--lock-wallpaper`/
`--lock-fingerprint` zostały usunięte wraz z ich implementacją. Zastępują je
powyższe testy natywne; historyczne dowody pozostają w `docs/evidence`.
Prawdziwe hasło, fizyczny skaner i suspend/resume hosta wymagają osobnego
odbioru użytkownika. Prywatny D-Bus sam w sobie nie izoluje PAM.

## Material Symbols — 2026-09-20

`python3 scripts/test-icons` sprawdza rzeczywiste piksele każdego lokalnego
symbolu: jeden kolor (z antyaliasingiem), obecność rysunku, sekcyjne pola,
padding i centrowanie. `--scale 1.25|1.5|2` powtarza odbiór na innym DPR;
`--all-qml` obejmuje całą regresję QML; `--file tst_launcher.qml` wybiera
konkretny zestaw. Runner zachowuje surowy log również przy błędzie/timeout.
Prywatne HOME, XDG i D-Bus, software, wyłącznie atrapy.

`tst_launcher.qml` sprawdza rozpoznane aplikacje, Signal, Tether, brak ikony,
puste pole i obcą bitmapę oraz aktywację Enterem. `tst_status.qml` obejmuje
wszystkie poziomy baterii i ładowania, nieznany odczyt, identyfikację SNI,
jednobarwne piksele i środek ikon w przycisku. `tst_visual_contract.qml`
sprawdza rodzinę Network WiFi przy zmianie siły, radia i Ethernetu
oraz rozmiar 20 px / padding poziomy 6 px paska. Porównuje kolor ikon z tekstem
zegara przy zmianie połączenia, radia, DND, wyciszenia i dostępności.
`tst_notifications.qml` obejmuje dzwonek bez nieprzeczytanych, z nowym
wpisem, po wygaśnięciu, DND, odczyt w centrum i zastąpienie wpisu.

`tst_bar_alignment.qml` mierzy jednakowe 5 px nad i pod polem SVG w części
paska nad separatorem oraz rzeczywiste piksele zegara dla trzech formatów
daty w pl_PL/en_US. Dla ośmiu poziomów baterii przełącza atrapę rozładowanie
→ ładowanie → rozładowanie: korpus zachowuje wysokość, pole rośnie z 32 do
36 px, oryginalny piorunek Material jest widoczny po prawej, a po odłączeniu
wraca początkowa geometria. Test sprawdza padding także poszerzonego pola.
Scena zrzutu ma zapas na fizyczne piksele QtTest przy DPR do 2; test jawnie
wykrywa obcięcie. Dopuszczalna różnica odstępów zegara wynosi 1 piksel
przy skali 1 i 2 piksele przy 1,5 ze względu na rasteryzację.
`scripts/test-wayland --nested`, również z `--smoke`, sprawdza stałą wysokość
korpusu baterii, szersze pole podczas ładowania i centrowanie zegara
w zrzucie z prywatnego GPU.
Test pojedynczego koloru dopuszcza cienki rysunek bez całkowicie kryjących
pikseli; nadal sprawdza każdy piksel jako mieszankę jednego koloru i tła.
`tst_desktop.qml` rozpoczyna nawigację dopiero po początkowym fokusie
panelu i jego układaniu: samo `Loader.Ready` poprzedza odroczone przekazanie
fokusu i nie wystarcza do deterministycznego wysyłania klawiszy.
Test audio czeka na układ panelu przed kliknięciem oraz utworzenie delegata
wyjścia przed ustawieniem na nim fokusu; zachowuje asynchroniczny Loader.

Natywne integracje launchera, baterii/traya i powiadomień korzystają z tych
samych wejść co runtime, prywatnych `.desktop` i atrap D-Bus. Launcher nie
wymaga już testowego motywu ani qt6ct; brak SNI pixmap nie daje ostrzeżenia.
Wyniki i podglądy: [status](status.md).

Korekta Signala: `tst_status.qml` przełącza bitmapę przeczytane/nieprzeczytane
przy niezmiennym SNI Active, także w nadmiarze traya. Sprawdza `chat_bubble`
→ `chat` → `chat_bubble`, kolor, geometrię, zachowanie fokusu, Enter,
NeedsAttention, pustą ikonę i usunięcie czytnika po zmianie aplikacji.
Pomiar koloru przy fokusie obejmuje pole samego wektora, bo otaczająca
ramka klawiatury prawidłowo używa gradientu. GrabImage następuje po polish;
reaktywna zmiana może już być wyrenderowana, zanim tryCompare się zakończy.
`scripts/test-status-integration` powtarza zmianę przez prawdziwy SNI
IconPixmap/NewIcon na prywatnym D-Bus. Dodatkowy odbiór
`docs/evidence/signal-chat-installed-assets.py` czyta wyłącznie zasoby
zainstalowanej aplikacji, sprawdzając 44 oryginalne PNG przy DPR 1,5.
Nie otwiera profilu Signala ani nie wysyła wiadomości.

## Ramki Hyprlanda — 2026-09-20

`tst_window_appearance.qml` sprawdza oczekiwanie na backend, scalanie
identycznych stanów, podgląd/anulowanie/zapis, zmianę pliku, zachowanie
ostatniej poprawnej palety, ochronę kontrastu oraz ponowne zastosowanie
po reloadzie i odzyskaniu gotowości backendu.

`scripts/test-keyboard-wayland` uruchamia produkcyjny adapter ramek obok
rzeczywistych ustawień i klawiatury na prywatnym kompozytorze. Odczytuje
konfigurację przez Lua i porównuje 16 pikseli GPU, w tym cztery narożniki,
z polem sRGB Shella. Kontroluje neutralną ramkę, warianty grup, zapis,
anulowanie i oba reloady. Prywatny HEADLESS 1280 × 900 uniezależnia
geometrię od rozmiaru okna rodzica, aby cień Ustawień nie zasłaniał próbek
ramki. Zrzuty obejmują wyłącznie prywatny Wayland.

## Gradient grupy i aktywne moduły — 2026-09-20

`tst_accent_groups.qml` porównuje rzeczywiste piksele z niezależnie
obliczoną przekątną: ramka i dwa kafelki mają jedno pole, osobne grupy
własne początki, a przesunięcie, resize i scroll aktualizują kolory.
Zagnieżdżona karta nie resetuje gradientu panelu. Test obejmuje zmianę
palety na żywo i kontrast ramki przy obu ciemnych akcentach.
Wariant 520×32 sprawdza równy udział obu osi; zmiana góra–dół nie może
zaniknąć na szerokiej grupie. Osie są normalizowane do rozmiaru grupy.
`tst_visual_contract.qml` klika Wi-Fi, Bluetooth i baterię, sprawdza
podświetlenie, jasne piksele ikony w kolorze zegara, brak fokusu myszy
i zamknięcie; obejmuje również audio, powiadomienia i Quick Menu.
`tst_launcher.qml` sprawdza rozmiar i położenie pojedynczej ramki pola,
jej piksele oraz przejście mysz → wpisywanie `hjkl`.
Piksele zagnieżdżonych kontrolek pobierane są z całej sceny przez
`mapToItem`, aby użyć rzeczywistego położenia na obrazie.

`scripts/test-wayland --nested` zapisuje także widoki aktywnych modułów
Wi-Fi, Bluetooth i baterii. Pełna próba używa GPU, prywatnych wyjść,
atrap usług i istniejącej macierzy rozdzielczości/skali.
Także wariant `--smoke` porównuje osiem rzeczywistych próbek RGB z
przekątną całej grupy: cztery narożniki panelu, trzy kafelki i aktywny
moduł przy prawym brzegu paska. Dodatkowa, dziewiąta próbka tego modułu
przy dolnej krawędzi sprawdza udział osi pionowej. ImageMagick odczytuje
PNG bez jego zmiany. Pełny Wayland zapisuje także fokus wiersza jasności
i temperatury; `tst_quick_menu.qml` klika, nawiguje klawiaturą i sprawdza
jedną ramkę na pełną szerokość każdego z tych wierszy.

## Kafelki, Caffeinate i historia VoxType — 2026-09-20

`tst_quick_menu.qml` obejmuje geometrię dwóch kolumn, położenie ikony
i etykiety, zmianę istniejącej ramki przy off, zewnętrzną ramkę przy on,
mysz bez fokusu, nawigację, opóźnienie i odmowę Caffeinate, `i`/prawy
przycisk, zachowanie trybu po zamknięciu oraz listę w panelu 320×220.
Testy Night Light wymagają automatycznego suwaka i braku odświeżania.
`scripts/test-notifications-integration` uruchamia prawdziwy notify-send
z flagami VoxType 1.0.1 i syntetycznym tekstem; zastąpienie, timeout
i DND muszą zachować historię, także dla innych transient.

`scripts/test-caffeinate-integration` należy do `scripts/test`. Używa
produkcyjnych Process/Python/D-Bus i prywatnego logind zwracającego Unix FD.
Sprawdza oba tryby, ciągłość przy zmianie, off, odmowę i timeout, 20 cykli,
soft/hard reload, EOF oraz utratę procesu i właściciela usługi. Żadna próba
nie korzysta z magistral hosta ani sprzętu. `scripts/test-wayland` dodaje
klawisze nowych kafelków; natywny test sesji z testowym logind sprawdza, że słuchacze
bezczynności tworzą wyłącznie pliki w prywatnym katalogu; Prezentacja
je blokuje, Praca w tle pozwala im działać przy utrzymanym FD `sleep`.


## Quick Menu i centrum powiadomień — 2026-09-19

`tst_quick_menu.qml` testuje rzeczywiste klawisze i kliknięcia: wspólną
ramkę audio, h/l/Enter/i, pojedynczy przystanek Tab, nazwy urządzeń,
opóźnione potwierdzenia kafelków, brak komunikatów postępu i OSD,
błąd wyłącznie jako powiadomienie, osobne panele i własność skanowania,
brak odświeżania Night Light, DND, historię po wygaśnięciu i wyciszeniu,
transient, zastąpienie ID, żywe akcje, limit 100 rekordów, powrót fokusu
po zniknięciu akcji, mysz po usunięciu karty oraz 10 cykli na 320×220.
Dotychczasowe testy domen i nawigacji przechodzą przez nowe moduły.
Integracja powiadomień sprawdza centrum i historię rzeczywistym D-Bus.
Natywny `scripts/test-wayland` obejmuje nowe moduły przy odłączaniu
monitora, 20 cykli paneli, oba rodzaje reloadu oraz 10 otwarć panelu
podczas znikania toastu/OSD. Każde wymaga prawdziwego fokusu klawiatury
i oddania go osobnej aplikacji po zamknięciu panelu.

## Mysz i fokus klawiatury — 2026-09-19

`tests/qml/tst_pointer_focus.qml` wysyła rzeczywiste zdarzenia Qt do
produkcyjnych kontrolek na atrapach. Sprawdza brak widocznych ramek po
kliknięciu workspace’u, każdego modułu paska i kontrolek Quick Settings,
otwieranie paneli oraz zmianę stron, potwierdzenie/anulowanie Power,
overflow i podmenu traya, lewy/prawy/środkowy przycisk, hasło Wi-Fi,
wejście do powiadomień, przeciąganie suwaka i tekst `hjkl`.
Testuje też zmianę mysz → klawiatura → mysz na tym samym elemencie,
ponowne wejście do paska przez IPC i pojedyncze wykonanie działania.
Wspólny wskaźnik jest sprawdzany w drzewie działających widoków, bez
zastępowania testów zachowania wyszukiwaniem tekstu w źródłach.
Zestaw należy do `scripts/test`; wyniki i granice odbioru w [statusie](status.md).

## Okno Ustawienia, skróty i komendy — 2026-09-17

`tests/qml/tst_keyboard.qml` sprawdza edycję i zapis skrótów/komend,
konflikty, zastrzeżone prefiksy, błędy zapisu, zmiany zewnętrzne, spóźnione
odpowiedzi po zamknięciu edytora, zachowanie tekstu hjkl, przełączanie sekcji
oraz dostępność listy i pól w oknie 320×220. Testuje też chip „Komenda”,
zapamiętanie okna przed otwarciem launchera i przekazanie fokusu do akcji.
`tests/test_keyboard.py` wykonuje wygenerowane transakcje w interpreterze
Lua: wymianę skrótów, rollback, cytowanie ścieżek i wykrywanie kolizji
symboli oraz kodów fizycznych klawiszy. Oba zestawy należą do `scripts/test`.

Osobny `scripts/test-keyboard-wayland --output artifacts/keyboard-wayland`
uruchamia prawdziwy Hyprland, FileView, adapter skrótów oraz natywne okno
Ustawienia. `wtype` naciska skróty w prywatnym kompozytorze; test potwierdza
zmianę przypisania, usunięcie starego skrótu, komendy, akcje workspace/okna,
konflikt z obcym skrótem, zapis kolorów i oba rodzaje reloadu. Kontroluje
fokus, dziesięć cykli otwierania/zamykania, logi i zwolnienie procesów.
Sprzęt i sesja mają jawne atrapy. Bubblewrap izoluje XDG, D-Bus, PID-y,
sieć i `/dev`, udostępniając socket Waylanda rodzica oraz render node GPU.
Tylko konfiguracja testowa włącza `input.resolve_binds_by_sym`, ponieważ
`wtype` tworzy własną mapę kodów klawiszy. Wyniki i obrazy: [status](status.md).

## Osobny panel audio i skróty launchera — 2026-09-17

`tst_audio.qml` sprawdza oba suwaki, wyciszanie, wybór wejścia/wyjścia,
niezależność kanałów, brak optymistycznego potwierdzenia, opóźnienie,
odmowę, timeout, odłączenie urządzenia i backendu, nawigację j/k/h/l/Enter,
mysz, przewijanie małego panelu, powrót fokusu, monitor i 20 cykli.
`scripts/test-audio-integration` używa prywatnego PipeWire z dwoma
wirtualnymi sinkami i dwoma source: rzeczywiste Props, preferencja kontra
potwierdzony default, zmiana zewnętrzna, hotplug, restart, soft/hard reload.
Żadnego mikrofonu ani wyjścia sprzętowego nie otwiera.

`tst_launcher.qml` obejmuje brak podpowiedzi niepełnych komend i zmianę
trybu wraz z fokusem/kursorem. `scripts/test-launcher-integration` wywołuje
produkcyjne `openCommands` i `openClipboard`, także w już otwartym panelu.
Podglądy: `scripts/preview --scenario audioPanel|audioPanelNoInput|audioPanelUnavailable|launcherCommands|launcherIncomplete`.
Wyniki, zrzuty i granice odbioru: [status](status.md).

Etapy 00–12, 2026-09-16. Wyniki odbioru: [etap 12](validation.md), [status](status.md),
[fundament](evidence/00-foundation.md), [pasek](evidence/01-bar.md),
[panele](evidence/02-panels.md), [wygląd](evidence/03-appearance.md), [audio](evidence/04-audio.md), [jasność](evidence/05-brightness.md), [bateria/tray](evidence/06-battery-tray.md), [sieć](evidence/07-network.md), [Bluetooth](evidence/08-bluetooth.md), [powiadomienia](evidence/09-notifications.md). Wymagania i wersje:
[development.md](development.md).

## Odbiór całości — etap 12

```sh
scripts/check
scripts/test
scripts/test-validation-integration --idle --output artifacts/validation.json
scripts/measure-idle --panels --output artifacts/validation-baseline.json
scripts/validate-visuals --output artifacts/validation-visuals
```

`tests/qml/tst_validation.qml` składa wszystkie domeny 00–11 jednocześnie
z jawnymi atrapami. Wysyła rzeczywiste klawisze Qt: workspace, wejście do
panelu, oba akcenty i zapis, suwaki audio/jasności, hasło zawierające hjkl,
sparowane urządzenie, DND, krytyczny toast i anulowanie Power. Osobno
sprawdza bierne OSD/toasty przy wpisywaniu tekstu, zanik i powrót wszystkich
usług w jednym panelu oraz osiem logicznych rozmiarów wynikających z dwóch
rozdzielczości i czterech skal. To test geometrii Item, nie monitorów Waylanda.

`scripts/test-validation-integration` używa rzeczywistego Quickshella,
FileView, LazyLoader i produkcyjnych handlerów IPC, z atrapami domen.
Każdy z 20 cykli przechodzi moduł Wi-Fi/skanowanie → ustawienia/podgląd
koloru → Power → overflow traya → zwolnienie widoku. Testuje też monitor
akcji IPC, hotplug atrapy oraz soft/hard reload przy skanowaniu i edycji.
Raport zawiera CPU/RSS, liczniki odczytów, skanowania, discovery,
operacji sesji i drzewo procesów. `--idle` dodaje 60 s spoczynku świeżego
procesu przed cyklami; `--cycles 60` umożliwia zbadanie trendu pamięci.
Pomiary wykonuj po zatrzymaniu pozostałych testów i zmian źródeł.

`scripts/validate-visuals` zapisuje 16 PNG i manifest z dokładnymi komendami.
Rozmiar logiczny dzieli przez skalę, więc obrazy odpowiadają nominalnym
1920×1080 / 1366×768, z możliwą różnicą 1 px przez zaokrąglenie. Scenariusz
`validation` ma 30 workspace, 40 klientów traya i długie nazwy; pozostałe
obrazy obejmują oba zestawy akcentów, OSD, powiadomienie, Power i brak usługi.
Każdy obraz wymaga oceny wzrokowej. Offscreen nie zalicza odbioru Waylanda.

`tests/test_runtime.py` naprawdę uruchamia wszystkie skrypty integracyjne,
podgląd, pomiar i główny runner na kopii z celowo brakującym importem QML.
Wymaga niezerowego kodu i nazwy brakującego modułu, bez wtórnego
`JSONDecodeError`. `ipc_reply` pokazuje log źródłowej awarii także przy
nieudanym reloadzie, a `ipc_json` odrzuca niepoprawną odpowiedź zamiast
zamieniać ją w pusty stan. Odczyt logu przez `pread` nie przesuwa pozycji
zapisu procesu potomnego. Testy nadal klasyfikują znane diagnostyki celowych
awarii usług osobno; nie wyłączono ostrzeżeń QML. Główny runner kończy się
po błędzie Python/QtTest, drukuje log od razu i ma limit QtTest 180 s.

### Odbiór natywny w prywatnym Waylandzie

`scripts/test-wayland` uruchamia produkcyjne okna w zagnieżdżonym Hyprlandzie.
Ten test jest osobny od domyślnego `scripts/test`, ponieważ udostępnia
socket Waylanda rodzica i render node GPU. Użytkownik zatwierdził pełny
odbiór UI i konieczne powtórzenia do 10 minut na przebieg. Poprzednia
odmowa dotyczyła wcześniejszej, węższej zgody na sam start kompozytora;
[historia uprawnień](evidence/12-wayland-ui-approval.txt).
Wyniki i niewykonane kryteria zapisano w [raporcie](validation.md).

```sh
# Krótka weryfikacja okien i jednego rzeczywistego zrzutu; limit 45 s.
scripts/test-wayland --nested --smoke --output artifacts/wayland-smoke
# Pełny scenariusz automatyczny; limit 600 s na przebieg.
scripts/test-wayland --nested --idle --output artifacts/wayland
```

Runner daje kompozytorowi wyłącznie socket Waylanda rodzica i węzeł
renderujący. Własne XDG, D-Bus, `/dev`, `/run`, `/tmp`, sieć i PID-y są
odizolowane przez bubblewrap. Krótka ścieżka `XDG_RUNTIME_DIR=/tmp/pw-*/r`
zapobiega przekroczeniu limitu UNIX socket. Każde `hyprctl` ma jawną
prywatną sygnaturę; żadne polecenie IPC nie wybiera kompozytora hosta.

`wayland-validation.qml` składa produkcyjne okna i kontrolery, prawdziwe
monitory/akcje workspace oraz jawne atrapy sprzętu i sesji. Zajętość
30 workspace i 40 klientów traya jest syntetyczna. Osobny proces
`wayland-client-test.qml` przyjmuje tekst; `wtype` wysyła klawisze tylko
do prywatnego Waylanda. Zrzuty robi `grim -o HEADLESS-* -s <skala>`;
runner dopuszcza tylko prywatne wyjścia i zapis w katalogu testu.
Wymagany jest grim; ścieżkę można podać przez `PUTKIN_GRIM`.
W tym środowisku oficjalny pakiet 1.5.0-2 rozpakowano wyłącznie do `/tmp`,
po sprawdzeniu SHA-256 z lokalnej bazy Arch; [dowód](evidence/12-grim-package.json).
Runner kopiuje executable do prywatnego katalogu przed izolacją `/tmp`.

Kliknięcie poza panelem/toastem wysyła mały klient protokołu
`wlr-virtual-pointer`; runner kompiluje go w prywatnym katalogu przez
`wayland-scanner`, `cc` i `pkg-config wayland-client`. Definicja i licencja
są w [tests/protocols](../tests/protocols/README.md). Nie instaluje helpera
w systemie. Współrzędne i wejście dotyczą wyłącznie prywatnego kompozytora.
Pole tekstowe drugiego procesu i `Window.active` sprawdzają powrót wejścia.

Sprawdzenia obejmują pełną ścieżkę klawiaturą, obie barwy
i FileView, bierne OSD/toasty wobec osobnej aplikacji, ostatnią pozycję
traya i podmenu, osiem par rozdzielczość/skala, rezerwację 32 px,
mieszane skale, IPC na drugim monitorze, hotplug czterech rodzajów panelu,
20 cykli i soft/hard reload. Opcjonalny idle zapisuje przez 60 s CPU/RSS
shella i kompozytora bez IPC w trakcie pomiaru, przed startem klienta
wejścia i procesów przechwytywania. Sprzęt i operacje sesji pozostają atrapami.

Zmiany trybu monitora używają `hyprctl -r`, aby wymusić klatkę na bezczynnym
wyjściu headless. Tylko na czas macierzy runner ustawia
`debug:disable_scale_checks=true`: 1366×768 przy 1,25/1,5 daje niecałkowite
wymiary logiczne, a domyślny Hyprland 0.56.2 zastępuje te skale wartością 1.
Test nadal wymaga dokładnej skali/rozdzielczości w IPC. Zaokrąglenie
wymiaru logicznego xdg-output może zmienić rozmiar PNG grim o 1 px;
raport zapisuje rzeczywisty rozmiar i nie zalicza innego trybu monitora.
Konfiguracja hosta się nie zmienia.
Zrzuty pomijają banery startowe kompozytora przez prywatne `dismissnotify`;
pełna diagnostyka zostaje w logu, a błędy QML powodują FAIL.

Podczas natywnego przebiegu pozostaw okno kompozytora widoczne i nie zmieniaj
fokusu, workspace ani trybu pełnoekranowego. Fizyczne wejście rodzica może
trafić do zagnieżdżonego kompozytora i zakłócić scenariusz. Pierwotny klient
zrzutów Qt również czekał na klatki ukrytego wyjścia rodzica; zastąpiono go
bezpośrednim przechwytywaniem grim, bez pomocniczego okna Qt.

## Pulpit i Night Light — etap 11

```sh
scripts/check
scripts/test
scripts/test-desktop-integration --idle --output artifacts/desktop.json
scripts/preview --desktop --screenshot artifacts/night-light.png
scripts/preview --desktop --scenario nightLightAbsent --size 1366x768 --scale 1.25
scripts/preview --desktop --scenario nightLightDenied --size 320x220 --scale 2
```

`tests/qml/tst_desktop.qml`: 16 przypadków zachowania (18 wyników
z init/cleanup) — stan już aktywny bez zapisu, brak usługi, brak optymizmu
i podwójnej operacji, sześć rodzajów błędów, hjkl/Enter/strzałki,
granice temperatury, przejście między jasnością i DND, restart,
przewijanie na 320×220 i zwolnienie panelu. Tapeta: render lokalnego
SVG, zwolnienie obrazu, neutralny fallback, brak pobierania URL i
przepuszczanie kliknięć. Celowo brakujący obraz ma pojedyncze, dokładnie
dopasowane oczekiwane ostrzeżenie `QQuickImage`; błędy importów/ładowania
komponentów oraz wszystkie inne ostrzeżenia nadal powodują FAIL.

`tests/test_night_light.py`: osiem testów walidacji argumentów, wersji,
właściciela, jednostki, tokenu PID/starttime, ścieżki instancji i braku
backendu. Weryfikacja uruchamianych poleceń dotyczy wywołań wykonanych
przez adapter, nie szukania tekstu w jego źródłach.

`scripts/test-desktop-integration` uruchamia `desktop-test.qml`, prawdziwy
QML Process, produkcyjny pomocnik protokołu i `tests/night_light_peer.py`
na prywatnym sockecie. `tests/night_light_fixture.py` jawnie zastępuje
wyłącznie kontrolę tożsamości demona i wymaga znacznika prywatnego katalogu.
Nie ma testowego obejścia w kodzie produkcji. Osobny przypadek sprawdza,
że produkcja odrzuca atrapę **przed** wysłaniem `identity get`.

Test potwierdza odczyt/zapis i weryfikację, odpowiedzi dzielone na pakiety,
odmowę, zapis niepotwierdzony i spóźniony, timeout, błędną odpowiedź,
brak i restart demona, brak ponowienia starego zamiaru, miękki reload
bez uruchamiania drugiego demona, SIGKILL pomocnika oraz zakończenie jego
procesu potomnego podczas reloadu. Dwadzieścia cykli sprawdza niszczenie
widoków i RSS. Opcja `--idle` mierzy 60 s CPU/RSS i brak odpytywania.

Przykład Lua jest ładowany przez lokalny `Hyprland --verify-config`.
Konfiguracja kontrolna po usunięciu dołączenia sprawdza wcześniejszą
wartość ramki przez `hl.get_config`. Przykład hyprsunset jest czytany
z prywatnego XDG przez lokalny executable, z dodatnią i ujemną próbą
parsera. Brak Waylanda celowo kończy ten proces przed uruchomieniem
backendu; kod 1 jest tu oczekiwany i nie udaje testu sprawnego demona.

Przy testach prywatny system bus i adresy sprzętu pozostają niedostępne,
nie ma hostowego WAYLAND_DISPLAY. Testy socketów wymagają ich dopuszczenia
poza sandboxem; nie usuwamy izolacji. Natywny layer-shell tapety,
fizyczne monitory, CTM/gamma i integracja prawdziwej jednostki użytkownika
pozostają osobnym odbiorem. [Dowody](evidence/11-desktop.md).

## 1. Bramka składni i importów

```sh
scripts/check
scripts/check core components
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

`scripts/check` uruchamia dla **każdego** pliku QML `qmlformat` bez zapisu
oraz `qmllint --ignore-settings --max-warnings 0`. Nie traktuje formatowania
jako testu uruchomienia. Sprawdza cały projekt wraz z testami, z pominięciem
artefaktów/buildów. Przyjmuje też konkretne pliki/katalogi, w tym ścieżki ze
spacjami. Błędy obu narzędzi są zbierane; wadliwy plik nie przerywa kontroli
pozostałych. Wywołania nie korzystają z `find -exec` ani interpretacji shellowej.

W `BarWindow.qml`, `InteractivePanelWindow.qml`, `OsdWindow.qml` i `NotificationWindow.qml` jest lokalny wyjątek wyłącznie dla diagnostyki
`uncreatable-type` na deklaracji `PanelWindow`: metadane Quickshell 0.3.1
opisują abstrakcyjny interfejs, a fabryka platformy jest rejestrowana podczas
uruchomienia. Potwierdzono to w `panelinterface.hpp` tej wersji. Nie wyłączono
kontroli importów ani typów właściwości. Poprawność fabryki na Waylandzie
wciąż wymaga odbioru środowiskowego; zielony lint go nie zastępuje.

| Kod | Znaczenie |
| --- | --- |
| 0 | Wszystkie znalezione pliki przeszły oba narzędzia |
| 1 | Co najmniej jeden plik ma błąd składni/importów/typów lub ostrzeżenie lint |
| 2 | Brak executable, błąd wejścia, pusty zestaw plików albo timeout narzędzia |

`tests/test_check.py` tworzy próbki w nowym katalogu tymczasowym. Sześć testów
obejmuje poprawny plik ze spacją w nazwie i zachowanie jego zawartości,
błędną składnię, brakujący import, agregację dwóch błędów w trzech plikach,
brak każdego z narzędzi i puste/nieistniejące wejście. Źródła projektu nie
są modyfikowane.

## 2. Rzeczywiste wejście Qt Quick

```sh
scripts/test
```

Skrypt uruchamia regresje bramki, `qmltestrunner` na `tests/qml/`, natywny
test protokołu Hyprlanda oraz integracje paneli, ustawień, audio, jasności, baterii/traya, sieci, Bluetooth i powiadomień opisane niżej.
Test fundamentu tworzy **ten sam FoundationView i te same
kontrolki** co Quickshell, podaje jawny MockState i wysyła zdarzenia Qt:

- Spacja/kliknięcie zmieniają stan przycisku; wyłączona kontrolka nie emituje `clicked`.
- Tab pomija wyłączoną kontrolkę i przenosi fokus przycisk → ikona → suwak;
  Shift+Tab wraca. Wskaźnik fokusu podąża za aktywną kontrolką.
- Strzałki zmieniają poziom i zatrzymują go na 0/100. Reset aktualizuje stan,
  suwak i etykietę, zachowując wiązania.
- Kliknięcie toru suwaka zmienia model.
- Najechanie na ikonę otwiera rzeczywisty tooltip, odsunięcie zamyka go;
  nazwy dostępności ikony i suwaka są obecne.

Pięć testów zachowania + init/cleanup daje siedem wyników QtTest. Ostrzeżenia
QML powodują niepowodzenie, w tym błędy ładowania przed uruchomieniem testów.
To sprawdza udostępnienie nazw, nie pełny odbiór czytnikiem ekranu.

### Wymaganie dla dalszej implementacji: nawigacja vimowa

Ustalenie użytkownika z 2026-09-16 dodaje [kontrakt h/j/k/l + Enter](design.md#nawigacja-klawiaturą).
Testy etapu 00 weryfikują standardowe wejście Qt opisane powyżej;
etap 01 potwierdza `h`/`l` i Enter w pasku. W kolejnych powierzchniach
testuj rzeczywistymi zdarzeniami klawiatury:

- h/l w rzędzie oraz j/k w kolumnie/listach, z pomijaniem wyłączonych elementów;
- widoczny fokus i dostęp do elementów poza widocznym obszarem;
- Enter i Enter numeryczny: jedna aktywacja wybranej pozycji;
- h/l na suwaku: zmiana o krok i respektowanie granic;
- wpisywanie h/j/k/l w polu tekstowym bez utraty fokusu;
- brak reakcji Putkin na te klawisze, gdy klawiaturę obsługuje inna aplikacja.

## 3. Izolacja

Narzędzia uruchomieniowe korzystają z `scripts/_common.py`:

- unikalne `/tmp/pk-*` oraz własne XDG_CONFIG_HOME, XDG_CACHE_HOME,
  XDG_DATA_HOME, XDG_STATE_HOME i XDG_RUNTIME_DIR (0700);
- prywatne katalogi wyszukiwania XDG_CONFIG_DIRS i XDG_DATA_DIRS;
- nowy session bus przez `dbus-run-session`, bez dziedziczenia hostowego adresu;
- niedostępny adres system bus, PipeWire i PulseAudio; bez hostowego
  DISPLAY, WAYLAND_DISPLAY, HYPRLAND_INSTANCE_SIGNATURE i ścieżek importów;
- jawny renderer offscreen/software, basic render loop, skala 1, locale C.UTF-8;
- zakończenie własnej grupy procesów i usunięcie tymczasowych danych.

Graf podglądu importuje Qt i podstawowy moduł Quickshell (pasek również Io
dla własnego IPC); **nie uruchamia natywnego adaptera Hyprlanda,
PAM, powiadomień, sprzętu ani adapterów sesji**. Prywatny D-Bus nie jest
izolacją urządzeń ani PAM — bezpieczeństwo tych testów wynika także z
braku takich integracji. Przy dodawaniu usług zachowaj osobny `preview.qml`.

W sandboxie tej sesji tworzenie socketów było zabronione. `dbus-run-session`
zwrócił `Operation not permitted`, a skrypty poprawnie zwróciły błąd.
Właściwe testy uruchomiono po dopuszczeniu lokalnych socketów poza sandboxem,
z zachowaniem opisanej izolacji. Nie należy usuwać izolacji, żeby ominąć błąd.

## 4. Renderer offscreen i zrzut

```sh
scripts/preview
scripts/preview --screenshot docs/evidence/00-foundation.png
scripts/preview --bar --size 1920x1080 --screenshot docs/evidence/01-bar-1920.png
scripts/preview --bar --size 1366x768 --scenario overflow --screenshot docs/evidence/01-bar-1366.png
```

Skrypt wymaga udanego startu, zapisanego **nowego** PNG i żywego procesu przez
zadany czas. Log znajduje się obok obrazu. Jedyne dopuszczone ostrzeżenie
platformy, z dokładnym dopasowaniem treści, to
`This plugin does not support setting window masks`. Pozostaje widoczne
w logu; żadne inne ostrzeżenia nie są wyciszane. Wynika z użycia okna
Quickshell na platformie offscreen. QtTest nie korzysta z tego wyjątku.

Zrzut 720×440 jest pobierany z wyrenderowanego Item przez `grabToImage`, po
aktywacji własnego okna i ustawieniu fokusu klawiatury. Pozwala ocenić kolory,
ostre rogi i obrys fokusu. Nie jest zrzutem monitora ani dowodem poprawności
layer-shell, rezerwacji miejsca, zarządzania monitorem czy fokusu Hyprlanda.

## 5. Prywatny compositor — osobny odbiór Wayland

W tej sesji **nie wykonano** tego odbioru. Weston nie jest zainstalowany;
do ukończonych testów offscreen nie trzeba doinstalowywać kompozytora.
Poniższy przepis służy do uruchomienia demonstracyjnego `FloatingWindow`
na maszynie z Westonem. Najpierw potwierdź `weston --version` i flagi
`weston --help`. Backend `headless` i renderer `pixman` opisuje
[oficjalna dokumentacja Westona](https://wayland.pages.freedesktop.org/weston/toc/running-weston.html).
Ten tryb nie korzysta z hostowego monitora ani wejścia sprzętowego.

Z katalogu projektu, po zapewnieniu Westona:

```sh
python3 - <<'PY'
import pathlib
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(pathlib.Path('scripts').resolve()))
from _common import ROOT, isolated_environment, stop_process_group, tool

weston, dbus, quickshell = tool('weston'), tool('dbus-run-session'), tool('quickshell')
with tempfile.TemporaryDirectory(prefix='pk-') as directory:
    env = isolated_environment(directory)
    compositor = subprocess.Popen([
        weston, '--backend=headless', '--renderer=pixman',
        '--shell=kiosk-shell.so', '--no-config', '--idle-time=0',
        '--socket=putkin-test', '--width=1280', '--height=720',
    ], env=env, start_new_session=True)
    session = None
    try:
        socket = pathlib.Path(env['XDG_RUNTIME_DIR']) / 'putkin-test'
        deadline = time.monotonic() + 10
        while not socket.is_socket():
            if compositor.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError('Prywatny compositor nie wystartował')
            time.sleep(0.05)
        env.update(QT_QPA_PLATFORM='wayland', WAYLAND_DISPLAY='putkin-test')
        session = subprocess.Popen([
            dbus, '--', quickshell, '--no-color', '--path', str(ROOT / 'preview.qml'),
        ], env=env, start_new_session=True)
        try:
            session.wait(timeout=10)
            raise RuntimeError('Podgląd zakończył się przed odbiorem; sprawdź log')
        except subprocess.TimeoutExpired:
            print('10 s pracy okna Wayland; oceń log przed oznaczeniem PASS')
    finally:
        if session is not None:
            stop_process_group(session)
        stop_process_group(compositor)
PY
```

To przepis dla zwykłego okna Wayland, nie test paska layer-shell. Odbiór
`PanelWindow` w etapie 01 wymaga kompozytora obsługującego właściwy protokół,
np. odizolowanego Hyprlanda, kontroli rezerwowanej przestrzeni i fokusu.
Zwykłego klienta testowego nie kieruj na socket aktywnego pulpitu.
Osobny runner natywny opisany na początku dokumentu, po wyraźnej zgodzie,
udostępnia ten socket wyłącznie jako backend zagnieżdżonego kompozytora;
Putkin i klienci wejścia/zrzutów używają wyłącznie jego prywatnego socketa.

W etapie 01 sprawdzono także start Hyprlanda 0.56.2 wewnątrz bubblewrap:
`--unshare-all --ro-bind / / --dev /dev --proc /proc --tmpfs /run --tmpfs /tmp`,
z ponownie udostępnionym wyłącznie własnym katalogiem `/tmp/pk-*`, prywatnym
XDG/D-Bus, tymczasową konfiguracją bez `exec` i limitem 12 s. Start zakończył
się kodem 134 / `CBackend::create() failed!`. Nie udostępniono hostowych
urządzeń ani magistral. [Log](evidence/01-wayland-attempt.log).
Aquamarine 0.15.0 wymaga alokatora DRM również przy backendzie headless;
potwierdzono w [źródle wersji](https://github.com/hyprwm/aquamarine/blob/v0.15.0/src/backend/Backend.cpp).
`/dev/dri` jest niewidoczny w sandboxie. Późniejszy odbiór etapu 12
potwierdził węzeł renderujący poza nim i użył go po zgodzie użytkownika.

## 6. Bazowy pomiar spoczynku

```sh
scripts/measure-idle
scripts/measure-idle --output docs/evidence/00-idle-60s.json
scripts/measure-idle --bar --output docs/evidence/01-idle-60s.json
```

Skrypt rozpoczyna nowy podgląd bez zrzutu, czeka 2 s na start i mierzy 60 s
bez interakcji. Co 1 s czyta `/proc` **z zewnętrznego procesu pomiarowego**;
sam shell nie odpytuje niczego okresowo. Raport JSON zawiera 61 próbek,
RSS shella, CPU oraz drzewa procesów na początku/końcu. Procesy narzędzi
testowych i prywatnego D-Bus są rozróżnione od shella i jego dzieci.

CPU = przyrost `(utime + stime) / CLK_TCK / czas × 100%`, względem jednego
rdzenia, bez dzielenia przez liczbę CPU. RSS pochodzi z liczby rezydentnych
stron procesu i jest podawany w KiB. Licznik CPU ma tutaj rozdzielczość 10 ms;
wynik 0 oznacza brak zarejestrowanego przyrostu, nie dowód absolutnie zerowej
pracy. Pomiar nie obejmuje startu, renderowania na GPU ani rzeczywistego Waylanda.

Po nowych stale działających usługach i w etapie 12 wykonaj osobny pomiar
w porównywalnych warunkach. Wynik 00 opisuje fundament. Wynik 01 obejmuje
większą powierzchnię, 30 workspace i działający zegar minutowy na atrapach,
bez realnego Waylanda i natywnego adaptera Hyprlanda.

## 7. Zachowanie paska i natywny adapter

`tests/qml/tst_bar.qml` używa tych samych `BarView`, przycisków, zegara,
`WorkspaceService` i `BarFocus` co produkcja, z jawnym `MockHyprland`.
11 testów zachowania sprawdza globalne numery 1–5/9/12, dwie różne aktywne
przestrzenie, pilność i zajętość, kliknięcie z właściwym monitorem,
`h`/`l` do numeru 30, Enter/Enter numeryczny, Escape, obrys fokusu,
przewijanie przyciskami, stabilność delegata, timeout i odłączenie monitora,
brak reakcji paska podczas wpisywania `hjkl` w polu oraz locale/tooltip daty.
Geometria jest sprawdzana dla szerokości 1920, 1366, 600 i 320 px.
Łącznie z fundamentem i init/cleanup daje to **20 wyników QtTest**.

```sh
scripts/test                  # cały zestaw, również test natywny
scripts/test-bar-integration  # tylko natywny adapter + IPC
```

Test natywny startuje Quickshell z `bar-test.qml`, osobnym adresem
`HYPRLAND_INSTANCE_SIGNATURE` i parą prawdziwych lokalnych socketów w
prywatnym `XDG_RUNTIME_DIR`. `tests/hyprland_protocol.py` emuluje mały
fragment protokołu; **produkcyjny** `Quickshell.Hyprland` parsuje dane
i zdarzenia. Sprawdzane są: zajętość z okien, urgency, dispatchery i kolejność
potwierdzeń, rzeczywiste wywołania `bar focus/close`, dodanie/usunięcie
monitora, stałe dwa połączenia event socket i utrata danych po EOF.
Obie ścieżki (`configProvider = hyprlang/lua`) mają osobne procesy.

Nie ma rzeczywistego `wl_display` ani mapowania toplevel Waylanda. Te dwie
konkretne diagnostyki oraz `PeerClosedError` celowo zrywanego socketa są
sprawdzane jako oczekiwane i drukowane w logach. Inne ostrzeżenia lub błędy
powodują FAIL. Test nie stanowi odbioru layer-shell, fizycznych monitorów,
rezerwacji obszaru ani fokusu kompozytora.

## 8. Panele, fokus i zasoby

```sh
scripts/test
scripts/test-panels-integration --output artifacts/panels-cycles.json
scripts/preview --panels --size 1920x1080 --screenshot artifacts/quick-settings.png
scripts/preview --panels --size 1366x768 --scenario settings --screenshot artifacts/settings.png
scripts/preview --panels --size 320x220 --scenario settings --screenshot artifacts/settings-small.png
scripts/measure-idle --panels --output artifacts/panels-idle.json
```

`tests/qml/tst_panels.qml` ładuje prawdziwy `PanelCoordinator`, `PanelHost`,
`BarView`, `PanelSurface` i obie strony. Dziesięć testów zachowania oraz
init/cleanup daje 12 wyników; razem z poprzednimi etapami **32 wyniki QtTest**.
Testy wysyłają rzeczywiste kliknięcia i klawisze, sprawdzając:

- h/j/k/l, strzałki, Tab/Shift+Tab, Spację, Enter i Enter numeryczny;
  pomijanie niedostępnych kontrolek i wpisywanie `hjkl` w polu;
- rzeczywisty tooltip, wypełnienie aktywnego przycisku, obrys fokusu,
  otwarcie myszą, wejście z końca listy workspace i powrót na przycisk;
- lokalne rozwinięcie opisu, dwa poziomy Escape, zastępowanie stron,
  odrzucanie nieznanej powierzchni bez uszkodzenia istniejącej sesji;
- 20 cykli, ponowne otwarcie w trakcie fade, zamknięcie przed końcem
  ładowania, wyłączenie wejścia od razu i zniszczenie wszystkich widoków;
- zmianę i usunięcie monitora na atrapach, wybór/fallback monitora;
- 320×220, szerokości 320/600/1366/1920, długi tekst i zmianę rozmiaru
  otwartego panelu z przewinięciem do aktywnej kontrolki.

QtTest otrzymuje jawny adapter `QtQuick.Loader`: w tej instalacji plugin
Quickshell nie ładuje się poza jego executable. `PanelHost` nie importuje
Quickshella, a źródła ani importy nie są przepisywane. Jawną atrapą natywnego
graba jest `MouseArea` testowej sceny; test pochłonięcia kliknięcia dotyczy
tej sceny, nie zachowania kompozytora. [Polityka produkcyjna](panels.md).

`scripts/test-panels-integration` używa **rzeczywistego Quickshella,
LazyLoadera i wywołań IPC** do produkcyjnego `PanelIpc`. Entry point
`panels-test.qml` ma wyłącznie testowy handler `probe`. Po każdym z 20 cykli
sprawdza brak aktywnego widoku, liczbę utworzonych/zniszczonych powierzchni
i RSS z `/proc`. Sprawdza też fokus po IPC, przełączenie strony/monitora,
hotplug na atrapach, brak ekranu i szybkie ponowne otwarcie w tej samej
iteracji. Raport i pełny log są zapisywane pod wskazaną ścieżką.

Pomiar `--panels` obejmuje 30 workspace, zegar minutowy i niezaładowany
host paneli przez 60 s. Są to te same warunki offscreen co pomiar etapu 01.
Prywatne procesy/XDG/D-Bus są sprzątane. Natywne `PanelWindow`,
`HyprlandFocusGrab`, tooltip `Popup.Window`, maska wejścia i fokus innej
aplikacji wymagają oddzielnego odbioru na Waylandzie. Testy atrap ani
zwykłego okna offscreen nie spełniają tych kryteriów.


## 9. Wygląd i trwałość ustawień — etap 03

```sh
scripts/check
scripts/test
scripts/test-settings-integration --output docs/evidence/03-settings.json
scripts/preview --panels --scenario settings --size 1366x768 --screenshot docs/evidence/03-appearance-mauve.png
scripts/preview --panels --scenario settings --size 1366x768 --accent '#94e2d5' --secondary '#fab387' --screenshot docs/evidence/03-appearance-teal.png
scripts/measure-idle --panels --output docs/evidence/03-idle-60s.json
```

`tests/qml/tst_settings.qml` wykonuje 35 wyników QtTest (w tym init/cleanup
oraz wiersze danych): rzeczywiste klawisze i kliknięcia, sześć presetów dla
obu akcentów, błędne HEX, wpisywanie `hjkl`, Enter/Enter numeryczny,
Spację i pomijanie niedostępnego zapisu. Sprawdza dynamiczne tokeny w dwóch
paskach i istniejącym suwaku, kontrast czerni/bieli, stałe role stanów,
ograniczenie ruchu, reset, opóźnione potwierdzenie i ponowienie po błędzie.
Dziesięć ścieżek zamknięcia odrzuca podgląd, w tym zamknięcie przed
załadowaniem strony. Dwadzieścia zmian zachowuje obiekty panelu/pola,
fokus, tekst i pozycję kursora. Testy paneli nadal sprawdzają przewijanie
320×220 i długą zawartość.

`scripts/test-settings-integration` jest częścią `scripts/test`. Używa
produkcyjnego Settings/FileView w prawdziwym Quickshellu, na prywatnych
XDG i D-Bus, bez adaptera pulpitu i sprzętu. Bada plik, jego treść,
mtime/inode, sygnały `saved`/`saveFailed`, stan UI i fokus przez testowe IPC:

- brak pliku i całego katalogu aplikacji, podgląd bez zapisu, utworzenie
  katalogów, atomowy zapis, własne zdarzenia watch oraz zapis bez zmian;
- rzeczywisty restart, reset z anulowaniem oraz jawny zapis resetu;
- 20 zewnętrznych zmian (in-place i atomowych) z reloadami, konflikt,
  brak nadpisania, niezmienione fokus/kursor i licznik utworzonych paneli;
- wstępny odczyt wykrywający konflikt nawet przy wyłączonym watcherze,
  anulowanie jeszcze nie rozpoczętego zapisu przez zamknięcie;
- uszkodzony JSON, nowszy schemat, błędny kolor, zachowanie ostatniego
  poprawnego stanu, naprawę zewnętrzną i uszkodzony plik przy starcie;
- realne chmod(0444) pliku, chmod(0500) rodzica przed pierwszym zapisem
  i chmod(000) dla błędu odczytu; brak utraty pliku i skuteczne ponowienia;
- usunięcie/odtworzenie pliku i zewnętrzne utworzenie katalogu aplikacji;
- miękki i twardy reload Quickshella, hotplug atrapy, brak pętli odczytu/zapisu.

Test uprawnień wymaga zwykłego użytkownika, odrzuca uruchomienie jako root.
Niepoprawne importy i ostrzeżenia QML nadal powodują FAIL. Wyjątki to znana
maska offscreen i **dokładnie** `inotify_add_watch(<prywatny plik>) failed:
(Permission denied)` podczas wymuszonego braku dostępu. Diagnostyki zostają
w logu i w raporcie, bez globalnego filtrowania kategorii.

Offscreen potwierdza logikę monitorów i reaktywność widoków. Natywne
warstwy Waylanda, kliknięcie poza panelem przez HyprlandFocusGrab, rzeczywisty
hotplug, przekazanie fokusu innej aplikacji i mieszane skale nadal wymagają
odbioru środowiskowego. Schemat i ograniczenia równoczesnego zapisu:
[settings.md](settings.md).

## 10. Audio, prywatny PipeWire i OSD — etap 04

```sh
scripts/check
scripts/test
scripts/test-audio-integration --idle --output docs/evidence/04-audio.json
scripts/preview --audio --size 1920x1080 --screenshot docs/evidence/04-audio-1920.png
scripts/preview --audio --size 1366x768 --scenario osd --screenshot docs/evidence/04-osd-1366.png
scripts/preview --audio --size 320x220 --screenshot docs/evidence/04-audio-small.png
scripts/preview --audio --scenario audioUnavailable --screenshot docs/evidence/04-audio-unavailable.png
```

`--audio` włącza podgląd paneli z `MockAudioBackend`. QtTest również używa
tej atrapy przez produkcyjny `AudioService`. `tst_audio.qml` sprawdza
zdarzeniami Qt suwak, serie strzałek przy opóźnionym backendzie, h/j/k/l,
Enter/Enter numeryczny, Spację, Tab, kółko paska i powrót fokusu. Weryfikuje
wspólność paska/panelu/OSD, odrzucanie błędnych wartości, 0/100%, mute,
zewnętrzne 135%, opóźnienie, odmowę i timeout, rzeczywisty i preferowany
wybór, brak wyjścia, restart na atrapach i stabilność delegata przy 20 zmianach.
Sprawdza też 320×220, przewijanie do fokusu i pomijanie wyłączonych kontrolek.

OSD: brak komunikatu przy starcie/powrocie usługi, właściwy monitor/fallback,
odnowienie timeoutu, brak zmiany aktywnej kontrolki, reakcja na Theme.accent,
ukrycie przez panel/hotplug i zniszczenie loadera. Są to **18 wyników QtTest**
z init/cleanup i wierszami danych; z poprzednimi etapami **85 wyników**.

`scripts/test-audio-integration` używa `audio-test.qml`, produkcyjnych
`PipewireBackend`, trackera, `AudioService`, `AudioIpc` oraz prawdziwego
`LazyLoader`. Serwer PipeWire ma własny runtime i dokładny plik
`tests/pipewire.conf`: dwa `support.null-audio-sink`, natywny protokół,
metadane i fabrykę adapterów. **Nie ładuje ALSA, BlueZ, portalu, RTKit,
PulseAudio, WirePlumber ani żadnego wykrywania urządzeń.** Wszystkie
wywołania `pw-cli`/`pw-metadata` należą do testu i łączą się tylko z tym
serwerem. Podgląd ani produkcja nie używają tych komend do odczytu audio.

Test zaczyna bez serwera, sprawdza jego późniejszy start, brak domyślnego
sinka, odczyt trackera, poziom/mute, 0/100%, serię komend, zewnętrzne Props,
brak OSD w panelu, preferencję bez zmiany rzeczywistego wyjścia i jej timeout.
Symuluje decyzję menedżera polityki przez metadane, usuwa sink, zatrzymuje
i restartuje prywatny serwer, wykonuje soft/hard reload Quickshella.
Po 20 cyklach OSD sprawdza zrównanie liczby utworzonych/zniszczonych widoków
oraz zapisuje RSS. Nie ma polityki WirePlumber ani fizycznej karty dźwiękowej.

Dwa spodziewane komunikaty biblioteki, dopasowane **dokładnie**, muszą
wystąpić po jednym razie i pozostają w logu/raporcie:

```text
ERROR quickshell.service.pipewire.loop: Failed to connect pipewire context. Errno: 112
WARN quickshell.service.pipewire.loop: Pipewire error on object 0 with code -32 connection error
```

Odpowiadają celowemu brakowi serwera przy starcie oraz jego zatrzymaniu.
Test wymaga poprawnych przejść stanu i powrotu po obu błędach. Inne
diagnostyki QML/importów powodują FAIL; obowiązuje wcześniejszy dokładny
wyjątek maski offscreen. Log prywatnego demona musi być pusty.

`--idle` po tych testach uruchamia **świeży** proces Quickshell i mierzy
60 s po 2 s rozgrzewki: 1920×1080, offscreen/software, skala 1, 30 workspace,
zegar minutowy, panel i OSD niezaładowane, natywny adapter połączony
z prywatnym PipeWire. To warunki bazowego panelu z dodatkową usługą audio.
RSS/CPU shella i osobny proces testowego serwera są raportowane oddzielnie.

Pełny odbiór wymaga jeszcze natywnego `OsdWindow` na Waylandzie: braku
fokusu/rezerwacji miejsca, przepuszczania kliknięć, rzeczywistych monitorów,
skal oraz fizycznego audio z menedżerem polityki. Test offscreen tego nie
zastępuje. Prywatne środowisko i wszystkie własne procesy są sprzątane.

## 11. Jasność i wspólny OSD — etap 05

```sh
scripts/check
scripts/test
scripts/test-brightness-integration --idle --output docs/evidence/05-brightness.json
scripts/preview --brightness --size 1920x1080 --screenshot docs/evidence/05-brightness-1920.png
scripts/preview --brightness --scenario brightnessOsd --secondary '#94e2d5' --size 1366x768 --screenshot docs/evidence/05-osd-1366.png
scripts/preview --brightness --scenario brightnessFocus --size 320x220 --screenshot docs/evidence/05-brightness-small.png
scripts/preview --brightness --scenario brightnessUnavailable --size 1366x768 --screenshot docs/evidence/05-brightness-unavailable.png
scripts/preview --brightness --scenario brightnessDenied --size 1366x768 --screenshot docs/evidence/05-brightness-denied.png
```

`--brightness` dodaje jasność i audio na jawnych atrapach. QtTest używa
produkcyjnego `BrightnessService`, parsera, widoku i wspólnego OSD.
`tst_brightness.qml` daje **26 wyników**, łącznie z poprzednimi etapami
**111**. Weryfikuje:

- zastane 0, brak urządzenia, zerowe/nieznane max, wartość poza zakresem,
  niebezpieczną nazwę, granice 1/100, mały zakres 0–7 i brak zapisu zera;
- deterministyczny wybór, zachowanie wybranego urządzenia i jego zniknięcie;
- odmowę uprawnień, timeout, zapis bez zmiany stanu, błąd odczytu,
  poprawne ponowienie oraz brak fałszywego procentu i OSD sukcesu;
- serię 71 żądań z dwoma zapisami, końcową wartość, stare odpowiedzi
  dostarczone w odwrotnej kolejności i odczyt sprzed nowszego żądania;
- ponowne otwarcie także podczas fade, zewnętrzną zmianę i brak pollingu;
- prawdziwe h/j/k/l, Enter/Enter numeryczny, strzałki, Tab/Backtab, Spację,
  przeciągnięcie myszą, końcowy poziom, fokus po utracie urządzenia i 320×220;
- zmianę audio → jasność w tym samym OSD, kolor, monitor/fallback,
  timeout, brak przejęcia fokusu i tłumienie przez Quick Settings.

`scripts/test-brightness-integration` jest częścią `scripts/test`. Uruchamia
`brightness-test.qml` w rzeczywistym Quickshellu: produkcyjny `Process`,
adapter, parser, model, IPC i `LazyLoader`. Atrapa `tests/brightnessctl_fake.py`
jawnie zastępuje **wyłącznie executable** i operuje na prywatnym JSON w
`/tmp/pk-*`, z wymaganym plikiem znacznika. Entry point bez wskazania atrapy
używa nieistniejącej ścieżki, nigdy hostowego brightnessctl. Nie czyta sysfs
ani nie dotyka urządzeń. Prywatny D-Bus sam w sobie tego nie gwarantuje.

Integracja sprawdza listy argumentów (także ścieżkę executable ze spacją),
odczyt po zapisie, kolejkę, status/IPC, ponowne otwarcie panelu, brak live,
odmowę, niepotwierdzony zapis, błędny format, zerowy zakres, brak urządzenia,
zastane 0, awarię procesu i timeout. Atrapa timeout ignoruje SIGTERM, więc
test wymaga SIGKILL i zniknięcia PID-u. Brak executable sprawdza rzeczywiste
`FailedToStart`; soft/hard reload kończy czekające dziecko. Dwadzieścia
cykli OSD sprawdza tworzenie/niszczenie i RSS; wszystkie PID-y są kontrolowane
po zakończeniu. Audio w tej integracji jest atrapą; pełny zestaw zachowuje
osobny test prawdziwego PipeWire.

Jedyna dodatkowa oczekiwana diagnostyka to dokładna linia
`Process failed to start…` zawierająca konkretną prywatną ścieżkę brakującego
executable i argumenty listy. Musi wystąpić raz i zostaje w logu/JSON.
Nie wyciszono importów ani kategorii logowania. Obowiązuje wcześniejszy
dokładny wyjątek masek offscreen.

`--idle` po integracji uruchamia świeży proces, czeka 2 s i mierzy 60 s:
1920×1080, 30 workspace, zegar minutowy, skala 1, offscreen/software,
zamknięty panel/OSD, prawdziwy adapter Process po zakończonym odczycie.
Raport sprawdza również **0 nowych komend brightnessctl**. Audio i monitory
są atrapami, dlatego wartości RSS nie są bezpośrednim porównaniem z pomiarem
04 z natywnym PipeWire.

Podczas pierwszej pełnej regresji test audio przegapił widoczność OSD
w 100-ms oknie, choć liczniki potwierdziły utworzenie i zniszczenie.
Timeout cykli integracji audio/jasności wynosi teraz 400 ms, co pozwala
na rundy IPC także przy obciążeniu. Nadal wymagane są oba stany loadera
i rzeczywiste wygaśnięcie; produkcyjny timeout pozostaje 1500 ms.
Kontrola zasobów czeka również na `Component.onDestruction`: loader może
stać się nieaktywny o jedną iterację zdarzeń przed usunięciem obiektu.
Zakończenie cyklu wymaga zrównania obu liczników, nie samego `active=false`.

Nie wykonano testów fizycznego backlight, uprawnień/logind hosta,
klawiszy firmware, rzeczywistych monitorów, wejścia/fokusu warstw Waylanda
ani mieszanych skal. [Kontrakt backendu i ograniczenia](brightness.md).


## 12. Bateria, SNI i DBusMenu — etap 06

```sh
scripts/check
scripts/test
scripts/test-status-integration --idle --output docs/evidence/06-status.json
scripts/preview --status --size 1920x1080 --screenshot docs/evidence/06-status-1920.png
scripts/preview --status --scenario batteryLow --size 1366x768 --accent '#94e2d5' --screenshot docs/evidence/06-battery-low.png
scripts/preview --status --scenario trayMenu --size 1366x768 --scale 1.25 --screenshot docs/evidence/06-tray-menu.png
scripts/preview --status --scenario trayOverflow --size 320x220 --scale 2 --screenshot docs/evidence/06-tray-small.png
scripts/preview --status --scenario batteryAbsent --size 1366x768 --screenshot docs/evidence/06-battery-absent.png
scripts/preview --status --scenario batteryCharging --size 1366x768 --scale 1.5 --screenshot docs/evidence/06-battery-charging.png
```

`tests/qml/tst_status.qml` używa produkcyjnych modeli/widoków oraz jawnych
MockBatteryBackend/MockTray. **21 wyników** obejmuje stany baterii,
peryferia, niedostępność/powrót, błędne dane, 0%, czas backendu i stałe
kolory ostrzeżeń. Rzeczywiste kliknięcia/klawisze sprawdzają aktywację,
środkowy/prawy klik, Shift+Enter, Menu/Shift+F10, h/j/k/l, Enter numeryczny,
strzałki, Tab/Backtab, dostępność i tooltip.

Dalsze przypadki obejmują menu i podmenu, pomijanie separatorów i pozycji
wyłączonych, wyłączone wejście do brakującego menu, zastąpienie ustawień
z anulowaniem edycji, usunięcie pozycji/menu/monitora, odzyskiwanie fokusu
oraz zachowanie fokusu nagłówka przy aktualizacji danych. Overflow ma
16 klientów i przewija się do ostatniego przy 320×220. Geometria jest
sprawdzana przy szerokościach 320/480/600/683/960/1366/1920.

`scripts/test-status-integration` uruchamia prawdziwy Quickshell,
UPowerBackend, SystemTray, QsMenuOpener i LazyLoader z `status-test.qml`.
Atrapa `tests/status_dbus_fake.py` wymaga pliku znacznika w `/tmp/pk-*`
i zgodnego adresu socketu. **Oba adresy D-Bus wskazują prywatny serwer**:
UPower nie trafia na magistralę systemową hosta. Atrapa eksportuje
DisplayDevice, mysz z baterią 3%, 16 klientów SNI na osobnych połączeniach
i DBusMenu z podmenu. Python-dbus/GLib są zależnościami tylko testów.

Integracja sprawdza natywne skalowanie procentu, PropertiesChanged,
ładowanie/rozładowanie/full/unknown/absent, filtr peryferiów, zanik i powrót
UPower oraz świeży start bez tej usługi. Przechodzi także ścieżkę awaryjną
rzeczywistych gdbus/busctl: zdarzeniowe odczyty JSON i powrót bez restartu.
Dla SNI sprawdza Activate/SecondaryActivate, a dla DBusMenu root
AboutToShow/GetLayout, opened/closed podmenu, clicked, ukryte/wyłączone
pozycje, checkbox/separator i zmianę układu podczas otwartego podmenu.

Usunięcie klienta następuje przez rozłączenie jego D-Bus, nie przez zmianę
listy w QML. Test wymaga odzyskania fokusu w pasku/overflow i zamknięcia
menu znikającej aplikacji. Zmiana tytułu zachowuje fokus; Passive pomija
pozycję. Klienci rejestrują się ponownie po zmianie właściciela watchera.
Dwadzieścia cykli wymaga zrównania liczników powierzchni i natywnych zdarzeń
opened/closed dla korzenia oraz podmenu. Soft/hard reload musi zmienić
generację konfiguracji, odtworzyć dane i zakończyć poprzedni gdbus.
Po teście kontrolowane są PID-y shella, jego obserwatorów, atrapy i D-Bus.

Spodziewane diagnostyki pozostają w logu i raporcie: dokładne dwa komunikaty
nieudanego startu nieistniejącej usługi UPower oraz jedno ostrzeżenie
natywnego providera o braku pixmapy klienta. Ten ostatni ma dokładny
wzorzec z adresem obiektu; wymagane jest jedno wystąpienie. Pozostałe
ostrzeżenia/błędy powodują FAIL. Nie wyłączono kategorii ani importów.
Obowiązuje wcześniejszy wyjątek maski okna offscreen.

Pomiar `--idle` uruchamia świeży proces po integracji: 1920×1080,
offscreen/software, skala 1, 30 workspace, zegar minutowy, zamknięty panel,
natywne UPower/tray i zarejestrowani klienci. Po 2 s rozgrzewki mierzy 60 s
RSS/ticków CPU oraz sprawdza 0 nowych odczytów baterii. Obserwator gdbus
jest jedynym stałym dzieckiem shella i ma osobny pomiar; atrapa/D-Bus
należą do narzędzi testowych. Audio/jasność w tym pomiarze są wyłączone.

Podglądy obejmują skale 1 / 1.25 / 1.5 / 2, ale nie zastępują testów
fizycznych monitorów z mieszanymi skalami. Wayland, natywne tooltipy,
HyprlandFocusGrab, fokus innej aplikacji, rzeczywista bateria i zestaw
aplikacji traya pozostają do osobnego odbioru środowiskowego.


## 13. Sieć i Wi-Fi — etap 07

```sh
scripts/check
scripts/test
scripts/test-network-integration --idle --output docs/evidence/07-network.json
scripts/preview --network --scenario networkPassword --size 1366x768 --screenshot artifacts/wifi-password.png
scripts/preview --network --scenario networkBlocked --screenshot artifacts/wifi-rfkill.png
scripts/preview --network --scenario networkPassword --size 320x220 --scale 2 --screenshot artifacts/wifi-small.png
```

`tests/qml/tst_network.qml` sprawdza ten sam NetworkService i UI co produkcja,
bez importu natywnego Networking. Atrapy zachowują obiekty urządzeń/sieci.
27 wyników obejmuje stany internetu, Ethernet+Wi-Fi, brak NM/adaptera,
rfkill, radio bez potwierdzenia i timeout, współwłasność skanowania,
11 sposobów zakończenia listy/operacji, rzeczywiste klawisze hjkl/Enter,
litery w maskowanym polu, błędny PSK, stare operacje, stabilność delegatów,
nietypowy SSID i duplikat na drugim urządzeniu, puste listy, edytor,
przewijanie małego panelu oraz 20 cykli.

`scripts/test-network-integration` jest częścią `scripts/test`. Wrapper
uruchamia native Quickshell.Networking i produkcyjny NetworkBackend na
prywatnej atrapie D-Bus (`tests/network_dbus_fake.py`). `network-test.qml`
ma wyłącznie testowy handler probe; testowe hasło powstaje w tym procesie,
nie jest argumentem IPC. Fałszywe Update rejestruje PID nadawcy bez sekretu,
co weryfikuje natywną ścieżkę Quickshell → NM. Test obejmuje:

- natywne modele, GetAll/GetAllDevices/AP, grupowanie duplikatów, sygnały
  zmiany siły, zapisane ActivateConnection i otwarte AddAndActivateConnection;
- NoSecrets, błędny/poprawny PSK przez natywny Update, puste pole po operacji,
  kontrolę braku sekretów w tymczasowych plikach/logach/XDG i argv;
- osobny stan internetu/portal, Ethernet+Wi-Fi i jawne CheckConnectivity;
- radio, odmowę Set, brak potwierdzenia, ponowienie, rfkill, usunięcie adaptera;
- anulowanie, zmianę celu, timeout, 20 rzeczywistych LazyLoaderów,
  zniszczenie widoków i skanowania, zwolnienie obserwatorów przy reloadzie;
- brak/zniknięcie/powrót NM, ochronę przed starym singletonem, miękki reload
  i jawny komunikat wymagający restartu procesu po twardym reloadzie;
- brak opcjonalnego edytora i uruchomienie wyłącznie jego testowego executable;
- opcjonalne 60 s spoczynku w świeżym procesie: CPU/RSS/drzewo procesów,
  brak nowych odczytów i RequestScan, a po zakończeniu kontrolę PID-ów.

Każde ostrzeżenie/import powoduje FAIL poza dokładnie dopasowaną maską
offscreen i oczekiwanym `Network will not work. Could not find an available backend.`
przy celowym starcie bez NM. Diagnostyka pozostaje w pełnym logu.
D-Bus ma oba adresy skierowane na ten sam prywatny socket; atrapa odmawia
startu bez znacznika wrappera. Brak hostowych adapterów, sprzętu i PAM.

To odbiór protokołu i UI, **nie rzeczywistego połączenia Wi-Fi**. RF,
NetworkManager/Polkit na docelowym systemie, różni producenci kart/AP,
rzeczywiste WPA/WPA2/SAE, roaming, portal HTTP i Wayland wymagają osobnego
odbioru. Offscreen i atrapa nie dowodzą uwierzytelnienia z prawdziwym AP.


## 14. Bluetooth — etap 08

```sh
scripts/check
scripts/test
scripts/test-bluetooth-integration --idle --output docs/evidence/08-bluetooth.json
scripts/preview --bluetooth --scenario bluetoothMultiple --size 1366x768 --scale 1.25 --screenshot artifacts/bluetooth.png
scripts/preview --bluetooth --scenario bluetoothDeviceFocus --size 320x220 --scale 2 --screenshot artifacts/bluetooth-small.png
```

`tests/qml/tst_bluetooth.qml` używa produkcyjnego BluetoothService, panelu
i kontrolek z atrapami backendu. Sprawdza rzeczywiste h/j/k/l, Enter/Enter
numeryczny, strzałki i tooltip, radio i połączenie bez optymistycznego
sukcesu, odrzucenie/timeout, szeregowaną obsługę szybkich kliknięć, zmianę
adaptera, późne wyniki, utratę urządzenia/usługi, pustą listę, baterię,
dosłowne nazwy, zachowanie delegata/fokusu, parowanie w osobnym programie,
mały panel, sześć ścieżek zamknięcia i 20 cykli. Zamknięcie panelu nie
anuluje zamówionej operacji współdzielonego serwisu.

`scripts/test-bluetooth-integration` jest częścią pełnego `scripts/test`.
Fikcyjny BlueZ udostępnia ObjectManager, Adapter1, Device1 i Battery1.
Sprawdzane są natywne modele Quickshell, rzeczywiste wywołania D-Bus,
PropertiesChanged/InterfacesAdded/Removed, odmowa i brak potwierdzenia,
blokada, wiele adapterów, usunięcie podczas operacji, restart/późny start,
20 LazyLoaderów, miękki/twardy reload z oczekującą operacją, zwalnianie
procesów i otwieranie testowego menedżera. Atrapa rejestruje i test odrzuca
każde StartDiscovery/StopDiscovery/Pair/RemoveDevice lub zapis innych
właściwości. PATH wyklucza uruchomienie prawdziwego Bluemana.

`--idle` mierzy 60 s po rozgrzewce świeżego procesu, offscreen/software,
1920×1080, zegar minutowy, zamknięty panel i wyłącznie natywny Bluetooth.
Porównuje odczyty/operacje oraz RSS, CPU i drzewo procesów. Inne integracje
systemowe są wyłączone/atrapowe. Po zakończeniu sprawdza usunięcie własnych
procesów. Logi zachowują diagnostykę. Jedyny dopuszczony komunikat natywny
to dokładny błąd utworzenia ObjectManager org.bluez, wyłącznie w scenariuszu
celowego startu bez BlueZ; błędy QML/importów nie są wyciszane.

Testy używają prywatnych XDG i obu prywatnych adresów D-Bus. Atrapa sprawdza
znacznik wrappera i adres socketu. Nie kontaktuje się ze sprzętem, PAM,
Polkit ani magistralami hosta. Rzeczywiste profile Bluetooth, kontrolery,
parowanie w Blueman, rfkill/uprawnienia i fokus obcego okna na Waylandzie
pozostają osobnym odbiorem środowiskowym.

## 15. Powiadomienia — etap 09

```sh
scripts/check
scripts/test
scripts/test-notifications-integration --idle --output docs/evidence/09-notifications.json
scripts/preview --notifications --scenario notificationLong --size 1366x768 --scale 1.25 --screenshot artifacts/notification-long.png
scripts/preview --notifications --scenario notificationLong --size 320x220 --scale 2 --screenshot artifacts/notification-small.png
```

`tests/qml/tst_notifications.qml` sprawdza produkcyjne usługi, kontroler,
toasty i Quick Settings na atrapach. 19 wyników obejmuje klawisze h/j/k/l,
Enter/Enter numeryczny, Tab/Backtab, Escape, tooltip, zachowanie fokusu
pola podczas nadejścia i kliknięcia, przekazanie z panelu, pauzę timera
podczas nawigacji i naprawę fokusu po usunięciu. Sprawdza także zastąpienia,
reason 1/2/3, resident/transient, DND i krytyczne, 100 zdarzeń, FIFO,
kolejkę krytycznych na małym ekranie, timeout w kolejce, hotplug i resize,
brak backendu, tekst PlainText, duży obraz i dostęp do ósmej akcji w 320×220,
oraz 20 cykli utworzenia/zniszczenia stosu. Każde ostrzeżenie Qt powoduje FAIL.

`scripts/test-notifications-integration` należy do pełnego `scripts/test`.
Ma natywny `NotificationServer`, produkcyjny backend i obserwatora, rzeczywiste
D-Bus `Notify`, `GetCapabilities`, `GetServerInformation`, `CloseNotification`
oraz sygnały `ActionInvoked` i `NotificationClosed`. 12 grup sprawdza:

- pojedynczego właściciela, dokładne capabilities, brakujące dane;
- rzeczywiste 6000 ms domyślnego timeout, 0, identyczne zastąpienie,
  nowe ID po zamknięciu i trzy powody zamknięcia;
- etykiety i usunięcie akcji po replace, resident/transient, DND i krytyczne,
  w tym zmianę krytycznego na zwykłe przy włączonym DND;
- wybór monitora, przekierowanie/usunięcie ekranów, 100 zdarzeń i kolejkę;
- obraz 8 MiB oraz jego zastąpienie, ograniczenia tekstu, brak znacznika
  treści w argv, logach, cache i prywatnych plikach;
- rozłączenie/powrót klienta, 20 rzeczywistych LazyLoaderów, soft/hard reload,
  zwolnienie natywnych obiektów i poprzednich obserwatorów;
- celowo zajętą nazwę z allow-replacement, brak późniejszego przejęcia
  po jej zwolnieniu, awarię obserwatora i celowy brak Pythona.

Wrapper kieruje oba adresy D-Bus na własny socket, używa prywatnych XDG,
offscreen/software i nie importuje natywnych adapterów sprzętu ani sesji.
Oczekiwana diagnostyka ogranicza się do znanej maski offscreen oraz dokładnie
jednego `Process failed to start` dla komendy obserwatora, wyłącznie w scenariuszu
`missing-helper`. Oba komunikaty pozostają w logu; oczekiwany brak executable
jest zapisany w JSON. Inne ostrzeżenia/importy/awarie powodują FAIL.

`--idle` uruchamia świeży proces, zegar minutowy, 30 workspace i zamknięte
okna panelu/toastów. Po 2 s rozgrzewki mierzy 60 s CPU/RSS shella i jego
jedynego dziecka — obserwatora Python. Po zakończeniu sprawdza usunięcie
zarejestrowanych PID-ów. Krótki pomiar i 20 cykli nie dowodzą braku wycieków
wielogodzinnej sesji ani nie ograniczają pamięci dowolnego payloadu D-Bus.

Wayland/layer-shell, maska, natywny grab, fokus obcej aplikacji, prawdziwy
hotplug i monitory z mieszanymi skalami pozostają do osobnego odbioru.
Nie przełączono ani nie zatrzymano serwera powiadomień hosta.

## 16. Sesja i logind — etap 10 po migracji

```sh
scripts/check
scripts/test
scripts/test-session-integration --output artifacts/session.json
scripts/preview --session --scenario power --screenshot artifacts/power.png
scripts/preview --session --scenario powerConfirm --size 1366x768 --scale 1.25 --screenshot artifacts/confirm.png
scripts/preview --session --scenario powerUnavailable --size 320x220 --scale 2 --screenshot artifacts/power-small.png
```

`tests/qml/tst_session.qml` używa produkcyjnego serwisu, kontrolera wznowienia,
PowerView, Quick Settings i hosta paneli. Rzeczywiste klawisze sprawdzają
h/j/k/l, Enter/Enter numeryczny, Tab, Escape, domyślne Anuluj, dokładnie jedno
żądanie i pomijanie niedostępnych działań. Dodatkowo testuje błąd, timeout,
późny wynik, utratę backendu, przejście z Quick Settings, powrót do paska,
wyśrodkowanie, 320×220, scroll do fokusu, hotplug, wymianę widoku,
odrzucenie potwierdzenia i 20 cykli. Wszystkie ostrzeżenia Qt są błędami.

`scripts/test-session-integration` należy do `scripts/test`. Produkcyjny
pomocnik posiada ScreenSaver na prywatnym D-Bus, a atrapa login1 rejestruje
wywołania i rzeczywiste deskryptory inhibitorów. Testowy entrypoint skraca
tylko timeouty. Natywny host blokady i PAM są tutaj atrapami Qt; rzeczywiste
interfejsy sprawdza osobno opisany powyżej test Waylanda.

Zakres: brak akcji po anulowaniu, aktualny secure przed sleep, brak/spóźnienie
potwierdzenia, odrzucenie starego numeru, serializacja, odmowa/timeout logind,
obcy UID sesji, zanik/powrót właściciela, oba rodzaje reloadu odblokowanego
shella i 20 cykli menu. Inhibitor delay jest zwalniany po secure i odnawiany
po wznowieniu. Fałszywy PrepareForSleep jest odrzucany. Inhibit ScreenSaver
należy do klienta, zwalnia się po jego wyjściu; SetActive(false) nie odblokowuje.

Diagnostyka importów i QML pozostaje włączona. Pomocniki testu są zamykane
przez wrapper. Działania zasilania i uwierzytelnienie nie dotykają hosta.


## Korekta wyglądu po uwagach użytkownika

`tests/qml/tst_visual_contract.qml` sprawdza rzeczywiste wejście Qt, brak
hover popupów, dokładną zainstalowaną rodzinę fontu, ramki 2 px, równe pola
ikon i kolory potwierdzonych połączeń, jedne otwarte szczegóły, błąd jako
toast obok panelu w DND oraz opacity bez zmiany geometrii. Ograniczony ruch
jest sprawdzany przy otwieraniu i zamykaniu; OSD zachowuje ekran do końca fade.

`scripts/test-wayland --nested` obejmuje nakładające się kończenie fade
OSD/toastu i otwieranie panelu, prawdziwy fokus innego klienta Wayland,
kliknięcie poza panelem, osiem skal/trybów, hotplug i 20 cykli.

Natywny podgląd blokady należy teraz do `--native-session`, opisanego powyżej.

Podczas regresji nie edytować plików importowanych przez działające testy:
autoreload Quickshell zmienia wtedy generację i unieważnia wynik.

## Launcher — rozszerzenie

`tests/qml/tst_launcher.qml` używa prawdziwego wejścia Qt: prefiksy i pigułki,
Backspace/usunięcie myszą, hjkl w tekście, Escape/Tab/jkhl/Enter, filtry,
ranking i MRU, opóźnione wyniki, zachowanie tożsamości zaznaczenia, pojedyncza
aktywacja, odmowa i spóźnione potwierdzenie, 100 wpisów na 320×220,
wyłączność, monitor/hotplug i 20 cykli. Testy myszy czekają na render i koniec
fade; nie traktują niegotowej klatki jako dowodu braku obsługi przycisku.

`tests/test_launcher.py` sprawdza prywatny atomowy zapis MRU, limity i obcy
schemat, brak utrwalania schowka, prawdziwe fd oraz cliphist, dosłowne ścieżki
z metaznakami, timeout/anulowanie z zebraniem procesu, start i błędy aplikacji,
Terminal=true, przeżycie launchera przez aplikację, pomijanie danych poufnych
oraz dokładny roundtrip tekstu/binariów na atrapę wl-copy.

`scripts/test-launcher-integration` wchodzi w skład `scripts/test` i łączy
prawdziwe DesktopEntries (także NoDisplay i kody pól Exec), Process,
fd/cliphist, IPC i LazyLoader z prywatnym HOME/XDG/D-Bus. Atrapy wl-paste
odbierają zdarzenia przez prywatne FIFO, a wl-copy/aplikacje zapisują tylko
w katalogu testowym. Sprawdzany jest zapis MRU, soft reload, pusta nowa baza
schowka, 20 cykli i usunięcie bazy przy wyjściu. Logi nie pomijają błędów
importów; negatywny test wspólnego runnera obejmuje nowy punkt wejścia.
Pełnego shella testy nie uruchamiają na aktywnym pulpicie.

## Osobny panel baterii — rozszerzenie

`tst_status.qml` obejmuje teraz procent/pasek/czas, stan pełny i nieznany,
trzy profile, potwierdzenie/odmowę, j/k/Enter/Escape, zmianę modelu z fokusem,
pomijanie niedostępnego trybu, powrót do ikony, właściwy monitor i hotplug,
20 cykli oraz klikanie i przewijanie panelu przy 320×220.

`scripts/test-status-integration` rozszerzono o atrapę PPD na tej samej
prywatnej magistrali co UPower. Produkcyjny adapter wykonuje trzy typowane
zapisy i odczyty potwierdzające; test obejmuje odmowę, zaakceptowany zapis
bez zmiany stanu, brak profilu, zmiany z innej aplikacji, ograniczenie
wydajności, utratę usługi podczas zapisu, powrót/późny start i oba reloady.
Sprawdza też usunięcie obserwatora; opcja `--idle` kontroluje brak odczytów
PPD w bezczynności. To test protokołu, bez przełączania sprzętu hosta.

```sh
scripts/preview --scenario batteryCharging --screenshot artifacts/battery.png
scripts/preview --scenario batteryLow --size 320x220 --scale 1.5 --screenshot artifacts/battery-small.png
scripts/test-status-integration --output artifacts/battery-integration.json
```

Scenariusze `battery`, `batteryCharging`, `batteryLow`, `batteryAbsent`,
`batteryFull`, `batteryNoTime`, `batteryNoProfiles` włączają atrapy statusu.

## Komendy workspace launchera

`tst_launcher.qml` sprawdza przez klawiaturę wszystkie cyfry `:wN` i `:mwN`,
mapowanie 0→10, niepełną składnię, dosłowne filtry, inny monitor, brak
pomocnika, brak/zamknięcie okna, powtórny Enter, timeout, EOF i odpowiedź
ze starej sesji panelu. Korzysta z tego samego WorkspaceService co pasek.
`scripts/test-bar-integration` testuje parser launchera razem z natywnymi
obiektami Hyprlanda i dokładnymi dispatcherami Lua/Hyprlang na prywatnych
socketach. Zmienia fokus między otwarciem i wykonaniem komendy, potwierdza
adres przeniesionego okna i brak przełączenia widoku, usuwa przechwycone
okno i sprawdza odmowę bez wybierania innego. Nie używa okien hosta.

Podglądy: `scripts/preview --scenario launcherWorkspace` oraz
`scripts/preview --scenario launcherMove --size 320x220 --scale 1.5`.
