# Wygląd i zakres Putkin

## Stabilny fade — 2026-09-20

Na polecenie użytkownika usuwamy opcję „Ogranicz ruch”. Jedynym przejściem
jest fade całej złożonej powierzchni przez 200 ms, z łagodnym początkiem
i końcem. Ramka, tekst, ikony oraz gradient mają jedną przezroczystość;
nakładające się tła nie przebijają przez gradient w trakcie animacji.
Otwarcie czeka na gotową stronę i ustabilizowanie układu przed pierwszą
widoczną klatką. Pozycja, wymiary i skala nie są animowane. Zamknięcie
odłącza wejście natychmiast, a powierzchnia znika po fade. Dawne ustawienie
`reducedMotion` jest przy odczycie ignorowane i pomijane w nowym zapisie.
Ta decyzja zastępuje wcześniejsze wzmianki o 120 ms i ograniczaniu ruchu.

## Screenshot — 2026-09-20

Lekka nakładka z celownikiem i zaznaczeniem, a po zatwierdzeniu pływający
podgląd obrazu. Bez obrazu podczas wyboru, bez podpowiedzi i tooltipów.
W wybiera okno aktywne sprzed wywołania. Enter/F zapisuje podgląd,
Escape/Q zamyka go z zachowaniem schowka. Ramki i przyciski korzystają
ze wspólnych tokenów oraz jednego gradientu. [Pełny kontrakt](screenshot.md).

## Blokada i bezczynność w Putkinie — 2026-09-20

Użytkownik zastępuje Hyprlock i Hypridle jednym procesem Quickshell.
WlSessionLock rysuje przyciemnioną tapetę, centralny zegar, datę i jedno
kwadratowe pole hasła. Zachowujemy glif odcisku oraz neutralny/zielony/czerwony
stan i reset błędu po 2 s. Bez dodatkowych tekstów, tooltipów i podpowiedzi.
PAM pozostaje systemowym mechanizmem uwierzytelniania; odblokowanie wymaga
potwierdzonego sukcesu bieżącej próby. Escape czyści pole, Enter wysyła
hasło, hjkl wpisują litery. Każdy monitor ma powierzchnię natywnej blokady.
Bezczynność: 180 s przyciemnienie do 10%, 300 s DPMS off, 360 s blokada,
900 s uśpienie. Powrót aktywności przywraca ekrany i wcześniejszą jasność.
Prezentacja blokuje automatykę; Praca w tle blokuje tylko sen. Ręczna
blokada i blokada przed snem pozostają aktywne w obu trybach.
Historyczne wzmianki o Hyprlocku opisują poprzednie wykonanie;
aktualna odpowiedzialność należy do natywnych modułów Putkina.

## Jednobarwne ikony Material Symbols — 2026-09-20

Wszystkie ikony własnego UI używają Google Material Symbols Outlined,
FILL 0, waga 400, GRAD 0, opsz 24, z katalogu fonts.google.com/icons.
Domyślny kolor to `Theme.text` (`#cdd6f4`). Na topbarze wszystkie ikony
zawsze mają kolor daty i czasu, także przy połączeniu, wyciszeniu, DND,
niskiej baterii, niedostępności i otwarciu modułu. Stan sygnalizuje kształt.
Poza paskiem aktywność, wyłączenie i błędy zachowują role motywu.
Jeden symbol ma jeden kolor, bez
gradientu wewnątrz rysunku, skali szarości ani konwersji bitmap aplikacji
na widoczne ikony.
Lokalne SVG i jeden renderer wektorowy zachowują proporcje i centrowanie.

Wysokość i padding wynikają z sekcji. Pole ładowania poszerza się na
oryginalny piorunek, zgodnie z doprecyzowaniem użytkownika:

| Sekcja | Pole SVG | Padding poziomy / pionowy | Pole ikony |
| --- | --- | --- | --- |
| Top bar, razem z baterią, trayem i przyciskiem nadmiaru | 20 px | 6 / 5 px | 32 × 30 px |
| Bateria podczas ładowania — dodatkowa szerokość na piorunek | 24 × 20 px | 6 / 5 px | 36 × 30 px |
| Launcher, wyniki i wyszukiwanie | 24 px | 4 px | 32 px |
| Suwaki Quick Menu i modułów, razem ze strzałkami | 24 px | 6 px | 36 px |
| Kafelki Quick Menu i Power | 24 px | 4 px | 32 px |
| Listy, menu i przyciski pomocnicze | 20 px | 4 px | 28 px |
| Nagłówki powiadomień | 24 px | 6 px | 36 px |
| OSD | 24 px | 4 px | 32 px |

