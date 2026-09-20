# Odbiór etapu 12

2026-09-16. **Etap 12 ukończony dla wersji `20260916-5132708bd8f7`
— kandydat wydania zweryfikowany w zakresie
[promptu](prompts/12-validation.md).** Naprawiono fokus i zamykanie paneli
oraz powiadomień. Końcowa regresja, natywny Wayland, klawiatura, wygląd
i wymagane pomiary przeszły. Użytkownik potwierdził działanie sprzętu,
blokady, uśpienia i wybudzenia oraz włączania i wyłączania Night Light.
Poniżej rozdzielono dowody automatyczne, odbiór użytkownika i ograniczenia.
[Lokalne przełączenie już wykonano; przenośny instalator etapu 13 pozostaje
niewdrożony](install.md).

## Zamknięcie kryteriów

Ostatni przebieg: `scripts/check` **PASS**, 137 QML, 0 błędów;
`scripts/test` **PASS**, kod 0, 17 testów Python, 235 wyników QtTest
(0 błędów i pominięć; 67,494 s) oraz wszystkie 12 runnerów integracyjnych.
[Log bramki](evidence/12-closeout-check.log),
[log testów](evidence/12-closeout-tests.log),
[25 plików wyników integracji i ich sumy](evidence/12-closeout-integrations/manifest.json),
[zbiorczy wynik zamknięcia](evidence/12-closeout.json).

| Zadanie z promptu 12 | Wynik i dowód |
| --- | --- |
| 1. Pełna ścieżka użytkownika | **PASS** w QtTest oraz przez rzeczywiste wejście Waylanda: start/workspace → Quick Settings → oba akcenty/zapis → audio/jasność → sieć/BT → toast/DND → anulowanie Power; [raport natywny](evidence/12-wayland-run13/report.json). |
| 2. Regresja i źródłowa diagnostyka QML | **PASS** w końcowych logach powyżej; 17 testów Python obejmuje celowy brak importu w 15 uruchomieniach. Naprawy fokusu potwierdzone natywnym kliknięciem i klawiaturą. |
| 3. Wygląd na Waylandzie | **PASS**, 18 ocenionych PNG: osiem kombinacji rozdzielczości/skali, dwa monitory o różnych skalach, cztery konteksty hotplug, długie etykiety i 40 pozycji traya; [ocena i sumy PNG](evidence/12-wayland-run13/review.json). |
| 4. Klawiatura i fokus | **PASS**, h/j/k/l i Enter, tekst w osobnej aplikacji, bierne OSD/toasty, powrót fokusu, overflow/podmenu i IPC na drugim monitorze; raport natywny powyżej. |
| 5. Awarie na atrapach i reload | **PASS** w 12 integracjach: utrata/powrót usług, odmowy, timeouty, stare odpowiedzi, uszkodzone ustawienia i reload. [Sesja](evidence/12-closeout-integrations/session.json) potwierdza blokada → potwierdzenie → suspend, brak suspend bez potwierdzenia oraz pojedyncze odświeżenie jasności po resume. |
| 6. Spoczynek i cykle | **PASS**, [baza 60 s](evidence/12-baseline-idle.json), natywne 60 s i 20 cykli oraz [rozszerzenie do 60 cykli](evidence/12-combined-idle.json). CPU/RSS, procesy, skanowanie i przyczyny pracy opisano niżej; końce kolejnych dziesiątek cykli natywnych nie wykazują dalszego wzrostu RSS. |
| 7. Rzetelny podział wyników | **PASS**, [zgłoszenia użytkownika](evidence/12-user-acceptance.json), [odczyt działającej sesji](evidence/12-closeout-live.json) i opis ograniczeń na końcu raportu. Brak otwartych wymaganych kryteriów lub wykrytych usterek wymagających naprawy. |

Nie zmieniono wymagań promptu: jego punkt 5 nakazuje testy awarii na
atrapach, a punkt 6 wymaga 60 s spoczynku i 20 cykli. Wcześniej wymienione
dodatkowe próby awarii na fizycznym sprzęcie, audyt PAM, pomiar VRAM
i wielogodzinna sesja pozostają granicami dowodów, nie blokadą tego etapu.

Podczas końcowej regresji źródła runtime i testów były identyczne z użytymi
w zaliczonym odbiorze Waylanda. Testy zakończyły się o **20:52:43 UTC**;
zgodność ponownie potwierdzono o **20:55 UTC**. Zweryfikowano również sumy
i wymiary wszystkich 18 PNG. Wszystkie **110 plików opublikowanego runtime**
nadal odpowiada manifestowi instalacji; 109 było też w manifeście odbioru
natywnego. Dodatkowy `config/menu-keybinds.lua` pochodzi ze sprawdzonego
lokalnego przełączenia. [Archiwum odebranego runtime](evidence/12-closeout-runtime.tar.gz).

**Od 21:05 UTC pojawiły się równoległe edycje wyglądu w katalogu roboczym**,
m.in. fontu, geometrii, tooltipów i panelu. Nie powstały w ramach tego
zamknięcia i nie nadpisano ich. Wynik PASS odnosi się do wskazanej wyżej
wersji, nie do tych późniejszych zmian; wymagają one własnej regresji
i odbioru wyglądu. Nie powtarzano testów podczas trwających obcych edycji.
Użytkownik potwierdził zakres: „Tak — zamknij etap 12 dla działającej wersji”.
[Manifest przyjętych źródeł](evidence/12-closeout-source-sha256.json) zachowuje
sumy sprawdzonego kodu i testów oraz końcowej dokumentacji, promptów i zasad;
nie jest deklaracją zgodności z później zmienionym katalogiem roboczym.