Topbar ma nadal 32 px wysokości, z czego dolne 2 px zajmuje separator.
Ikony i zegar są centrowane w pozostałych 30 px. Każde pole SVG ma po 5 px
nad i pod sobą; wewnętrzna pusta przestrzeń zależy od kształtu symbolu.
Zegar centruje widoczny obrys znaków, zamiast całego wiersza czcionki,
i zaokrągla położenie do fizycznych pikseli. Nieparzysta wysokość rysunku
może dać różnicę jednego piksela między odstępami.

Bateria używa `battery_android_0`–`battery_android_6`, przy pełnej baterii
`battery_android_full`. Ładowanie używa oryginalnych Material Symbols
`battery_charging_20_2`, `30_2`, `50_2`, `60_2`, `80_2`, `full_2`, z piorunkiem
po prawej stronie. Ścieżki Google pozostają niezmienione. Pole ikony
rozszerza się na piorunek, zachowując padding sekcji; skala symbolu jest
jednorodna i utrzymuje wysokość korpusu baterii 10 px na topbarze.
Różnica proporcji obu oryginalnych symboli nie jest korygowana rozciąganiem.
Zastępuje to odrzucony wariant z piorunkiem nałożonym na Battery Android.
Nieznany odczyt ma `battery_android_question`.
Powiadomienia: `notifications`, `notifications_unread`, `notifications_off`;
DND ma pierwszeństwo. Otwarcie centrum oznacza historię jako przeczytaną;
wygaśnięcie toasta nie usuwa nieprzeczytanego wpisu.
Wi-Fi używa rodziny `network_wifi`, w tym wariantów 1/2/3 bar według siły.
Brak połączenia/radia pokazują pasujące trójkątne `signal_wifi_0_bar`/`signal_wifi_off`.

Google nie dostarcza logotypów innych aplikacji. Aplikacje dostają lokalną
mapę symboli funkcji i kategorii. Signal w launcherze używa `chat_bubble`.
W trayu bez nieprzeczytanych wiadomości ma `chat_bubble`, a z nimi `chat`
(dymek z trzema liniami). Oba symbole mają identyczny obrys, rozmiar,
padding i jasny kolor; Signal nie dostaje dodatkowej kropki uwagi.
Tether ma własne jednobarwne uzupełnienie na tej samej siatce.
Nieznane aplikacje używają `apps`.
Zastępuje to wcześniejszy kontrakt Papirus-Dark i odcieni szarości.

## Ramki okien Hyprlanda — 2026-09-20

Okna mają kwadratowe narożniki i ramkę 2 px, zgodnie z tokenami Shella.
Aktywna ramka używa jego dwóch akcentów i tego samego pola gradientu:
lewy górny → prawy dolny, równy udział osi niezależnie od proporcji okna.
Nieaktywna ramka używa neutralnego `border`. Dotyczy to również grup okien.
Podgląd, anulowanie i zapis motywu aktualizują ramki; restart Shella
i przeładowanie Hyprlanda ponownie stosują bieżące kolory.

## Wspólny gradient i ramki — 2026-09-20

Dwa akcenty są końcami jednego gradientu: główny w lewym górnym rogu,
dodatkowy w prawym dolnym. Cały pasek na monitorze stanowi jedną grupę;
każdy panel, w tym Quick Menu i launcher, ma własną grupę. Ramka,
wypełnienia aktywnych elementów, suwaki i fokus korzystają z tego samego
pola kolorów. Gradient nie zaczyna się od nowa w przycisku ani wierszu.
Przewijanie i zmiana rozmiaru zachowują jego położenie względem grupy.
Doprecyzowanie użytkownika: osie pozioma i pionowa mają równy udział
niezależnie od proporcji grupy. Prawy górny i lewy dolny róg mają mieszankę
obu akcentów 1:1; także niski pasek zachowuje wyraźne przejście góra–dół.
Drobne glify, tekst akcentowy i uchwyty pobierają kolor ze swojego miejsca
w grupie. Próbki w edytorze nadal przedstawiają dosłowny wybierany kolor;
kolory ostrzeżeń i błędów zachowują znaczenie.

Otwarty moduł na pasku ma tło akcentu; jego ikona zachowuje kolor daty
i czasu, zgodnie z korektą topbara z 2026-09-20.
Fokus pola tekstowego podświetla jego własną ramkę 2 px, bez dodatkowego
zewnętrznego obrysu. Reguła myszy i klawiatury pozostaje wspólna.
W Quick Menu fokus jasności i temperatury obejmuje całą szerokość wiersza,
włącznie z ikoną i wartością, tak jak wiersz głośności. Kontrolki wewnątrz
nie dorysowują własnych obrysów; kliknięcie nadal ukrywa fokus.

## Quick Menu i centrum powiadomień — 2026-09-20

Dźwięk ma jeden punkt nawigacji i jedną ramkę obejmującą cały wiersz:
`h/l` zmieniają głośność, `Enter/i` rozwijają wyjścia, `j/k` przechodzą
między wierszami. Mysz nadal osobno obsługuje suwak, wyciszenie i strzałkę.
Nazwy audio rozróżniają złącza; głośniki wbudowane to „Wbudowane głośniki”.
Wi-Fi i Bluetooth w Quick Menu są wyłącznie kafelkami on/off. Zarządzanie
odbywa się w osobnych panelach modułów z paska. Światło nocne nie ma
przycisku odświeżania. Zmiany stanu nie dodają tekstów postępu ani sukcesu;
błędy są powiadomieniami. Nie przeszkadzać ma kafelek w Quick Menu oraz
zsynchronizowany przełącznik w centrum, dostępnym z paska i skrótu.
Oddzielny przycisk „Powiadomienia” usunięto z Quick Menu.
Centrum przechowuje do 100 ostatnich powiadomień w pamięci sesji, także
wygasłych, wyciszonych przez DND i oznaczonych `transient` (także VoxType).
Po zamknięciu protokołu zachowuje tylko tekst i bezpieczną ikonę, bez
akcji i obrazów zależnych od życia natywnego obiektu. Restart czyści historię.
Karty wybierane przez `j/k` mają własny fokus; `Enter` i kliknięcie treści
wykonują akcję powiadomienia. `i` oraz strzałka w nagłówku rozwijają skrócony
tekst, `Escape` zwija go przed zamknięciem panelu. Nawigacja między kartami
zachowuje rozwinięcie. Centrum przewija całą listę wraz z pełnym tekstem.
Przycisk × ma grubszy symbol, bez domyślnej ramki i tła.

Data decyzji: 2026-09-17. Kontrakt uwzględnia korekty użytkownika po obejrzeniu działającego shella, w tym wielkość ikon oraz oznaczenie zajętych workspace’ów. Minimalizm, zgodność z referencjami i przejścia wyłącznie przez opacity są wymaganiami, nie opcjami.

Podpowiedzi, teksty pomocnicze i tooltipy wolno dodawać wyłącznie na
wyraźne polecenie użytkownika. Ta zasada obowiązuje przy wszystkich
przyszłych zmianach interfejsu.

## 1. Co wynika z obrazów

| Obraz w katalogu głównym | Rola | Co przenosimy |
| --- | --- | --- |
| `ChatGPT Image Sep 15, 2026, 11_58_07 PM (1).png` | Widok całego pulpitu | Spokojny, pełnoszeroki pasek, dużo miejsca na tapetę, wyraźne obramowania 2 px |
| `ChatGPT Image Sep 15, 2026, 11_58_07 PM (2).png` | Style guide | Catppuccin Mocha, monospace, kwadratowe rogi, stany workspace, prosty toast i OSD |
| `ChatGPT Image Sep 15, 2026, 11_58_08 PM (3).png` | Stany i ekrany | Quick Settings po prawej, powiadomienia w prawym górnym rogu, power menu, stylistyka blokady |
| `ChatGPT Image Sep 15, 2026, 11_58_08 PM (4).png` | Kierunek architektury | UI oddzielone od integracji; istniejące usługi systemowe jako źródło stanu |

Nazwy Waybar, mako, wlogout, hyprpaper oraz tekst konfiguracji na obrazach opisują przykładowy pulpit. Nie oznaczają obowiązku uruchomienia tych programów razem z ich odpowiednikami w Quickshellu. Rysunek architektury nie wymaga tworzenia osobnego procesu dla każdego adaptera QML.

## 2. Układ