## Warunki i zakres

Sprawdzono rzeczywistą implementację 00–11: pasek/workspace/zegar,
Quick Settings, oba akcenty i zapis, audio, jasność i wspólny OSD,
baterię/tray, Wi-Fi, sparowany Bluetooth, toasty/DND, menu sesji,
opcjonalną tapetę i Night Light. Produkcyjny `shell.qml` pozostał małym
korzeniem, z pojedynczymi usługami współdzielonymi przez widoki monitorów.
Testowe backendy nie weszły do produkcyjnego UI.

Wersje ponownie odczytane lokalnie: Quickshell **0.3.1**, Qt **6.11.2**,
Hyprland **0.56.2**, Aquamarine **0.15.0**, hyprsunset **0.4.0-3**,
Python **3.14.7**, D-Bus **1.16.2**. Użyto Noto Sans Mono, fallbacku
monospace; JetBrains Mono nie jest dostępny. Źródła API sprawdzone przed
użyciem: [Qt TestCase 6.11](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html),
[PanelWindow 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
[HyprlandFocusGrab 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandFocusGrab/),
[Quickshell/reload 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/).

Każdy automatyczny test zachowania ma prywatne XDG i D-Bus oraz wyłączone adresy usług hosta.
PipeWire ma tylko wirtualne sinki, systemowy D-Bus jest atrapą protokołu,
brightnessctl i locker są atrapami executable. Offscreen/software używa
jednego ekranu Qt; drugi monitor w testach jest obiektem danych.
Po wyraźnej zgodzie uruchomiono produkcyjne okna z atrapami na prywatnym,
zagnieżdżonym Waylandzie. Te testy nie aktywowały produkcyjnego `shell.qml`
na pulpicie ani nie uruchamiały operacji sprzętu, PAM czy prawdziwego suspend.
Prywatny D-Bus sam w sobie nie izoluje tych operacji. Późniejsze przełączenie
na życzenie użytkownika, jego odbiór sprzętu i końcowe odczyty hosta
są osobnymi dowodami, opisanymi na końcu raportu.

Brak metadanych Git uniemożliwia wskazanie commita. Źródła potwierdzonej
regresji opisuje [SHA-256 204 plików runtime i testów](evidence/12-source-sha256.json).
Historyczny [stan przygotowania 208 plików](evidence/12-wayland-prepared-sha256.json)
poprzedza testy natywne i dwie naprawy produkcji.
[Manifest 250 źródeł](evidence/12-final-source-sha256.json) utrwala stan
po naprawach i odbiorze Waylanda; manifest zamknięcia etapu jest powyżej.

## Potwierdzone wyniki

Poniższa tabela zachowuje przebiegi z kolejnych części etapu, w tym wyniki
sprzed napraw; najnowsza regresja jest w sekcji zamknięcia powyżej.
Wszystkie polecenia wykonano z katalogu projektu. Testy z socketami wykonano
po ich dopuszczeniu poza sandboxem, zachowując prywatne środowisko.

| Polecenie / obszar | Wynik i dowód |
| --- | --- |
| `scripts/check` | **PASS**, 135 QML, 0 błędów; [log](evidence/12-check.log) |
| `scripts/test` | **PASS**, kod 0; 17 Python, 235 QtTest, 67,584 s części Qt, wszystkie 12 integracji; [log](evidence/12-tests.log) |
| Nowa ścieżka Qt | **13 PASS**: pełna klawiatura, bierne nakładki, wszystkie usługi niedostępne/powrót, osiem rozmiarów logicznych; [osobny przebieg](evidence/12-validation-qt-run4.log), następnie pełny zestaw |
| Diagnostyka runnerów | Rzeczywisty brak importu w 15 uruchomieniach: 12 integracji, preview, measure-idle i test. Niezerowy kod oraz źródłowy błąd QML, bez `JSONDecodeError`; część 17 testów Python |
| Workspace / IPC | Natywny parser Hyprlanda, Hyprlang i Lua, potwierdzanie akcji, hotplug protokołu i EOF; [Hyprlang](evidence/12-bar-hyprlang.log), [Lua](evidence/12-bar-lua.log) |
| Panele / ustawienia | Fokus, niszczenie, 20 cykli; FileView, uszkodzony/nowszy plik, odmowa zapisu, konflikt, restart/reload; [panele](evidence/12-panels-cycles.json), [ustawienia](evidence/12-settings-integration.json) |
| Audio / jasność | Prywatny PipeWire i Process: odczyt po zapisie, timeouty, stare odpowiedzi, restart, reload, niszczenie OSD; [audio](evidence/12-audio-integration.json), [jasność](evidence/12-brightness-integration.json) |
| Bateria / tray | Natywne UPower, SNI i DBusMenu na atrapach: brak/powrót usługi, overflow, podmenu, usuwanie klienta; [raport](evidence/12-status.json) |
| Sieć / Bluetooth | Natywne protokoły NM/BlueZ: radio/PSK, stabilne listy, błędy, późne odpowiedzi, utrata usługi, reload; [sieć](evidence/12-network.json), [Bluetooth](evidence/12-bluetooth.json) |
| Powiadomienia | Jeden właściciel prywatnej nazwy, akcje, DND, krytyczne, zalew, zastąpienia, zanik obserwatora i brak ujawnienia treści; [raport](evidence/12-notifications.json) |
| Sesja / Night Light | Kolejność blokada → potwierdzenie → suspend wyłącznie na atrapach; nieufny ScreenSaver odrzucony. Hyprsunset: protokół, restart, odmowa i odczyt potwierdzający; [sesja](evidence/12-session.json), [pulpit](evidence/12-desktop.json) |
| Wszystkie domeny razem | **PASS**, 20 cykli po cztery strony, monitor produkcyjnego IPC, hotplug atrapy, soft/hard reload przy otwartej sieci i szkicu kolorów; [raport](evidence/12-validation.json), [log](evidence/12-validation.log) |
| Renderowanie | **PASS offscreen**, 16 świeżych PNG, wszystkie otwarte i ocenione; [polecenia i wymiary](evidence/12-visuals/manifest.json), [log](evidence/12-visuals.log) |
| Kontrola końcowa | **PASS**, sumy 204 źródeł zgodne, składnia 24 plików Python, cele 271 lokalnych linków istnieją, procesy pomiarów i integracji zakończone; [log](evidence/12-final-review.log) |
| `scripts/check` po przygotowaniu odbioru natywnego | **PASS**, historycznie 138 QML, 0 błędów; [log](evidence/12-check-after-wayland-preparation.log). Później usunięto pomocnika zrzutów Qt, zastąpionego grim. |
| Regresja diagnostyki po przygotowaniu | **PASS**, 3 testy, 8,065 s; [log](evidence/12-runtime-after-wayland-preparation.log). Pełny zestaw 235 QtTest / 17 Python / 12 integracji to wcześniejszy przebieg powyżej. |
| Zatwierdzony start kompozytora | **PASS tylko środowiska**, po skróceniu prywatnego runtime działa odczyt monitora przez IPC i istnieje socket zdarzeń; [JSON](evidence/12-wayland-short-runtime.json). Brak uruchomienia UI Putkin. |
| Końcowy `scripts/check` | **PASS**, 137 QML, 0 błędów; [log](evidence/12-check-final.log) |
| Końcowy `scripts/test` po naprawach | **PASS**, kod 0; 17 Python (8,875 s), 235 QtTest (67,441 s), wszystkie 12 integracji; [log](evidence/12-tests-final.log) |
| `scripts/test-wayland --nested --idle` | **PASS**, 127,754 s, 18 zrzutów, wszystkie kontrole natywne poniżej; [JSON](evidence/12-wayland-run13/report.json), [log](evidence/12-wayland-run13.log), [sprzątnięcie](evidence/12-wayland-run13/cleanup.json) |
| Końcowy przegląd źródeł i dokumentów | **PASS**, 250 plików w manifeście, składnia 37 skryptów Python, cele lokalnych linków istnieją; [log](evidence/12-completion-review.log) |

Raporty domen z końcowej regresji skopiowano z katalogu generowanego
do [archiwum końcowych integracji](evidence/12-final-integrations/manifest.json).
Wcześniejsze odnośniki w tabeli zachowują historyczny przebieg sprzed
dwóch napraw natywnego fokusu.

Przejście klawiaturą zaczyna się od wejścia do paska, aktywacji workspace
(i ponownego wejścia do paska, zgodnie z kontraktem), następnie obejmuje
Quick Settings → dwa akcenty i zapis → audio/jasność → PSK zawierające
`hjkl` → połączenie sparowanego urządzenia → DND i krytyczny toast →
anulowanie Power. Fokus wraca na przycisk paska. Osobny przypadek
potwierdza, że OSD i toast pozostawiają wpisywanie `hjkl` w polu tekstowym.
Powyższy QtTest został następnie uzupełniony rzeczywistym wejściem do
osobnego procesu w kompozytorze, opisanym poniżej.

Po zaniku NM lub BlueZ backend Quickshell 0.3.1 wymaga restartu procesu,
zgodnie z istniejącymi kontraktami. Testy natywne potwierdzają diagnostykę
i ukrycie nieaktualnych danych; powrót atrapy QML nie znosi tej granicy API.

## Usunięte usterki i uzupełnienia

- Natywne `InteractivePanelWindow` i aktywny `NotificationWindow` używają
  `OnDemand` razem z `HyprlandFocusGrab`. `Exclusive` blokowało kliknięcie
  poza panelem i zakłócało wejście do powiadomień w Hyprlandzie 0.56.2.
  Test rzeczywistym wskaźnikiem i klawiaturą potwierdza zamknięcie/wyjście,
  a następnie wpisywanie do osobnej aplikacji. Pasywne toasty nadal mają
  `None`; nie zmieniono kontraktu skrótów ani publicznego IPC.
- Wspólne `ipc_reply` sprawdza proces i pierwotny log ładowania/reloadu
  przed interpretacją IPC. `ipc_json` odrzuca niepoprawną odpowiedź,
  zamiast zamieniać ją w pusty stan i kończyć mało użytecznym timeoutem.
  Wszystkie 12 integracji korzystają z tych funkcji. Log czytany przez
  `pread` nie przesuwa wspólnej pozycji zapisu procesu potomnego.
- Główny runner kończy się po błędzie Python/QtTest, drukuje log Qt od razu
  i ma limit 120 s dla rozbudowanego zestawu. Importy i ostrzeżenia QML
  nadal powodują błąd. Znane komunikaty celowych awarii usług pozostają
  widoczne i są sprawdzane przez istniejące, wąskie listy wyjątków.
- Dodano pełną kompozycję testową wszystkich domen, kontrolę skanowania
  przy przejściach między stronami oraz wspólny test reloadu i monitorów.
  Nowy test czeka również na zniszczenie widoków i zebranie procesów.
- Podgląd nie rozwija już automatycznie Bluetooth w obcych scenariuszach.
  Scenariusz `validation` ma 30 workspace, 40 ikon traya i długie nazwy.
  Macierz obrazu dzieli rozmiar fizyczny przez skalę przed renderowaniem;
  samo zwiększenie `QT_SCALE_FACTOR` przy stałym rozmiarze logicznym nie
  sprawdzałoby ciasnego ekranu HiDPI.
- Logi w podkatalogach `docs/evidence/` pozostają wersjonowalne.
  Publiczne IPC, format ustawień i zakres produktu nie zostały rozszerzone.

Historia prób: [pierwszy test w sandboxie](evidence/12-tests-initial.log)
pokazał odmowę socketów, w tym `denied` zamiast oczekiwanego braku backendu;
[przebieg z dopuszczonymi socketami](evidence/12-tests-baseline.log) miał
222 PASS Qt i komplet integracji. Pierwsza bramka nowego testu wyłapała
błędne nazwy metod/procentu; następne próby poprawiły oczekiwanie na fokus
oraz ponowne wejście do paska po aktywacji workspace. Nie zmieniano
produkcyjnej nawigacji, aby dopasować ją do testu. Pierwsza integracja
całości zbyt wcześnie sprawdzała `/proc` po SIGTERM;
[wynik](evidence/12-combined-initial-run.log). Dodano oczekiwanie na zebranie
własnych procesów. Końcowa regresja przeszła na ustalonych źródłach QML.

## Ocena wyglądu

Oceniono pełny pasek, pusty środek, Mocha, nieprzezroczyste powierzchnie,
kwadratowe rogi, obrys fokusu, oba akcenty i ograniczenie geometrii panelu.
Przy małej wysokości niższe sekcje przewijają się; QtTest potwierdza,
że kontrolka z fokusem jest widoczna. Duży tray nie wypycha zegara i wejścia
do panelu. Długie nazwy są skracane lub zawijane, a literalne znaczniki
w powiadomieniu nie są interpretowane jako HTML. Power zaczyna od Anuluj.

| Nominalne piksele | Skala 1 | Skala 1,25 | Skala 1,5 | Skala 2 |
| --- | --- | --- | --- | --- |
| 1920×1080 | [obraz](evidence/12-visuals/quick-1920x1080-1.png) | [obraz](evidence/12-visuals/quick-1920x1080-1.25.png) | [obraz](evidence/12-visuals/quick-1920x1080-1.5.png) | [obraz](evidence/12-visuals/quick-1920x1080-2.png) |
| 1366×768 | [obraz](evidence/12-visuals/quick-1366x768-1.png) | [obraz](evidence/12-visuals/quick-1366x768-1.25.png) | [obraz](evidence/12-visuals/quick-1366x768-1.5.png) | [obraz](evidence/12-visuals/quick-1366x768-2.png) |

Dodatkowo: [Mauve/Blue](evidence/12-visuals/settings-mauve.png),
[Teal/Peach](evidence/12-visuals/settings-teal.png),
[OSD audio](evidence/12-visuals/audio-osd.png),
[OSD jasności](evidence/12-visuals/brightness-osd.png),
[długi toast i ósma akcja](evidence/12-visuals/notification-long.png),
[Anuluj w Power](evidence/12-visuals/power-cancel.png),
[overflow](evidence/12-visuals/tray-overflow.png),
[brak Night Light](evidence/12-visuals/night-light-absent.png).
Przy 1366×768 i skali 1,5 wynik ma 1367 px szerokości wskutek zaokrąglenia
rozmiaru logicznego do 911 px. Manifest zachowuje wymiary rzeczywistych PNG.

To obrazy `grabToImage` z renderera offscreen, bez prywatnych treści.
Nie są zrzutami wyjść Waylanda. W tej macierzy nie porównywano całego
pulpitu z osobistą tapetą ani zewnętrznej blokady.

## Spoczynek, cykle i praca w tle

Pomiary wykonano **kolejno, po zakończeniu testów i renderów**, bez zmian
źródeł w trakcie. Każdy miał świeży proces, 2 s rozgrzewki, offscreen/software,
skalę 1, 1920×1080, 30 workspace i prawdziwy zegar minutowy. Próbki RSS/CPU
co sekundę zbiera zewnętrzny Python przez `/proc`; shell nie otrzymywał IPC
podczas właściwych 60 s. Baza `--panels` używa wspólnego okna podglądu bez
dołączonych sekcji domen; obiekty jego atrap nadal są tworzone. Nie jest
to pomiar samego fundamentu etapu 00 ani natywnych backendów produkcji.

```sh
scripts/measure-idle --panels --output docs/evidence/12-baseline-idle.json
scripts/test-validation-integration --idle --cycles 60 --output docs/evidence/12-combined-idle.json
```

| Próba | Czas / CPU shella | RSS shella | Procesy |
| --- | --- | --- | --- |
| Baza `--panels` | 60,000206 s; **0 ticków**, 0% jednego rdzenia | **98 004 → 98 132 KiB**, +128 KiB | Quickshell + prywatny dbus-run-session i dbus-daemon; 0 dzieci shella |
| Wszystkie domeny, zamknięty panel | 60,000132 s; **0 ticków**, 0% jednego rdzenia | **101 824 → 103 104 KiB**, +1280 KiB | Te same 3 procesy środowiska, 0 dzieci shella |
| 20 cykli w pełnej regresji | Interakcja; to nie pomiar spoczynku | **126 848 → 129 148 KiB**, min. 126 848, maks. 129 944 | 20 utworzonych / 20 zniszczonych powierzchni |
| Rozszerzenie do 60 cykli po pomiarze idle | Interakcja; to nie pomiar spoczynku | **129 936 → 131 012 KiB**, min. 129 936, maks. 132 788 | 60 utworzonych / 60 zniszczonych powierzchni |

Dowody: [baza JSON](evidence/12-baseline-idle.json),
[log pomiaru bazy](evidence/12-baseline-idle-run.log),
[wszystkie domeny i 60 cykli JSON](evidence/12-combined-idle.json),
[log pomiaru całości](evidence/12-combined-idle-run.log),
[log Quickshella](evidence/12-combined-idle.log).
Rozdzielczość licznika CPU wynosi 10 ms (100 ticków/s). Zero ticków oznacza
brak zarejestrowanego przyrostu, nie dowód absolutnie zerowej pracy.

W czasie idle stan przed i po był identyczny: zero scan/discovery i akcji
sesji, brak załadowanych paneli, OSD i toastów. Liczniki odczytów jasności
i Night Light pozostały **1 → 1** (odczyt startowy). Po 60 cyklach było
**60 scanStarts / 60 scanStops**, discovery nadal 0, **61** odczytów każdej
z tych dwóch domen (start + jedno otwarcie Quick Settings na cykl).
Nie wykonano operacji sesji. Potem routing IPC i reloady również przeszły;
końcowe RSS po tych dodatkowych operacjach wyniosło **136 848 KiB** i jest
oddzielone od serii cykli. Po sprzątnięciu raport potwierdził 0 żywych PID-ów.

W bazowym teście samych paneli RSS zwiększył się o 5824 KiB, a po pierwszych
20 cyklach całości o 2300 KiB. Dlatego zbadano dłuższą serię. Mediany RSS
kolejnych bloków 20 cykli: **131 234 / 131 332 / 131 200 KiB**; końce bloków:
**131 332 / 130 816 / 131 012 KiB**. Nie widać utrzymującego się wzrostu
w tej serii. Wynik jest zgodny ze stabilizacją po rozgrzaniu, ale bez
profilu sterty nie przypisujemy wszystkich różnic konkretnej pamięci cache.
Krótki test i liczniki zniszczonych widoków nie dowodzą braku wielogodzinnego
wycieku ani nie obejmują cache GPU.

Przegląd przyczyn pracy produkcji (opis kodu i integracji domenowych,
**nie pomiar całego produkcyjnego shella**):

| Źródło | Powód aktywności / zasady spoczynku |
| --- | --- |
| SystemClock | Jeden zegar, aktualizacja co minutę, współdzielony przez monitory |
| Hyprland / tray / PipeWire | Natywne zdarzenia; Hyprland ma dodatkowy wspólny socket obserwujący EOF, nie proces per monitor. Tracker audio obejmuje aktualne wyjście. Kontrolny timer audio działa po zapisie, nie w idle. |
| UPower / NM / BlueZ | Po jednym zdarzeniowym `gdbus monitor` na domenę do śledzenia właściciela; krótkie `busctl` po potrzebnym zdarzeniu/akcji, bez stałego pollingu |
| Wi-Fi / BT | Lease skanowania tylko dla widocznej listy; Bluetooth nie uruchamia discovery |
| Powiadomienia / sesja | Po jednym zdarzeniowym pomocniku Python. Powiadomienia obsługują metadane zastąpień; sesja obserwuje login1/Hypridle. Timery mają ograniczać oczekujące operacje, a nie odpytywać sprzęt. |
| Jasność / Night Light | Krótkie odczyty przy starcie, otwarciu, jawnej zmianie/odświeżeniu, jasność również po resume. Brak stałego procesu; throttle i deadline tylko podczas operacji. |
| FileView / panele / OSD / toasty | Watch pliku; odczyt po zapisie/zmianie. LazyLoader, krótki fade i timeout widocznych komunikatów. Zamknięte powierzchnie zwalniają zasoby. |
| Hypridle / Hyprsunset / Hyprlock | Zewnętrzni właściciele sesji. Putkin nie uruchamia drugiego hyprsunset; Hyprlock jest niezależny od reloadu shella. Nie działają w powyższym pomiarze atrap. |

## Natywny Wayland — wykonany odbiór UI

```sh
PUTKIN_GRIM=/tmp/putkin-grim/usr/bin/grim scripts/test-wayland --nested --idle --output docs/evidence/12-wayland-run13
```

**PASS**, kod 0, 127,754 s. [Pełny raport](evidence/12-wayland-run13/report.json),
[log przebiegu](evidence/12-wayland-run13.log),
[log Quickshella](evidence/12-wayland-run13/putkin.log),
[log kompozytora](evidence/12-wayland-run13/hyprland.log).
Scena `wayland-validation.qml` używa produkcyjnych okien, kontrolerów,
FileView i adaptera Hyprlanda; sprzęt i sesja mają jawne atrapy.
30 zajętych workspace i 40 klientów traya są syntetyczne, lecz zmiana
workspace, monitory, layer-shell, grab i wejście przechodzą przez protokoły
rzeczywistego kompozytora. Root produkcji nadal ma 95 linii.

Bubblewrap oddziela PID-y, sieć, `/dev`, `/run`, `/tmp`, XDG i D-Bus.
Udostępniono tylko zatwierdzony socket Waylanda rodzica i `renderD128`,
bez `card0`, urządzeń wejścia czy magistral sprzętu. Każde `hyprctl` ma
prywatną sygnaturę. Program grim 1.5.0-2 pochodzi z oficjalnego pakietu Arch,
rozpakowanego do `/tmp` po sprawdzeniu SHA-256 z lokalnej bazy; nie został
zainstalowany w systemie. [Pochodzenie pakietu](evidence/12-grim-package.json),
[suma executable](evidence/12-wayland-run13/capture-tool.json).

| Obszar | Potwierdzone zachowanie |
| --- | --- |
| Okna | Produkcyjne Bar/Wallpaper/Panel/OSD/NotificationWindow; jeden pasek i rezerwacja 32 logicznych px na wyjście. Panele mieszczą się w ekranie. |
| Pełna klawiatura | Workspace → Quick Settings → oba akcenty/zapis → audio/jasność → PSK z `hjkl` → sparowany BT → DND/krytyczny toast → anulowanie Power → fokus przycisku paska. Zero operacji sesji. |
| Grab i obce okno | Wirtualne kliknięcie poza panelem zamyka go; aplikacja w osobnym procesie otrzymuje dalszy tekst. Pasywne OSD/toasty nie przechwytują tekstu. Jawna nawigacja toastów kończy się przez Escape i kliknięcie poza stosem; toast pozostaje. |
| Tray | Klawiatura dociera do czterdziestej pozycji, przewija ją do widoku, otwiera podmenu i aktywuje liść dokładnie raz. |
| Skale | 1920×1080 i 1366×768 przy 1 / 1,25 / 1,5 / 2; rzeczywiste tryby zapisane w IPC. Dolna kontrolka jest osiągalna i odsłonięta. |
| Dwa monitory | HEADLESS 1920×1080 przy skalach 1 i 1,5 jednocześnie, oprócz wyjścia rodzica. IPC panelu i audio wybiera drugi skupiony monitor. |
| Hotplug | Usunięcie wyjścia podczas skanowania Wi-Fi, szkicu wyglądu, podmenu traya i potwierdzenia Power; okno i stan chwilowy zwolnione. Wyjście ponownie dodane w każdym przypadku. |
| Cykle / reload | 20 cykli po cztery strony; bilans widoków 37/37 i skanów 22/22 łącznie z wcześniejszą ścieżką. Soft/hard reload przy skanowaniu i szkicu; zapisane Teal/Peach zachowane, szkic odrzucony. |
| Sprzątnięcie | Wszystkie procesy potomne zakończone, wrapper zebrany, prywatny katalog usunięty; [JSON](evidence/12-wayland-run13/cleanup.json). Brak błędów QML. |

Tryby monitora używają `hyprctl -r`, aby bezczynne wyjście headless dostało
klatkę potrzebną do zastosowania reguły. Dla wymaganej macierzy włączono
**wyłącznie w prywatnej konfiguracji testowej** `debug:disable_scale_checks`:
1366×768 / 1,25 lub 1,5 daje ułamkowe wymiary logiczne i domyślny Hyprland
zastępuje skalę wartością 1. Nie obniżono asercji rzeczywistego trybu.
Po macierzy przywrócono kontrolę skal. API zweryfikowane w źródłach
[HyprCtl 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/debug/HyprCtl.cpp)
i [Monitor 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/output/Monitor.cpp).
Naprawę fokusu oparto na [WlrKeyboardFocus 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrKeyboardFocus/)
i [FocusGrab 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/protocols/FocusGrab.cpp).

### Obrazy natywne

Wszystkie **18 PNG otwarto i oceniono**. Zachowano Mocha, oba akcenty,
nieprzezroczyste powierzchnie, kwadratowe rogi i obrys fokusu. Mniejsze
obszary logiczne pokazują przewiniętą dolną część panelu; nagłówek poza
viewportem nie oznacza ucięcia okna. Długie etykiety są skracane/zawijane,
przepełniony tray nie usuwa zegara ani wejścia do panelu.
[Ocena, wymiary i sumy obrazów](evidence/12-wayland-run13/review.json).

| Tryb fizyczny | Skala 1 | Skala 1,25 | Skala 1,5 | Skala 2 |
| --- | --- | --- | --- | --- |
| 1920×1080 | [PNG](evidence/12-wayland-run13/quick-1920x1080-1.png) | [PNG](evidence/12-wayland-run13/quick-1920x1080-1.25.png) | [PNG](evidence/12-wayland-run13/quick-1920x1080-1.5.png) | [PNG](evidence/12-wayland-run13/quick-1920x1080-2.png) |
| 1366×768 | [PNG](evidence/12-wayland-run13/quick-1366x768-1.png) | [PNG](evidence/12-wayland-run13/quick-1366x768-1.25.png) | [PNG](evidence/12-wayland-run13/quick-1366x768-1.5.png) | [PNG](evidence/12-wayland-run13/quick-1366x768-2.png) |

Przy 1366×768 / 1,25 PNG grim ma **1366×767** wskutek przeliczenia
zaokrąglonego rozmiaru logicznego xdg-output. Monitor nadal ma 1366×768
przy skali 1,25; pełne metadane są w raporcie. Pozostałe wymiary są zgodne.
Przechwytywanie używa [udokumentowanego CLI grim 1.5.0-2](https://man.archlinux.org/man/grim.1.en).

Pozostałe widoki: [start](evidence/12-wayland-run13/initial-quick.png),
[bierne nakładki i osobna aplikacja](evidence/12-wayland-run13/passive-overlays.png),
[Mauve/Blue](evidence/12-wayland-run13/settings-mauve.png),
[Teal/Peach](evidence/12-wayland-run13/settings-teal-peach.png),
[Anuluj w Power](evidence/12-wayland-run13/power-cancel.png),
[pozycja 40](evidence/12-wayland-run13/tray-overflow-last.png),
[podmenu](evidence/12-wayland-run13/tray-submenu.png),
[pierwszy monitor](evidence/12-wayland-run13/mixed-first.png),
[drugi monitor](evidence/12-wayland-run13/mixed-second.png),
[OSD na drugim](evidence/12-wayland-run13/osd-second.png).
To całe prywatne wyjścia, bez treści hosta. Tło testu jest jednolitym Mocha;
osobistą tapetę zachowano przy późniejszym przełączeniu. Banery startowe kompozytora usunięto
prywatnym `dismissnotify`, pozostawiając pełny log diagnostyczny.
Hyprland raportuje niedostępny DRM/seat przed wyborem backendu Waylanda,
fallback kursora, ograniczenia zarządzania kolorem i zwolnienie przycisku
po zmianie graba. Te komunikaty nie zostały wyciszone. PASS dotyczy
sprawdzonych zachowań; nie oznacza pustego logu kompozytora ani odbioru CTM.

### Pomiar natywny

Świeży proces, 2 s rozgrzewki, dwa wyjścia, 30 workspace, 40 klientów traya,
wszystkie domeny, zegar minutowy, zamknięte panele. Przez **60,000024 s**
nie wysyłano IPC; klient wejścia i grim wystartowały dopiero później.
Pomiar poprzedzał końcowy lint i regresję, bez zmian QML w trakcie.
Użytkownik w tym przebiegu nie zmieniał fokusu ani workspace rodzica.

| Proces | Przyrost CPU | RSS KiB |
| --- | --- | --- |
| Putkin / Quickshell | **2 ticki**, około **0,033% jednego rdzenia** | **203 888 → 203 480**, −408 |
| Prywatny Hyprland | **57 ticków**, około **0,950% jednego rdzenia** | **147 796 → 147 796** |

100 ticków/s; odczyt `/proc` co sekundę. Quickshell ma jeden proces i zero
dzieci we wszystkich próbkach. Stan przed/po identyczny: brak skanowania,
discovery, paneli i operacji sesji, odczyty jasności/Night Light **1 → 1**.
Kompozytor, bwrap, D-Bus i runner należą do środowiska testowego; raport
CPU/RSS obejmuje shell i kompozytor, nie sumę całego hosta. Brak pomiaru
zajętości GPU lub pamięci VRAM. Praca Quickshella obejmuje zegar i zdarzenia
natywnych monitorów; atrapy nie dodają sprzętowych pomocników produkcji.

20 cykli po interakcjach i hotplug, już przy trzech wyjściach:
RSS **244 360 → 247 552 KiB**, zakres **244 360–248 352 KiB**.
Koniec cyklu 10: **247 584**, koniec 20: **247 552 KiB** (−32).
Mediany połówek: **246 284 / 247 704 KiB**. Wzrost całej serii +3192 KiB
wystąpił przede wszystkim podczas pierwszych dziesięciu cykli; końce
kolejnych dziesiątek nie pokazują dalszego wzrostu. Nie przypisujemy go
konkretnej pamięci cache bez profilu sterty. Krótki pomiar nie dowodzi
braku długotrwałego wycieku; dłuższa seria 60 cykli offscreen jest opisana
wyżej. [Próbki i podsumowanie](evidence/12-wayland-run13/review.json).

### Historia prób i granice wyniku

Pierwszy całkowicie prywatny Hyprland, bez GPU/wyświetlacza rodzica,
kończył się kodem 134 i brakiem alokatora; [log](evidence/12-wayland-attempt.log).
Następnie automatyczny przegląd odrzucił próbę z socketem rodzica/GPU.
Użytkownik zatwierdził start 12 s; skrócenie runtime naprawiło zbyt długą
ścieżkę socketu zdarzeń; [wynik](evidence/12-wayland-short-runtime.json).
Szerszy test UI został osobno odrzucony, a następnie użytkownik wyraźnie
zatwierdził cały dalszy odbiór UI i konieczne powtórzenia do 10 minut.
Obie odmowy pozostają historyczne: [pierwsza](evidence/12-wayland-approval.txt),
[UI i późniejsza zgoda](evidence/12-wayland-ui-approval.txt).

Próby 1–4 korygowały inicjalizację 40 atrap traya, wyszukiwanie wyłącznie
widocznych wierszy podmenu, nazwę testowego IPC oraz odświeżanie trybów.
[Próba 5](evidence/12-wayland-run5.log) ujawniła niezamykający się panel;
[próba 6](evidence/12-wayland-run6.log) potwierdziła naprawę i ujawniła
odrzucenie skal 1366. [Próby 7](evidence/12-wayland-run7.log)
i [8](evidence/12-wayland-run8.log) sprawdzały brak wejścia do toastów;
po zmianie na OnDemand przejście i powrót wejścia przeszły.
Próby 9–12 wykryły niestabilny zapis klatek przez pomocnicze okno Qt
oraz błędny kierunek testowego wejścia do poziomego przycisku Wi-Fi.
Zrzuty zastąpiono grim, bez okna zależnego od widoczności wyjścia rodzica.
Użytkownik zgłosił zmiany fokusu, pełnego ekranu i workspace w trakcie
wcześniejszych testów; mogły wpływać na klatki i wejście. Nie przypisujemy
im automatycznie każdej wcześniejszej awarii. Końcowy przebieg 13 był
niezakłócany i zaliczył cały scenariusz na poprawionych źródłach.

## Odbiór użytkownika i pozostałe kryteria

2026-09-16, po przełączeniu aktywnej sesji na Putkin, użytkownik potwierdził
działanie regulacji jasności i audio, Bluetooth, Wi-Fi, baterii oraz monitorów.
Źródłem poniższego podstawowego odbioru sprzętu jest to zgłoszenie użytkownika.
Po podaniu skrótu Super+Shift+L i przycisku Blokada użytkownik potwierdził
także działanie blokady ekranu odpowiedzią „dziala”.
Następnie przekazał: „uśpienie i wybudzenie potwierdzone”; to źródło
podstawowego odbioru rzeczywistego suspend/resume.
Na pytanie, czy włączenie Night Light ociepla obraz, a wyłączenie przywraca
normalne kolory, odpowiedział: „Tak, włączenie i wyłączenie działa”.
[Zapis wszystkich potwierdzeń](evidence/12-user-acceptance.json).

| Obszar | Potwierdzony wynik i granice |
| --- | --- |
| Fizyczne audio/backlight/bateria/Wi-Fi/BT | **PASS — podstawowe działanie potwierdzone przez użytkownika**. Zgłoszenie nie obejmuje osobnych wyników unplug/replug, odmowy uprawnień, wszystkich wariantów PSK ani utraty/restartu usług; tych scenariuszy na sprzęcie nie oznaczono jako PASS. |
| Blokada ekranu | **PASS — podstawowe działanie potwierdzone przez użytkownika** po instrukcji użycia skrótu lub przycisku Blokada. Nie wskazano, którą ścieżkę uruchomienia sprawdzono; nie zaliczono obu niezależnie ani scenariuszy awarii PAM. |
| Uśpienie i wybudzenie | **PASS — podstawowe działanie suspend/resume potwierdzone przez użytkownika**. Zgłoszenie nie zawiera osobnego wyniku odświeżenia jasności po wznowieniu ani kolejności automatycznej blokady. |
| Integracja Hypridle / logind / uwsm | **PASS w wymaganym zakresie testowym**: 13 grup końcowej integracji, w tym brak suspend bez potwierdzonej blokady, odrzucenie spóźnionych odpowiedzi/obcego ScreenSaver, odmowy, anulowanie, wybór własnej sesji i pojedyncze odświeżenie jasności po resume. Na hoście produkcyjny adapter dodatkowo **potwierdził tożsamość Hypridle i własną aktywną sesję** przez sam odczyt; [dowód](evidence/12-closeout-session-owner.json). Nie wykonywano ponownie logout ani fizycznego wymuszania awarii. |
| Fizyczne monitory / GPU | **PASS — działanie monitorów potwierdzone przez użytkownika**. Nie podano szczegółowej macierzy hotplug/skal; pomiar VRAM, wszystkie sterowniki i wielogodzinna sesja pozostają niezweryfikowane. |
| Opcjonalny Night Light / tapeta | **PASS — użytkownik potwierdził wizualne włączanie i wyłączanie Night Light.** Końcowy odczyt adaptera: filtr aktywny, 4500 K, brak błędu; jednostka `active/running`, autostart `enabled`. Dotychczasowa czysta tapeta `Cloudsnight.jpg` jest aktywna po [przełączeniu](install.md); źródłowy obraz obejrzano, nie zawiera narysowanego UI. [Stan sesji](evidence/12-closeout-live.json), [wynik przeglądu tapety](evidence/12-closeout.json). |

Scenariusze sprzętu i sesji rozwijają kontrakty [audio](audio.md),
[jasności](brightness.md), [sieci](network.md), [Bluetooth](bluetooth.md),
[sesji](session.md) i [pulpitu](desktop.md). Powtarzalny odbiór natywnego UI:
[instrukcja testowania](testing.md#odbiór-natywny-w-prywatnym-waylandzie).
Końcowy odczyt hosta potwierdził jedną instancję Putkin, jej własność nazwy
powiadomień, jeden pasek z rezerwacją 32 px na aktywnym eDP-1 i brak błędów
konfiguracji Hyprlanda oraz QML; [log shella](evidence/12-closeout-live.log).
Nie zmieniano w tym odczycie sprzętu, ustawień ani stanu blokady.

**Etap 12 zakończony dla wskazanej wersji.** Wynik nie stanowi audytu PAM, pełnej macierzy
fizycznych urządzeń i sterowników, pomiaru VRAM ani wielogodzinnego testu
pamięci. Negatywne scenariusze usług i uprawnień przeszły na izolowanych
protokołach/atrapach, zgodnie z punktem 5 promptu. Ustawienie `enabled`
jednostki nie jest dowodem działania po kolejnym logowaniu.
Przełączono aktywną sesję i autostart na Putkin; lokalny rollback sprawdzono
w ramach [etapu 13](install.md). Jego przenośny instalator i odbiór przyszłej
sesji logowania pozostają oddzielnym, niewykonanym zakresem.