- Jeden ciągły pasek przy górnej krawędzi każdego monitora; margines zewnętrzny 0, środek pusty.
- Po lewej workspace 1–5. Aktywny ma tło akcentu i sam numer, bez trójkąta ani dodatkowego znaku; nieaktywny zajęty ma numer w kolorze akcentu i wadze DemiBold, bez kropki; stan pilny ma pogrubiony numer w kolorze błędu. Udostępnić również aktywny/zajęty workspace spoza 1–5. Obszar ma ograniczoną szerokość: aktywny pozostaje widoczny, pozostałe są osiągalne przewijaniem lub wejściem do nadmiarowych pozycji, także klawiaturą.
- Po prawej niewielki tray, sieć, Bluetooth, audio, bateria, powiadomienia, ustawienia, data i godzina. Ikony statusu mają równe pola 32 px. Audio i bateria bez procentów na pasku. Zmiana symbolu odzwierciedla stan; kolor wszystkich ikon jest taki jak daty i czasu. Brak sprzętu usuwa niepotrzebny wskaźnik, nie udaje wartości 0%.
- Kliknięcie statusu systemu otwiera Quick Settings przy prawym brzegu paska; Wi-Fi, Bluetooth, bateria, audio i powiadomienia mają osobne panele. Dwa suwaki są widoczne od razu; szczegóły jednego modułu naraz pojawiają się przez fade. Rozmiar panelu zmienia się natychmiast, bez animacji geometrii.
- Ustawienia wyglądu dostępne przez jawny przycisk w Quick Settings. Power menu osobną powierzchnią pośrodku właściwego monitora.
- Toasty powiadomień u góry po prawej, poniżej paska. OSD nie zabiera fokusu i nie zasłania głównej kontroli, której zmianę pokazuje.
- Przy braku miejsca najpierw skracać datę i ograniczać tray. Workspace, zegar i wejście do Quick Settings pozostają dostępne. Panel ograniczać do dostępnej szerokości **i wysokości**, długą zawartość przewijać.

Quick Settings zawiera kolejno suwak audio, suwak jasności i prostokątne
kafelki w dwóch kolumnach: Wi-Fi / Bluetooth, Nie przeszkadzać / Światło
nocne, Caffeinate. Ikona jest po lewej, etykieta po prawej, z odstępem 8 px.
Światło nocne jest przełącznikiem; po włączeniu pojawia się suwak temperatury
z termometrem. Stopka zawiera Blokadę, Ustawienia i Zasilanie. Bez opisu motywu, diagnostycznych akapitów i tooltipów.
Szczegóły urządzeń są domyślnie schowane; otwarcie kolejnych zamyka poprzednie.
Kafelek Caffeinate przełącza zapamiętany tryb, domyślnie Prezentację. `i`
albo prawy przycisk rozwija wybór: Prezentacja i Praca w tle. `j/k`,
Enter oraz Tab działają na liście. [Semantyka i integracja](caffeinate.md).
Fokus klawiatury na wyłączonym przycisku podświetla jego istniejącą ramkę;
zaznaczony element zachowuje zewnętrzną ramkę. Mysz nie rysuje fokusu.
Niedostępny suwak zachowuje układ, jest nieaktywny i pokazuje „—”.
Krótkie nazwy, potwierdzony stan i opis dostępności zastępują instrukcje
wyświetlane stale. Hasło Wi-Fi zachowuje zwykłe wpisywanie tekstu.

OSD jest jednym poziomym wierszem: ikona, gruby pasek wypełnienia, procent.
Pojawia się u dołu właściwego monitora, nie zabiera fokusu i nie dubluje
regulacji w otwartym panelu. Ramka i poziom używają wspólnego gradientu OSD.
[Audio](audio.md), [jasność](brightness.md), [bateria i tray](battery-tray.md),
[sieć](network.md), [Bluetooth](bluetooth.md).

Błędy operacji, backendów i walidacji trafiają do osobnego powiadomienia.
Nie umieszczamy ich pomiędzy kontrolkami. Toast błędu pozostaje widoczny przy
otwartym panelu oraz w DND; na szerokim ekranie mieści się obok panelu.
Powtarzający się błąd tej samej kategorii aktualizuje istniejący toast.
Nadejście nie przejmuje fokusu. Zwykłe powiadomienia nadal ustępują panelom.
W otwartym centrum wpis błędu jest widoczny w historii, bez drugiego toastu.
[Kontrakt powiadomień](notifications.md).

Power menu pokazuje cztery kafelki w jednym rzędzie; mały ekran używa dwóch
kolumn. Akcje kończące pracę nadal wymagają osobnego potwierdzenia, domyślnie
z fokusem na Anuluj. Natywna blokada Quickshell ma przyciemnioną tapetę,
duży zegar pośrodku, datę i jedno kwadratowe pole hasła, bez avatara.
Używa wspólnych akcentów i tapety; uwierzytelnienie obsługuje PamContext.
[Kontrakt sesji](session.md).

W polu hasła, przy lewym brzegu wewnątrz ramki, jest glif odcisku
`md-fingerprint` z tej samej rodziny Nerd Font. Kolory Catppuccin Mocha:
wyjściowy Subtext0 `#a6adc8`, poprawny skan Green `#a6e3a1`, błąd Red
`#f38ba8`. Błąd gaśnie po 2 s; następny błąd odnawia ten czas. Sukces
pozostaje zielony do zniknięcia blokady. Glif pozostaje widoczny podczas
wpisywania hasła; nie dodaje etykiet ani podpowiedzi. Uwierzytelnianie
i moment odblokowania należą do LockService oraz PamContext; sukces odblokowuje od razu.

Tapeta i światło nocne zachowują dotychczasowe adaptery.
[Kontrakt pulpitu](desktop.md). Strona Wygląd edytuje dwa akcenty i
zapis według [kontraktu ustawień](settings.md).
Okna i powrót fokusu: [kontrakt paneli](panels.md).

### Rozszerzenie: launcher — 2026-09-17

Korekta listy i podglądu 2026-09-20: pod chipem kategorii pozostaje sama
lista, bez powtórzonego nagłówka. Historia bez filtra zachowuje „Ostatnie”.
Wpisy schowka mają jeden wiersz samej treści, 36 px wysokości, bez ikony
i podpisu „Schowek”. Aplikacje zachowują ikony. Wybrany wpis schowka
pokazuje po prawej kwadratową ramkę do 320 × 320 px, wyrównaną do góry
launchera: obraz dopasowany z zachowaniem proporcji albo zawijany tekst
z przewijaniem. Podgląd podąża za klawiaturą i najechaniem wskaźnika.
Lista zachowuje szerokość do 640 px; gdy obok nie mieści się co najmniej
160 px podglądu, pozostaje sama lista. Obie ramki dzielą gradient grupy.
Bez nowych podpowiedzi, podpisów i tooltipów.

Korekta 2026-09-20: launcher korzysta ze wspólnego katalogu Material Symbols
opisanego na początku tego dokumentu. Wyniki poza zwartymi wierszami schowka
mają jednobarwne ikony, równe pola i padding. Zastępuje to wcześniejszy Papirus.

Na życzenie użytkownika dodajemy launcher pod `Super+Spacja`: aplikacje,
pliki w katalogu domowym i schowek. `:a `, `:f `, `:c ` zamieniają prefiks
w usuwalną etykietę filtra (odpowiednik pigułki poprzednika, z kwadratowymi
rogami Putkina). Puste zapytanie pokazuje ostatnie użycia; `: ` wybiera
samą historię. Bez interpretacji poleceń powłoki i integracji terminala.
Panel ma szerokość do 640 px, jest wyśrodkowany na aktywnym monitorze,
używa wspólnych tokenów, ramek 2 px i wyłącznie przejścia opacity.
Wyszukiwanie nie blokuje wpisywania, a lista mieści się w wysokości ekranu.
Enter aktywuje, strzałki wybierają; Escape z pola przechodzi do nawigacji
`j/k`, kolejny zamyka, `h/l` i `/` wracają do pola/filtra. Litery w polu
są tekstem. Backspace w pustym polu odtwarza prefiks filtra.
Historia zapisuje do 100 identyfikatorów aplikacji/plików, bez treści schowka.
Schowek jest ograniczony do sesji procesu, 100 wpisów po maks. 2 MiB;
pomija oznaczone poufne dane. Enter kopiuje wpis, bez automatycznego wklejania.
Szczegóły implementacji i ograniczenia: [launcher](launcher.md).

Rozszerzenie komend: `:wN` przełącza workspace, `:mwN` przenosi okno
aktywne przed otwarciem launchera bez zmiany widoku. N to pojedyncza cyfra
0–9; 0 oznacza workspace 10, zgodnie z istniejącymi skrótami Hyprlanda.
Wynik komendy jest widoczny w liście i wymaga Enter; samo wpisywanie nie
zmienia pulpitu. Filtry :a/:f/:c nadal traktują zawartość jako wyszukiwanie.

Korekta 2026-09-17: `Super+V` otwiera launcher z filtrem schowka,
`Super+;` (bez Shift) otwiera pustą treść komendy z usuwalnym chipem „Komenda”.
Nagłówek historii nazywa się „Ostatnie”. W trybie komend dwukropek jest
reprezentowany przez chip; wpisanie `:w3` w zwykłym launcherze działa nadal.
Niepełne komendy, w tym `:w`, nie pokazują tekstu pomocniczego.

### Rozszerzenie: Ustawienia i Klawiatura — 2026-09-17

Ustawienia otwierają osobne natywne okno z tytułem „Ustawienia”, zamiast
warstwy panelu. Sekcje „Wygląd” i „Klawiatura” współdzielą tokeny Putkina.
Wygląd zachowuje graficzne edytory obu akcentów i zapis.
Klawiatura udostępnia gotowe działania Hyprlanda i shella, edytowalny skrót
oraz komendę `:` dla każdego działania. Zapis sprawdza duplikaty i konflikty
ze skrótami kompozytora. Zamknięcie odrzuca niezapisane zmiany; samo wpisanie
komendy nie wykonuje działania. Akcje sesji zachowują osobne potwierdzenie.

### Rozszerzenie: osobny panel audio — 2026-09-17

Ikona głośnika otwiera osobną ramkę po prawej stronie, w tym samym
koordynatorze paneli. Od razu widoczne są suwaki głośnika i mikrofonu,
wyciszanie oraz wybór urządzeń wyjściowych i wejściowych. Bez dodatkowego
nagłówka i instrukcji. Stan oraz wybór potwierdza PipeWire; brak urządzenia
wyłącza właściwą kontrolkę. Panel przewija się na małym ekranie, zachowuje
h/j/k/l, Enter, Tab i Escape oraz wspólne tokeny i fade. Quick Settings
zachowuje dotychczasową regulację wyjścia. Otwarty panel audio tłumi OSD
głośności; regulacja mikrofonu nie pokazuje OSD głośnika.

### Rozszerzenie: panel baterii — 2026-09-17

Rozszerzenie baterii (2026-09-17): ikona baterii otwiera osobny panel po
prawej stronie. Adaptacja `BatteryPopup` poprzednika: procent, poziomy pasek,
stan i czas do rozładowania / pełnego naładowania, trzy tryby pracy
(Oszczędny, Zrównoważony, Wydajność). Kwadratowe kontrolki ze wspólnymi
tokenami; aktywny tryb oznaczony kolorem i stanem dostępności Qt. Niedostępny tryb jest
nieaktywny. Nieznany czas nie daje pozornego szacunku. Zmianę trybu potwierdza
usługa systemowa; błędy trafiają do istniejących powiadomień.

Korekta użytkownika: bez nagłówka „Bateria”, przycisku ×, komunikatu
„Niski poziom baterii”, nagłówka „Tryb pracy” i widocznej etykiety „Aktywny”.
Bez separatora nad profilami i tekstu stanu obok procentu („Na baterii”,
„Ładowanie” i pozostałe stany). Pozostają procent, pasek i informacja o czasie.
Przełączanie profilu nie wyświetla napisu „Zmiana…”.
Tekst przycisków jest wyśrodkowany w pionie; zamykanie przez Escape lub poza
panelem. Nawigacja zapętla dostępne profile; przy braku profili fokus
pozostaje na panelu, aby nadal obsługiwać Escape.

### Nawigacja klawiaturą

Ustalenie użytkownika z 2026-09-16: **nawigacja Putkin jest vimowa**.

| Klawisz | Działanie |
| --- | --- |
| `h` | W lewo |
| `j` | W dół |
| `k` | W górę |
| `l` | W prawo |
| `Enter` | Potwierdzenie / aktywacja wybranej pozycji |

To podstawowa nawigacja paska, paneli, list i menu. Kierunki odpowiadają
układowi elementów; na poziomym suwaku `h`/`l` zmniejszają/zwiększają wartość.
Fokus pozostaje widoczny, a niedostępne elementy są pomijane. Skróty działają
w aktywnej powierzchni Putkin, bez przejmowania klawiszy innych aplikacji.

Podczas edycji tekstu litery `h/j/k/l` trafiają do pola. `Enter` potwierdza
bieżący wybór lub edycję zgodnie z kontekstem; nie omija osobnego potwierdzenia
akcji zasilania. `Escape` zachowuje reguły cofania/zamykania. Standardowe wejście
Qt (Tab/Shift+Tab, strzałki, Spacja) może pozostać dodatkową drogą obsługi.

Ustalenie z 2026-09-19: **ramka fokusu jest wyłącznie dla interakcji
klawiaturą**. Kliknięcie wykonuje działanie bez ramki, również na elemencie
wcześniej wybranym klawiaturą. Dotyczy workspace’ów, wszystkich modułów
paska, Quick Settings, menu oraz przyszłych kontrolek. Przeciąganie suwaka
także nie pokazuje ramki. Hover, wciśnięcie, aktywny workspace i stan
włączonej funkcji zachowują swoje oznaczenia.

Panel otwarty myszą i jego kolejne strony zachowują wejście potrzebne do
obsługi Escape i klawiatury, lecz obrys pojawia się dopiero przy użyciu
klawiszy. Otwarcie skrótem/IPC od razu pokazuje wybór klawiatury.
Kliknięte pole tekstowe nadal przyjmuje tekst i ustawia kursor.
Kontrolki oraz ich własne tła korzystają ze wspólnego wskaźnika fokusu;
samo `activeFocus` nie jest warunkiem rysowania ramki.

## 3. Tokeny startowe

Wartości geometrii są propozycją do weryfikacji w renderze, w logicznych pikselach Qt. Obrazy wygenerowane przez AI nie są precyzyjną specyfikacją wymiarów.

| Token / rola | Wartość startowa |
| --- | --- |
| Tło główne `background` | `#1e1e2e` — base |
| Ciemniejsze tło `backgroundStrong` | `#181825` — mantle |
| Powierzchnia kontrolki `surface` | `#313244` — surface0 |
| Obramowanie neutralne `border` | `#45475a` — surface1 |
| Tekst `text` | `#cdd6f4` |
| Tekst drugorzędny `textMuted` | `#a6adc8` |
| Akcent główny `accent` | `#cba6f7` — mauve |
| Akcent dodatkowy `accentSecondary` | `#89b4fa` — blue, prawy dolny koniec gradientu |
| Sukces / ostrzeżenie / błąd | `#a6e3a1` / `#f9e2af` / `#f38ba8` |
| Rogi / przezroczystość powierzchni | 0 px / 100% |
| Obramowanie / fokus | 2 px / 2 px |
| Wysokość paska | 32 px |
| Odstępy | 4, 8, 12, 16, 24 px |
| Wewnętrzny odstęp panelu | 12 px |
| Szerokość Quick Settings | 360 px, ograniczona rozmiarem monitora |
| Wysokość celu interakcji | co najmniej 32 px; w panelach zwykle 36 px |
| Font / tekst interfejsu | `JetBrainsMono Nerd Font Mono`; 13 px, drugorzędny 12 px |
| Glify statusu | font 20 px; skompresowane glify Wi-Fi i audio 32 px, aby wyrównać widoczną wielkość rysunku |
| Ruch | wyłącznie fade złożonej powierzchni, 200 ms; start po ustabilizowaniu układu |

Paleta bazuje na Catppuccin Mocha. Rozdział akcentów i kolorów komunikujących stan odpowiada zasadom [oficjalnego style guide](https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.md). Geometria, dwa konfigurowalne akcenty i powyższe rozmiary są decyzjami Putkin.

Wymagana zainstalowana rodzina `JetBrainsMono Nerd Font Mono` dostarcza tekst i glify statusu. Ikony mają nazwy dostępności; brak popupów na hover. Zakazane są animacje pozycji, wymiarów, skali i rozwijania/zwijania. Reguła warstw Putkin wyłącza dodatkowe animacje compositora.

## 4. Kolory edytowane w interfejsie

Etap 03 dostarcza gotową stronę **Wygląd**, zanim dojdą kolejne moduły:

- Akcent główny oraz dodatkowy: wybór z próbek Mauve, Pink, Blue, Lavender, Peach, Teal i pole `#RRGGBB`.
- Podgląd na żywo obejmuje wszystkie monitory, otwarte panele, aktywne workspace, fokus, przełączniki i wypełnienia suwaków.
- „Zapisz” utrwala zweryfikowane wartości; „Anuluj” odrzuca podgląd; „Przywróć domyślne” przywraca projektowe kolory w edytowanej wersji ustawień.
- Każde zamknięcie formularza bez udanego zapisu — Escape, kliknięcie poza nim, zastąpienie panelem, hotplug lub reload — odrzuca podgląd tak jak „Anuluj”. Ukryty edytor nie pozostawia aktywnych globalnych kolorów roboczych.
- Niepoprawny kolor ma obrys błędu i osobne powiadomienie po zatwierdzeniu/opuszczeniu pola; nie trafia do pliku. Nie akceptować przezroczystych kolorów jako sposobu obejścia nieprzezroczystego stylu.
- `onAccent` dobierany do koloru wypełnienia z jasnego/ciemnego wariantu. Bardzo słaby kontrast akcentu z tłem wymaga czytelnego ostrzeżenia lub alternatywnego obrysu; fokus i stany nie mogą polegać tylko na kolorze.
- Trwałe ustawienia w `${XDG_CONFIG_HOME:-$HOME/.config}/putkin/settings.json`; pierwszy zapis tworzy także brakujący katalog aplikacji. Podgląd i otwarcie panelu pozostają stanem chwilowym.
- Błąd zapisu jest osobnym toastem. UI nie pokazuje „zapisano”, dopóki zapis się nie powiedzie. Uszkodzony plik nie usuwa ostatniej poprawnej konfiguracji.

Zmiana akcentu obejmuje UI Putkin i ramki Hyprlanda oraz wygląd natywnej blokady Quickshell. Synchronizację ramek dodano na polecenie użytkownika 2026-09-20. Motywy zawartości innych aplikacji mają odrębne konfiguracje.

## 5. Zakres pierwszej wersji

**Rdzeń:** pasek, workspace, zegar, tray, bateria, audio, jasność podświetlenia laptopa, OSD, Quick Settings, Wi-Fi, podstawowy Bluetooth, toasty z DND, ustawienia akcentów, power menu i natywna blokada i obsługa bezczynności Quickshell.

**Świadome uproszczenia:**

- Sieć: Ethernet i zwykłe Wi-Fi, w tym hasło PSK; zaawansowane profile, VPN i enterprise przez opcjonalny systemowy edytor.
- Bluetooth: radio oraz połączenia z już sparowanymi urządzeniami. Pełne parowanie/PIN w QML to oddzielne rozszerzenie; można jawnie otworzyć zewnętrzny menedżer.
- Powiadomienia: toasty, akcje, timeouty, DND. Brak trwałej historii, załączników do odpowiedzi i własnych rozszerzeń protokołu w pierwszej wersji.
- Audio: wyjście, mute, poziom i wybór urządzenia; rozbudowany mikser aplikacji odroczony.
- Blokada: WlSessionLock, wygląd z referencji, hasło i odcisk przez PamContext w tej samej instancji Quickshell.
- Tapeta, Night Light i przykłady motywów zewnętrznych w opcjonalnym etapie 11. Wyłączenie tej funkcji nie blokuje używania shella.

Launcher, multimedia, historia schowka, screenshot editor, overview, browser bridge, własny greeter i natywne moduły C++ pozostają poza domyślną roadmapą. [Audyt](audit.md) opisuje kandydatów do późniejszego wykorzystania.

## 6. Granica między shellem a pulpitem

| Element referencji | Właściciel |
| --- | --- |
| Pasek, panele, OSD, powiadomienia, ustawienia | Putkin / Quickshell |
| Workspace, tiling, ramki okien, gaps, skróty | Hyprland; Putkin wywołuje jego API |
| Zawartość terminala, prompt Fish, Neovim | Konfiguracja tych aplikacji |
| Bezpieczna blokada i uwierzytelnianie | Protokół session-lock kompozytora i PamContext Quickshell |
| Tapeta | Opcjonalny moduł Putkin / Quickshell, zgodnie z decyzją użytkownika z etapu 11; bez hyprpaper, dokładnie jeden właściciel |
| Temperatura barwowa ekranu | Istniejąca usługa użytkownika hyprsunset 0.4.0; Putkin jest klientem IPC |

Żaden z czterech PNG nie jest czystą tapetą: zawiera pasek, okna lub opisy. W etapie 11 należy użyć osobnego obrazu użytkownika albo osobno przygotowanej ilustracji. Nie ustawiać zrzutu z narysowanym paskiem jako tła pulpitu.

## 7. Odbiór wizualny

Zrzuty porównawcze: pasek, Quick Settings, ustawienia kolorów, OSD, toast, power menu oraz zewnętrzna blokada, jeśli testowane jest środowisko z nią. Widoki ze stałymi atrapami danych powinny umożliwiać powtarzalne porównanie.

Sprawdzić 1920×1080 i 1366×768, skale 1 / 1,25 / 1,5 / 2, dwa monitory z różnymi skalami, długi tekst i brak sprzętu. Te rozdzielczości i skale są planem testów, nie wynikiem obecnego audytu. Teksty produktu domyślnie po polsku; daty według locale użytkownika.
