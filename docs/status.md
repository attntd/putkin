# Status implementacji

## Repozytorium Git i wykluczenia AI — 2026-09-20

Zainicjowano repozytorium Git 2.55.0 na gałęzi `main`, bez commitów.
Na wyraźne polecenie użytkownika `.gitignore` wyklucza wyłącznie dodatkowe
materiały AI: `.agents/`, `.codex/`, `AGENTS.md`, `AGENTS.override.md`,
`docs/prompts/` i referencje `ChatGPT Image *.png` z katalogu głównego.
Testy, podglądy, roadmapy, dokumentacja techniczna i dowody pozostają
dostępne do wersjonowania; wcześniejsze reguły artefaktów zachowano.

- Kontrola zachowania Gita: **PASS**. Porównanie `git ls-files` przed i po
  zmianie potwierdziło wykluczenie dokładnie 32 plików AI (27 promptów,
  4 PNG i `AGENTS.md`), zachowanie pozostałych 2329 plików oraz wszystkich
  274 plików manifestu runtime. Cztery próby `git check-ignore` potwierdziły
  reguły konfiguracji agentów. `git symbolic-ref` zwraca `main`.
- `scripts/check`: **PASS**, 217 QML, 0 błędów; wykonano w tej sesji przed
  edycją `.gitignore`. Kod QML pozostał bez zmian.
- Nie wykonywano instalacji ani testów UI: zakres obejmuje metadane Gita
  i reguły ignorowania, bez zmiany zachowania shella.

## Wspólna instalacja launchera, fade i screenshota — 2026-09-20

**Wdrożone i aktywne: `20260920-155210-f60d99e92e0f`.** Po zakończeniu
obu równoległych prac użytkownik wznowił polecenie instalacji. Wydanie
zawiera zwarty launcher z podglądem, wspólny fade 200 ms bez opcji
ograniczania ruchu oraz naprawioną rejestrację reguły screenshota.
Zastępuje `20260920-144910-c522126acd2f`; 274 pliki runtime, 23 dodane lub
zmienione. Sumy plików animacji i poprawki screenshota odpowiadają
manifestom ich końcowych testów. [Zakres i sumy](evidence/combined-release-source.json),
[plan instalacji](evidence/combined-release-install-plan.json).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| Pełny `scripts/check` | **PASS**, 217 QML, 0 błędów; [log](evidence/combined-release-check.log). |
| Launcher z ukończonym fade | **62 PASS**, 0 FAIL, prywatne XDG/D-Bus i atrapy; [log](evidence/combined-release-launcher-qml.log). |
| Prywatny Wayland wspólnej wersji | **4 grupy PASS**, tekst/obraz, hjkl/Enter, przewijanie, maska wejścia i skala 1,5; [raport](evidence/combined-release-launcher-wayland/report.json), [log](evidence/combined-release-launcher-wayland-run.log), [sprzątanie](evidence/combined-release-launcher-wayland/cleanup.json). Obejrzano zrzuty tekstu i skali 1,5. |
| Walidacja paczki przez instalator | **PASS**, 137 QML bez błędów, 274 pliki zgodne ze sprawdzonymi źródłami; [przebieg](evidence/combined-release-activation-run.log). |
| Odbiór aktywnej sesji | **PASS**, jedna instancja PID 311941, `putkin.service active/running` w `session-graphical.slice`; powtórne `qs` zachowuje PID. Jeden właściciel powiadomień, pasek i tapeta na aktywnym eDP-1, osiem skrótów i jedno polecenie, pojedynczy Print dla Putkina; [raport](evidence/combined-release-activation.json). |
| Stan i konfiguracja | **PASS**, gotowość blokady/idle, zachowane Caffeinate „Praca w tle” oraz sumy settings.json, keyboard.json i launch.json. Log QML i konfiguracja Hyprlanda bez błędów ani ostrzeżeń; [log](evidence/combined-release-live.log). |

Zachowano pięć buildów, a `previous` wskazuje poprzednią aktywną wersję.
Powrót: `scripts/install --restore --activate`. Ta instalacja nie zmienia
implementacji runtime; publikuje ukończone wspólne źródła. Nie powtarzano
niezmienionych zestawów fade i screenshota: ich wyniki oraz wcześniejsze
nieudane przebiegi pozostają opisane poniżej. Pełny wspólny przebieg QtTest
nadal nie ma wyniku PASS; wykonano udokumentowaną regresję zakresów.

Testy wejścia i obrazu wykonywano na atrapach i prywatnym kompozytorze.
Na pulpicie sprawdzono instalację i gotowość usług, bez przechwytywania
treści użytkownika, odczytu schowka, PAM ani suspend/resume. Ocena
płynności na fizycznym ekranie pozostaje po stronie użytkownika.

## Roadmapa integracji Signala — 2026-09-20

**Plan gotowy; implementacja S00–S12 jeszcze nie rozpoczęta.**
Powstała [roadmapa Signala](signal/ROADMAP.md), 13 samowystarczalnych
promptów w `docs/prompts/signal/` i [status przekazania](signal/STATUS.md).
Każdy prompt powtarza decyzje użytkownika: Mocha i akcenty shella,
usługa uruchamiana/zatrzymywana z Putkinem, otwarcie rozmowy oraz
quick reply z powiadomienia. Kolejność obejmuje model historii,
parowanie, tekst, powiadomienia, raporty, media, zmiany wiadomości,
retencję, grupy, odbiór i wdrożenie. Odczytano istniejące źródła,
kontrakty i aktualną dokumentację API.

- Kontrola dokumentacji: **PASS**, 13 promptów z wymaganym kontekstem,
  zależnościami, zadaniami, odbiorem i przekazaniem stanu; lokalne
  odnośniki poprawne. [Raport](evidence/signal/roadmap/review.json).
- `scripts/check`: **PASS**, 217 QML, 0 błędów, exit 0.
  [Log](evidence/signal/roadmap/check.log).
- Testy zachowania integracji, instalacja, parowanie i próby z telefonem
  nie zostały wykonane — należą do przyszłych etapów, a nie do tworzenia
  roadmapy. Brak metadanych Git; bez deklaracji commita.

Następny krok: pełny [prompt S00](prompts/signal/00-audit-contracts.md)
w osobnej sesji, z katalogiem pracy `/home/attntd/projects/putkin`.

## Screenshot po przeładowaniu — 2026-09-20

**Wdrożone: `20260920-155210-f60d99e92e0f`; testy końcowe PASS.**
Usunięto wywołanie nieistniejącego `HL.LayerRule.remove()`.
`ScreenshotBackend` aktualizuje jedną nazwaną regułę przez `hl.layer_rule`;
po reloadzie Hyprlanda odtwarza ją zdarzenie `configreloaded`. Nakładka
nadal znika bez animacji kompozytora przed przechwyceniem PNG.
[Sprawdzone API wersji](development.md#screenshot--2026-09-20).

Dodano do istniejącego testu Waylanda dwa cykle soft reload, hard reload
Quickshella i reload konfiguracji Hyprlanda. Każdy wykonuje Print/Enter,
sprawdza piksele obrazu, schowek, sprzątanie, pojedynczy skrót Print
i brak ostrzeżeń. Przed poprawką ten sam test odtworzył `remove()` przy
pierwszym soft reloadzie: [log](evidence/screenshot-reload-baseline.log),
[runtime](evidence/screenshot-reload-baseline/screenshot.log).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 217 QML, 0 błędów; [log](evidence/screenshot-reload-check.log). |
| `tst_screenshot.qml` | **19 PASS**, 0 FAIL, 0 pominięć, prywatne XDG/D-Bus i atrapy; [log](evidence/screenshot-reload-qt.log). |
| `test_screenshot.py` | **9 PASS**, rzeczywisty pomocnik z atrapami narzędzi; [log](evidence/screenshot-reload-python.log). |
| Prywatny Wayland `--screenshot` | **13 grup PASS**, w tym sześć reloadów, czyste piksele przy włączonych animacjach, zapis i schowek, skala 1,25 oraz odłączenie monitora; [raport](evidence/screenshot-reload-wayland/report.json), [log](evidence/screenshot-reload-wayland.log). |
| Regresja klawiatury i ramek | **11 grup PASS**, oba reloady bez błędu screenshota, 16 pikseli GPU, brak duplikatów skrótów i 10 cykli Ustawień; [raport](evidence/screenshot-reload-keyboard-headless/result.json), [log](evidence/screenshot-reload-keyboard-headless.log). |
| Sprzątanie obu prób natywnych | **PASS**, usunięte prywatne katalogi i zebrane wrappery: [screenshot](evidence/screenshot-reload-wayland/cleanup.json), [klawiatura](evidence/screenshot-reload-keyboard-headless/cleanup.json). |

Weryfikacja ujawniła zależność testu klawiatury od rozmiaru okna
nadrzędnego: przy 941 × 565 px cień Ustawień zasłaniał górną ramkę
okna referencyjnego. Zachowano [pierwszą próbę](evidence/screenshot-reload-keyboard.log)
i [powtórzenie](evidence/screenshot-reload-keyboard-final.log). Runner używa
teraz prywatnego HEADLESS 1280 × 900, bez zmiany tolerancji pikseli.
Pierwsza próba nowego testu screenshota miała animowane okno odniesienia;
[zachowany log](evidence/screenshot-reload-before.log). Końcowy test
stabilizuje je przed ponownym włączeniem animacji i otwarciem nakładki.

Zmieniono adapter, sondę testową, testy natywne i dokumentację;
[manifest źródeł](evidence/screenshot-reload-source-sha256.json).
Nie uruchamiano pełnego shella na aktywnym pulpicie ani nie odczytywano
schowka użytkownika. Późniejsze wspólne wdrożenie z fade i launcherem
opisano powyżej.

## Stabilny fade bez opcji ograniczania ruchu — 2026-09-20

**Wdrożone: `20260920-155210-f60d99e92e0f`; do odbioru wizualnego użytkownika.**
Podczas implementacji nie przełączano instalacji na pulpicie; wspólne
wdrożenie opisano powyżej. Zmiana obejmuje wspólne
przejścia i ustawienia; równoległe zmiany logiki schowka zachowano.

Usunięto „Ogranicz ruch” z formularza, Theme i modelu ustawień. Starsze
pliki z booleanem `reducedMotion` nadal wczytują akcenty; dawna flaga jest
ignorowana i znika dopiero przy jawnym zapisie. Nawigacja przechodzi teraz
bezpośrednio z drugiego edytora koloru do resetu.

`FadePresentation`, używany przez `FadeScope` i `FadeColumn`, czeka na
gotową stronę i dwa kolejne niezmienione pomiary geometrii w aktualizacjach
klatek. Następnie odsłania całą złożoną powierzchnię przez **200 ms,
InOutCubic**. Nie animuje pozycji, wymiarów ani skali. Zagnieżdżone sekcje
wchodzą razem z rodzicem. Warstwa eliminuje przebijanie jednolitego tła
akcentu przez gradient, pozostaje przez czas widoczności i jest zwalniana
po zamknięciu. Rozwijana kolumna ma osobny margines na zewnętrzną ramkę
fokusu bez skalowania treści. Przygotowanie klatkowe kończy pracę po otwarciu.
Zamknięcie nadal natychmiast odłącza wejście.

Zmieniono komponenty fade, `Metrics`, hosty paneli/OSD/powiadomień,
gotowość strony w `PanelSurface`, model i widok ustawień oraz ich przykład,
atrapę sceny i testy. Test obrazu launchera czeka na pełną widoczność.
Przy dodatkowej regresji natywnej skorygowano historyczną liczbę skrótów
o istniejący Print Screen. [Manifest plików](evidence/fade-source-sha256.json).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 217 QML, 0 błędów; [log](evidence/fade-check.log). |
| Osiem zestawów QtTest na prywatnym XDG/D-Bus | **223 PASS**, 0 FAIL, 0 pominięć: [fade](evidence/fade-qt-fade.log), [ustawienia](evidence/fade-qt-settings.log), [wygląd](evidence/fade-qt-visual_contract.log), [panele](evidence/fade-qt-panels.log), [fokus](evidence/fade-qt-pointer_focus.log), [Quick Menu](evidence/fade-qt-quick_menu.log), [powiadomienia](evidence/fade-qt-notifications.log), [launcher](evidence/fade-qt-launcher.log). |
| GPU, prywatny Hyprland, skale 1 i 1,25 | **36 PASS** łącznie. Piksele przy opacity 0,25/0,5/0,75, zachowanie geometrii i ramki fokusu, gotowość, szybkie ponowne otwarcie oraz Quick Menu/Wi-Fi/Bluetooth/bateria i OSD; [1](evidence/fade-wayland-1/report.json), [1,25](evidence/fade-wayland-125/report.json). |
| `scripts/test-settings-integration` | **PASS**, rzeczywisty FileView, 11 grup, 20 zmian/reloadów, migracja obu dawnych wartości ruchu i zapis/restart; [raport](evidence/fade-settings.json). |
| `scripts/test-panels-integration` | **PASS**, rzeczywiste IPC/LazyLoader, 20 cykli, 0 pozostawionych widoków; [raport](evidence/fade-panels.json). |
| Pełny wspólny przebieg Qt | **NIEUKOŃCZONY** — limit runnera 240 s. Końcową regresję objętego zmianą zakresu wykonano osobnymi zestawami powyżej; [pierwszy log](evidence/fade-all-qt-initial.log). |
| Dodatkowy `test-keyboard-wayland` | **FAIL końcowej kontroli logu**, po przejściu scenariuszy okien, ustawień, skrótów i reloadów. Istniejący `ScreenshotBackend` przy reloadzie wywołuje nieistniejące `remove()` uchwytu reguły Lua. Ostrzeżenia zachowano, nie wyciszono; funkcji screenshot nie zmieniano w tym zakresie. [Log runnera](evidence/fade-keyboard-run.log), [log Quickshella](evidence/fade-keyboard-wayland/quickshell.log). |

Test pikseli przed poprawką wykazał **3 FAIL** dla trzech poziomów opacity;
[dowód regresji](evidence/fade-baseline.log). Próby pośrednie wykryły też
przeskalowanie przez rozszerzony `layer.sourceRect`; końcowe rozwiązanie
go nie używa. Porównanie geometrii/ramek/fill z renderowaniem bez warstwy
przechodzi na software i GPU. Software inaczej wygładza tekst do tekstury;
test koloru w czasie fade obejmuje tekst z tej samej złożonej warstwy.

Ten przebieg nie obejmował pełnego odbioru całego shella ani naprawy
niezależnego błędu screenshota; jego późniejszą poprawkę opisano
[powyżej](#screenshot-po-przeładowaniu--2026-09-20).
Wrażenie płynności na aktywnym pulpicie pozostaje do oceny
użytkownika po wspólnym wdrożeniu. [Kontrakt](design.md#stabilny-fade--2026-09-20),
[testy](testing.md#stabilny-fade--2026-09-20).

## Zwarta lista i podgląd schowka w launcherze — 2026-09-20

**Wdrożone: `20260920-155210-f60d99e92e0f`.** Po zakończeniu animacji
użytkownik wznowił instalację; wspólny odbiór opisano powyżej. Pod chipem
filtra pozostaje lista bez powtórzonego nagłówka. Historia bez filtra
zachowuje „Ostatnie”. Wiersz schowka ma 36 px i samą treść, bez ikony
oraz podpisu „Schowek”; wiersze aplikacji zachowują ikony.

Po prawej pojawia się kwadratowy podgląd do 320 × 320 px, wyrównany
do górnego brzegu launchera. Obraz zachowuje proporcje, tekst zawija się
i przewija. Wybór klawiaturą lub wskaźnikiem zmienia podgląd bez kopiowania;
Enter nadal kopiuje wybraną pozycję. `l` wchodzi do podglądu, `j/k`
przewija, `h`/Escape wraca. Ukrycie podglądu przy zwężeniu ekranu przywraca
fokus listy. Dla kwadratu mniejszego niż 160 px podgląd jest pomijany,
bez zwężania głównej listy. Nie dodano podpowiedzi ani tooltipów.

Zmiany obejmują LauncherView / nowy LauncherPreview, serwis, adapter QML
i istniejący pomocnik Python, geometrię PanelHost/PanelSurface oraz natywną
maskę wejścia. Dekodowany jest wyłącznie wybrany wpis; stare odczyty są
anulowane, a spóźnione odpowiedzi odrzucane. Podgląd tekstu ma limit 32 768
znaków; obrazy używają adresu data i wyłączonego cache. Kopiowanie nadal
zachowuje pełny wpis do 2 MiB. Brak dodatkowych plików treści i pollingu.
[Kontrakt](launcher.md#podgląd-schowka--2026-09-20).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| Bramka zmienionego zakresu `scripts/check …` | **PASS**, 13 QML, 0 błędów; [log](evidence/launcher-preview-scope-check.log). |
| `python3 -m unittest discover -s tests -p test_launcher.py -v` | **PASS**, 10 testów: prawdziwe cliphist, tekst/PNG, limity, błędne i usunięte ID, anulowanie/zebranie dekodera, bez kopiowania ani zapisu podglądu; [log](evidence/launcher-preview-python.log). |
| `scripts/test-launcher-integration` | **PASS**, 7 grup; produkcyjne Process/JSON, cliphist i Qt Image, prywatne watchery/wl-copy, proporcje obrazu, zmiana tekst ↔ obraz i sprzątanie; [raport](evidence/launcher-preview-integration.json), [log](evidence/launcher-preview-integration.log). |
| Końcowy `tst_launcher.qml` | **61 PASS, 1 FAIL**. Wszystkie nowe przypadki podglądu/listy/fokusu, w tym ukrycie podczas nawigacji, przechodzą. Istniejące porównanie pikseli pola `test_search_focus_colors_its_own_border` otrzymuje `#181825` zamiast `#1e1e2e`; [log](evidence/launcher-preview-qml.log). Wcześniejszy przebieg przed dalszymi zmianami fade miał 61/61 PASS, przed dodaniem przypadku zwężenia. |
| Prywatny Wayland `--launcher-preview` | **PASS**, 4 grupy: rzeczywiste hjkl/Enter, przewijanie, tekst/obraz, wyrównanie ramek, kliknięcie w podgląd, poza krótszą listą i w przerwę, skala 1,5; [raport](evidence/launcher-preview-wayland/report.json), [przebieg](evidence/launcher-preview-wayland-run.log). |
| Ocena zrzutów | Otworzono i sprawdzono [tekst offscreen](evidence/launcher-preview-text.png), [obraz natywny](evidence/launcher-preview-wayland/launcher-native-image.png) oraz [skalę 1,5](evidence/launcher-preview-wayland/launcher-native-scale-1.5.png). Końcowy runner czeka na pełną widoczność panelu przed zrzutem. |
| Sprzątanie natywnej próby | **PASS**, prywatny katalog usunięty i wrapper zebrany; [wynik](evidence/launcher-preview-wayland/cleanup.json). |

**Równoległa sesja animacji:** użytkownik potwierdził, że fade jest rozwijany
w osobnej sesji Codex. Nie zmieniano jej FadePresentation/FadeScope ani
testów fade. Wywołany pełny `scripts/check` obejmował wtedy 217 QML i zgłosił
`missing-property` w `components/FadePresentation.qml` — [log](evidence/launcher-preview-check.log).
Pełna regresja QML zgłosiła trzy błędy `Fade::test_group_pixels` i osiągnęła
limit runnera 240 s przed końcem — [log](evidence/launcher-preview-all-qml.log).
Nie zaliczamy tych przebiegów jako PASS całego projektu. Wyniki opisują
zastany stan podczas równoległych edycji; ich końcowy odbiór pozostaje
przy sesji animacji.

Wszystkie testy używały atrap i prywatnych XDG/D-Bus; natywna próba także
prywatnego kompozytora i wejścia. Nie odczytywano schowka użytkownika
i nie uruchamiano drugiego pełnego shella na jego pulpicie. Pierwsza próba
QtTest w sandboxie nie mogła utworzyć prywatnego socketu D-Bus; właściwe
przebiegi wykonano z tą samą izolacją po dopuszczeniu uruchomienia narzędzia.

### Próba instalacji i odroczenie — 2026-09-20

Po poleceniu „instaluj nową wersję” przygotowano paczkę na bazie aktywnego
wydania screenshot, z dziesięcioma zmianami runtime launchera i dotychczasową
implementacją animacji. Paczka zawiera 273 pliki;
[manifest i zakres](evidence/launcher-preview-package.json),
[różnice](evidence/launcher-preview-package.diff).

- Walidacja paczki: **136 QML PASS**, sumy plików zgodne;
  [log](evidence/launcher-preview-package-check.log).
- QtTest launchera na tej paczce: **62 PASS, 0 FAIL**;
  [log](evidence/launcher-preview-package-qml.log).
- Integracja launchera: **7 grup PASS**;
  [raport](evidence/launcher-preview-package-integration.json).
- Prywatny Wayland: **4 grupy PASS**, tekst/obraz, nawigacja, maska wejścia
  i skala 1,5; [raport](evidence/launcher-preview-package-wayland/report.json),
  [sprzątanie](evidence/launcher-preview-package-wayland/cleanup.json).
  Pierwszy przebieg wykrył wyścig z mapowaniem okna atrapy; runner czeka
  teraz na to okno przed otwarciem launchera.
- Ponowny pełny `scripts/check` w źródłach: **217 QML PASS**;
  [log](evidence/launcher-preview-install-check.log). Ten wynik nie zastępuje
  końcowego odbioru zachowania animacji.

Aktywacja nie przeszła kontroli logu: istniejący `ScreenshotBackend.configure()`
przy ponownym starcie wywołuje nieistniejące `putkin_screenshot_rule:remove()`
w Hyprlandzie 0.56.2. Instalator cofnął `current` i uruchomił poprzednią
wersję; także ona zgłasza to ostrzeżenie. Nie wyciszano go ani nie uznano
aktywacji za udaną. [Przebieg](evidence/launcher-preview-activation-run.log),
[stan po powrocie](evidence/launcher-preview-first-activation-rollback.json).

Użytkownik następnie poprosił o poczekanie na koniec prac nad animacjami.
Instalacji nie ponawiano. Odczyt z 15:28 UTC potwierdza jedną instancję
poprzedniego wydania, PID 299629, `putkin.service active/running`
w `session-graphical.slice`, gotowość blokady i idle oraz zachowane
Caffeinate „Praca w tle”; [stan](evidence/launcher-preview-deferred.json).

**Stan w chwili odroczenia:** poprawka reguły screenshot, test restartu,
sprawdzenie wspólnej wersji i instalacja pozostawały niewykonane. Późniejszą
naprawę oraz udane wspólne wdrożenie opisano w sekcjach powyżej.

## Screenshot — 2026-09-20

**Wdrożone i aktywne: `20260920-144910-c522126acd2f`.** Na polecenie
użytkownika przełączono działającą instancję przez `scripts/install --activate`.
Wydanie zastępuje `20260920-143123-526a551c6a9f` i zawiera 272 pliki runtime;
14 dodanych lub zmienionych plików obejmuje wyłącznie mechanizm screenshot.

Print oraz `:screenshot` otwierają lekki wybór na bieżącym monitorze.
Enter przechwytuje wycinek lub cały monitor, W — okno aktywne sprzed
wywołania, również przed launcherem. Q/Escape anuluje wybór bez PNG
i bez zmiany schowka. Po zatwierdzeniu nakładka znika, powstaje PNG,
obraz trafia do schowka i pojawia się natywny pływający podgląd.
Enter/F zapisuje do katalogu obrazów XDG, podfolder `Screenshots`;
Q/Escape zamyka podgląd, zachowując schowek. Plik tymczasowy jest usuwany.
Nie dodano podpowiedzi, tooltipów ani tekstów postępu/sukcesu.

Reguła bez animacji jest instalowana po rozpoznaniu Lua przez Hyprlanda
i odnawiana po reloadzie. Samo Component.onCompleted następowało za wcześnie;
test pikseli z aktywnymi animacjami wykrył resztkę przyciemnienia i potwierdził
naprawę. Backend używa rozłącznych opcji grim `-o`/`-g`. Model i okna są
oddzielone od poleceń; przed zatwierdzeniem nie działa pomocnik przechwycenia.
Odczyt poprzedniego katalogu skrótów dodaje nowy rekord bez utraty edycji.

Potwierdzone wyniki:

- `scripts/check`: **214 QML, 0 błędów** ([log](evidence/screenshot-check.log)).
- Pełna regresja QML: **560 PASS, 0 FAIL, 0 SKIP**
  ([log](evidence/screenshot-all-qml.log)); końcowy zestaw screenshota po
  doprecyzowaniu odłączonego monitora: **19 PASS**
  ([log](evidence/screenshot-qml.log)).
- Python: **9 PASS** dla przechwycenia, geometrii, zapisu, schowka, błędów
  i sprzątania procesu/pliku; **6 PASS** regresji skrótów z Print.
  [Screenshot](evidence/screenshot-python.log),
  [klawiatura](evidence/screenshot-keyboard-python.log).
- Prywatny natywny Wayland: **7 grup PASS**. Rzeczywiste Print, Q/Escape,
  przeciągnięcie wstecz, Enter/W/F, komenda wpisana do launchera, oryginalne
  okno, pływający podgląd z fokusem, dokładne wymiary i bajty PNG/schowka/
  zapisu, brak przyciemnienia także z animacjami, skala 1,25/ujemna pozycja
  monitora oraz odłączenie wybranego monitora. [Raport](evidence/screenshot-wayland/report.json),
  [przebieg](evidence/screenshot-wayland-run.log),
  [podgląd](evidence/screenshot-wayland/screenshot-preview.png),
  [zaznaczenie](evidence/screenshot-wayland/screenshot-region-selection.png).
- Pomiar runnera: **373 ms** od Enter do odczytanego podglądu pełnego
  1920×1080, razem z IPC/wtype i sprawdzeniem schowka. To pojedyncza próbka
  prywatnego kompozytora, nie benchmark użytkowej sesji. Test potwierdza
  brak pomocnika i prywatnego PNG podczas wyboru.
- Prywatne procesy oraz katalog usunięte: [cleanup](evidence/screenshot-wayland/cleanup.json).
- Aktywacja: **PASS**, paczka 135 QML bez błędów, sumy wszystkich 272 plików
  zgodne ze źródłami. Jedna instancja PID 284556, jeden właściciel powiadomień,
  `putkin.service active/running` w `session-graphical.slice`. Blokada i idle
  gotowe; zachowano Caffeinate „Praca w tle”. Konfiguracja Hyprlanda i log QML
  bez błędów. Adapter zastosował 8 skrótów i 1 polecenie; jedyny bare Print
  wskazuje `Putkin:screenshot`. [Odbiór](evidence/screenshot-activation.json),
  [przebieg](evidence/screenshot-activation-run.log),
  [log QML](evidence/screenshot-activation-live.log).

Podczas aktywacji usunięto poprzednie przypisanie samego Print do
`quickshell-de:screenshot-open` z konfiguracji Hyprlanda i jej źródła chezmoi.
Skróty Print z modyfikatorami pozostały bez zmian. Adapter nadal nie usuwa
cudzych przypisań samodzielnie. [Dokładna zmiana](evidence/screenshot-activation-config.diff).
Instalator zachował pięć buildów łącznie; powrót do poprzedniego runtime:
`scripts/install --restore --activate`.

Ograniczenia odbioru: nie przechwytywano prywatnych treści użytkownika ani
nie wykonywano uwierzytelniania PAM ani suspend/resume hosta. Okno
przecinające monitory i obrót ekranu mają testy geometrii na atrapach;
pełnej fizycznej macierzy różnych DPI nie wykonano. Zachowanie przechwycenia
sprawdzono na prywatnym kompozytorze; w aktywnej sesji sprawdzono start,
gotowość usług i rejestrację skrótów.

Pierwszy test offscreen w sandboxie nie mógł utworzyć prywatnego socketu
D-Bus ([log](evidence/screenshot-sandbox-dbus.log)); poprawny odbiór wykonano
z prywatnymi XDG/D-Bus poza tym ograniczeniem. Jego domyślna ścieżka logu
omyłkowo nadpisała historyczny `material-icons-qt.log`; historyczną wzmiankę
poniżej skorygowano, a istniejące pełne dowody regresji ikon pozostają.
Aktualne testy wskazują jawne osobne pliki wyników.

[Kontrakt](screenshot.md), [testy](testing.md#screenshot--2026-09-20),
[API i zależności](development.md#screenshot--2026-09-20).

## Domyślne qs, UWSM i pięć buildów — 2026-09-20

**Wdrożone; poniżej odbiór pierwszej instalacji.** `qs` uruchamia Putkina jako `putkin.service`
w `session-graphical.slice` UWSM. Autostart, skróty i IPC wskazują stałe
`~/.config/quickshell`, połączone przez `~/.local/share/putkin/current`
wtedy z buildem **`20260920-143123-526a551c6a9f`**. Usunięto 23 starsze katalogi
i ich archiwa aktualizacji; pozostało **pięć buildów łącznie**. Pierwsze
27 kopii plus nowy build zostało zredukowane do pięciu.

Dodano `scripts/install`, `scripts/_install.py`, `scripts/qs` oraz
`tests/test_install.py`. Instalator ma staging, walidację QML i sum,
atomową publikację, dry-run, prywatny `--destination`, `--source`, powrót
do poprzedniego buildu i automatyczną retencję. Aktualizacja aktywnej sesji
wymaga `--activate`, odmawia przy blokadzie, zachowuje Caffeinate i ma
powrót po błędzie startu. Nie zmienia ustawień ani nie instaluje pakietów.

Opublikowane **265 plików runtime** pochodzi z wcześniej działającego
`20260920-native-session-9a3db25af706`; jedyna zmiana to zachowanie
stałej ścieżki IPC w `scripts/lock-session`. Równoległa praca nad
Screenshot nie weszła do tej pierwszej instalacji; jej późniejszą aktywację
opisano powyżej.
Osiem plików konfiguracji live/chezmoi zmienia autostart, ścieżki skrótów
i referencję do istniejącego helpera SSH askpass. Stara konfiguracja
innego shella ma jedną kopię `~/.config/quickshell.previous`.
Launcher, dowiązanie konfiguracji i `putkin/launch.json` są zapisane także
w chezmoi. Wcześniejsze różnice Hyprlanda/Zen pozostają niezmienione.

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 214 QML, 0 błędów; [log](evidence/default-install-check.log). |
| `python3 -m unittest discover -s tests -p test_install.py -v` | **PASS**, 15 testów, 5,573 s; [log](evidence/default-install-tests.log). |
| Paczka do instalacji | **PASS**, 130 QML, 265 plików, porównanie ze sprawdzonym aktywnym wydaniem; [przygotowanie](evidence/default-install-prepare.log), [plan](evidence/default-install-plan.json). |
| Atomowość i powrót | **PASS** na prywatnych plikach: proces przerwany przed/po publikacji, błąd kopiowania/walidacji/startu, stary albo nowy kompletny runtime, rollback przez CLI i zachowane ustawienia. |
| Prawdziwe Quickshell CLI | **PASS** na małej atrapie offscreen: domyślny katalog, względne importy, brak duplikatu, stabilna tożsamość i brak automatycznego reloadu po zmianie linku. |
| Aktywny pulpit | **PASS**, PID 279522, jedna instancja i właściciel powiadomień, `putkin.service active/running`, slice UWSM; drugie `qs` zachowuje PID. Paski, tapety, Ustawienia, gotowość blokady/idle i skróty poprawne; Caffeinate „Praca w tle” zachowane. [Odbiór](evidence/default-install-activation.json), [log QML](evidence/default-install-live.log). |
| Retencja | **PASS**, 5 katalogów: bieżący, native-session, signal-chat, charging-material, bar-alignment. `current` i `previous` wskazują istniejące kompletne paczki. |

Test wykrył, że samo dowiązanie pliku `shell.qml` psuje względne importy;
zastąpiono je dowiązaniem całego katalogu. Pierwsza aktywacja wykryła
tekstową odpowiedź `qs list --json` przy braku wybranej instancji.
Automatycznie przywrócono działający poprzedni shell, bez usuwania buildów;
launcher używa teraz `list --all --json` i porównuje docelową konfigurację.
[Pierwsza próba](evidence/default-install-activation-initial.log),
[udane przełączenie](evidence/default-install-activation-run.log).
Początkowy check wykrył też błąd typu w równolegle edytowanym
ScreenshotBackend; po jego niezależnej korekcie check całego projektu
przeszedł. Nie wyciszano importów. Początkowy sandbox nie pozwalał
utworzyć prywatnego D-Bus; poprawny test wykonano poza tym ograniczeniem,
nadal na prywatnych XDG/D-Bus/offscreen.

**Granice odbioru:** nie wykonywano ponownego logowania, hasła/PAM,
fizycznego skanera ani suspend/resume. Sprawdzono działającą usługę UWSM
i kod autostartu, bez restartowania sesji. Na obcym koncie instalator
wymaga dołączenia autostartu do istniejącej konfiguracji Hyprlanda według
[instrukcji](install.md); automatycznej migracji dowolnego innego DE nie
realizowano. Nie powtarzano pełnej regresji niezmienionych widoków.
Brak dostępnych metadanych Git; bez deklaracji commita.

Aktualizacja: `scripts/install --activate`. Powrót:
`scripts/install --restore --activate`. Dawne polecenia odtwarzania z
usuniętych archiwów w historycznych sekcjach nie są już aktualne.

## Blokada i bezczynność w jednej instancji — 2026-09-20

**Wdrożone: `20260920-native-session-9a3db25af706`.**
Po odblokowaniu sesji przez użytkownika przełączono pulpit i autostart.
Wydanie zachowuje korektę Signal Chat z poprzedniej wersji.
Użytkownik wybrał zastąpienie Hyprlocka i Hypridle wspólną instancją
Quickshell dla paska, paneli, blokady i bezczynności.

`LockHost` używa WlSessionLock/Surface, `LockService` sprawdza secure i bieżący
wynik PAM; hasło i odcisk mają niezależne PamContext. Widok korzysta ze
wspólnych tokenów, pola Qt i glifu odcisku, bez podpowiedzi. IdleMonitor
zachowuje 180/300/360/900 s, przywracanie jasności i DPMS oraz oba tryby
Caffeinate. Automatyczny sen zachowuje SuspendThenHibernate; ręczne Uśpij
używa Suspend. Pomocnik D-Bus posiada ScreenSaver i inhibitor sleep/delay.
Protokół secure, numery żądań i wstrzymanie uwierzytelniania pilnują
kolejności lock-before-sleep. Auto-reload jest wyłączony podczas blokady;
awaria klienta pozostawia kompozytor zablokowany.

Wydanie zawiera własne pliki PAM. Hasło włącza absolutne
`/etc/pam.d/system-auth` (z limitami prób), pam_shells i pam_nologin;
omija dodatkowy fprintd z lokalnego system-local-login, żeby obie rozmowy
nie rywalizowały o skaner. Nie zmieniono systemowych plików PAM.
Usunięto zależności i pomocniki Hyprlock/Hypridle ze źródeł runtime.

Potwierdzone wyniki:

- `scripts/check`: **207 QML, 0 błędów**, [log](evidence/native-session-check.log).
- Prywatny natywny Wayland: **8 grup PASS**: błędne/poprawne hasło przez
  stos PAM wydania z izolowanym system-auth; odcisk/błąd/reset; hasło podczas
  skanowania; hotplug; reload po odblokowaniu; dim, DPMS potwierdzone w
  kompozytorze i restore; inhibitory; SuspendThenHibernate po secure;
  śmierć klienta bez odsłonięcia sesji.
  [Raport](evidence/native-session-wayland-release/report.json),
  [blokada](evidence/native-session-wayland-release/native-lock.png).
- Paczka: **265 plików**, 17 dodanych/zmienionych i 5 usuniętych względem
  aktywnego wydania; 6 konfiguracji zmienia tylko ścieżki wydania.
  Rollback, jego powtórzenie, zachowanie Caffeinate, ochrona późniejszych
  edycji i odmowa restartu zablokowanej sesji: **PASS** na plikach tymczasowych.
  [Plan](evidence/native-session-activation-plan.json),
  [test](evidence/native-session-package-test.log).

Pełna końcowa regresja: **30 testów Python, 542 QtTest i wszystkie 14
integracji PASS**, kod wyjścia 0. [Log](evidence/native-session-tests-final.log).
Nowa integracja sesji obejmuje 11 grup, w tym odnowienie dostępności snu
po zwolnieniu inhibitora bez otwierania UI.
[Raport](evidence/native-session-integration-final.json).
Pierwszy przebieg wykrył stare oczekiwanie fokusu w integracji paneli
(po dodaniu Caffeinate); poprawiono fixture. Wcześniej uzupełniono brakującą
ikonę w kopii testu diagnostyki importów. Błędów importów nie wyciszono.
Natywny DPMS wymagał inicjalizacji modułu Hyprlanda przed pierwszym timerem;
poprawiono to i sprawdzono rzeczywisty stan monitorów. Odbiór sprzętowy
wcześniejszego Hyprlocka nie stanowi odbioru nowego PAM Quickshell.

Nie wykonano hasła użytkownika, skanu fizycznym czytnikiem ani suspend/resume
hosta. Testy miały osobne XDG/D-Bus, prywatny compositor i zamaskowany PAM;
nie uruchomiono drugiego pełnego shella na aktywnym pulpicie.

Aktywacja **PASS**: jedna instancja Quickshell PID 265056, właściciel
powiadomień; ScreenSaver i inhibitor sleep/delay należą do jej pomocnika
sesji PID 265074. Hypridle `inactive/disabled`, jego wpis autostartu usunięty
także z chezmoi. Procesy Hyprlock/Hypridle nie działają. Paski, tapety,
Ustawienia, panele, launcher i skróty sprawdzone; konfiguracja Hyprlanda
i log QML bez błędów. Sumy 265 plików runtime potwierdzone. Ustawienia,
audio oraz istniejące różnice chezmoi/Zen zachowane.

Po zwolnieniu tymczasowego inhibitora aktualizacji `idle.ready=true`,
`idle.inhibited=false`, blokada gotowa i odblokowana. Zachowano Caffeinate
„Praca w tle”, więc `sleepInhibited=true` jest oczekiwane. Nie wykonywano
prób uwierzytelnienia ani snu na hoście.
[Aktywacja](evidence/native-session-activation.json),
[stan po przełączeniu](evidence/native-session-live.json),
[log](evidence/native-session-live.log).
Powrót po odblokowaniu sesji:
`/home/attntd/.local/state/putkin/update-20260920-native-session-9a3db25af706/restore`.
Skrypt zachowuje późniejsze edycje plików, przywraca poprzedni runtime,
konfigurację, autostart Hypridle i bieżący tryb Caffeinate.


## Signal: Chat bubble i Chat — 2026-09-20

**Wdrożone: `20260920-signal-chat-897d94e15725`.** Launcher
pokazuje `chat_bubble`; tray bez nieprzeczytanych również `chat_bubble`,
a z nimi `chat`. Oryginalne symbole Google mają ten sam obrys i viewport.
Kolor `Theme.text`, rozmiar, centrowanie i padding pozostają stałe.
Usunięto lokalny `putkin_signal.svg` i dodatkową kropkę uwagi Signala.

Signal Desktop 8.27.0 zachowuje SNI Active i zmienia IconPixmap, zamiast
zgłaszać NeedsAttention. Niewidoczny, zdarzeniowy `SignalTrayState` odczytuje
czerwone oznaczenie tej bitmapy; widoczna ikona jest zawsze wektorem.
Stan odpowiada oznaczeniu przekazywanemu przez Signal, bez czytania bazy
wiadomości. Wyłączenie oznaczenia w samym Signalu usuwa też źródło tej
informacji dla shella.

- `scripts/check` izolowanego pakietu i jego testów: **162 QML, 0 błędów**
  ([log](evidence/signal-chat-check-final.log)).
- Launcher, katalog wektorów i bateria/tray: **193 PASS, 0 FAIL, 0 SKIP**
  ([log](evidence/signal-chat-qml-final.log)). To trzy odpowiednie zestawy,
  nie pełna regresja projektu. Odbiór obejmuje stan Active, powtarzane
  przełączenia w obu kierunkach, nadmiar traya, kolor, geometrię i fokus.
- Prywatna integracja SNI/UPower/PPD: **9 grup PASS, 20 cykli**
  ([raport](evidence/signal-chat-integration-final.json)). Prawdziwe
  IconPixmap/NewIcon przełączają symbol bez zmiany statusu Active.
- Wszystkie **44 PNG z zainstalowanego Signala**, rozmiary 16/32/48/256,
  liczniki 1–9/9+: **42 PASS**, DPR 1,5, w tym 40 przejść do oznaczenia
  i z powrotem ([log](evidence/signal-chat-installed-assets.log),
  [sumy i wersja](evidence/signal-chat-installed-assets.json)).
- **83 oryginalne SVG** zgodne z manifestem Google; 84 symbole razem
  z Tether. Potwierdzono identyczną ścieżkę zewnętrzną obu dymków
  ([wynik](evidence/signal-chat-assets.json)).
- Pakiet **261 plików**: pięć zmienionych, dwa dodane, jeden usunięty.
  Osiem konfiguracji zmienia wyłącznie ścieżkę wydania. Przywracanie,
  powtórzenie i ochrona późniejszych edycji: **PASS**
  ([log](evidence/signal-chat-package-test-final.log),
  [plan](evidence/signal-chat-activation-plan.json)).

Równolegle powstają zmiany natywnej blokady i bezczynności. Pierwszy
`scripts/check` katalogu roboczego zgłosił trzy pliki: dwa tej migracji
oraz niejawny typ/wiązania Loadera traya ([log](evidence/signal-chat-check.log)).
Poprawiono własny Loader. Pakiet i testy izolowano na aktywnym wydaniu
z wyłącznie poprawką Signala; cudze zmiany zachowano w katalogu roboczym
([zakres i sumy](evidence/signal-chat-isolation.json)).
Wczesna próba Canvas wykazała rekurencyjne wejście z imageLoaded;
próbkowanie przeniesiono do onPaint, a ładowanie odroczono. Test pikseli
czeka na układ zamiast na kolejną, czasem już narysowaną klatkę; przy
fokusie pomija osobną, prawidłowo kolorową ramkę klawiatury.

Pierwsza próba aktywacji zatrzymała się przed zmianami, ponieważ włączono
Caffeinate „Praca w tle”, a poprzedni pomocnik wymagał trybu off
([log](evidence/signal-chat-activate-run.log)). Przełączenie odtwarza teraz
zastany tryb; sprawdzono wszystkie trzy tryby i ponowienie w testach
pomocnika. Ręczne przywrócenie zachowuje tryb z chwili wywołania,
a automatyczne przywrócenie po błędzie odtwarza stan sprzed przełączenia.

Testy używały prywatnych XDG i D-Bus oraz atrap. Nie wysyłano wiadomości,
nie otwierano profilu Signala, nie powtarzano całej macierzy Waylanda,
pomiaru idle ani sprzętu/PAM. Odbiór żywej wiadomości pozostaje niewykonany.

Odbiór aktywnej sesji: **PASS**. Jedna instancja **PID 243441** jest
właścicielem powiadomień; pasek 32 px, tapeta, Ustawienia, panele, launcher
i skróty działają. Log QML i konfiguracja Hyprlanda bez błędów; 261 plików
zgodnych z pakietem. Hypridle **PID 243433** aktywny; Caffeinate nadal
**background**, z blokadą usypiania. Ustawienia, klawiatura, audio,
konfiguracja blokady i istniejące różnice chezmoi/Zen zachowane.
Obejrzano [aktywny pasek](evidence/signal-chat-live-bar.png): Signal bez
nieprzeczytanych pokazuje jasny Chat bubble, wyśrodkowany w swoim polu.
[Odbiór](evidence/signal-chat-activation.json),
[log](evidence/signal-chat-live.log),
[przywrócenie](install.md#signal-chat-bubble-i-chat--2026-09-20).

## Oryginalna ikona ładowania i szersze pole — 2026-09-20

**Wdrożone: `20260920-charging-material-41a71d98cd09`.**
Poprzedni wariant z wewnętrznym piorunkiem nie odpowiadał intencji
użytkownika. Przywrócono oryginalne `battery_charging_20_2`, `30_2`, `50_2`,
`60_2`, `80_2`, `full_2`, z piorunkiem po prawej. Katalog zmienia wyłącznie
viewport: korpus ma wysokość **10 px** tak jak Battery Android. Jednorodna
skala zachowuje proporcje oryginalnego symbolu; pole SVG rozszerza się z
20 do **24 px**, a przycisk z 32 do **36 px**. Padding pozostaje 6 px
poziomo / 5 px pionowo. Usunięto osiem lokalnych ikon i generator nakładki.

- `scripts/check`: **196 QML, 0 błędów**
  ([log](evidence/charging-material-check-complete.log)).
- Pełna regresja QML: **529 PASS, 0 FAIL, 0 SKIP**
  ([log](evidence/charging-material-all-qml-complete.log)).
- Geometria, trzy formaty daty w dwóch locale i osiem poziomów baterii:
  **17 PASS** w skali 1 ([log](evidence/charging-material-alignment.log))
  oraz **17 PASS** przy 1,5 ([log](evidence/charging-material-scale-1.5.log)).
  Testy mierzą piksele korpusu, obecność zewnętrznego piorunka, szersze pole,
  równy padding i powrót do poprzedniej geometrii po odłączeniu.
- Bateria/tray: **46 PASS**, w tym wszystkie oryginalne warianty ładowania,
  aktywacja i nawigacja ([log](evidence/charging-material-status.log)).
- Prywatny Hyprland/GPU: **PASS smoke only**. Korpus przed i podczas
  ładowania zajmuje wiersze **10–19**; szerokość przycisku **32 → 36 px**.
  Zegar ma odstępy 9/10 px, dziewięć próbek gradientu przechodzi kontrolę.
  Brak pozostałych procesów. [Raport](evidence/charging-material-wayland-final/report.json),
  [ładowanie](evidence/charging-material-wayland-final/bar-charging.png),
  [rozładowanie](evidence/charging-material-wayland-final/bar-discharging.png).
  Pomiar geometrii odczytuje położenie po zakończeniu układania Row.
- **82 oryginalne SVG i ich ścieżki bez zmian**, zgodne z manifestem Google;
  katalog ma 84 symbole ([wynik](evidence/charging-material-original-assets.json)).
- Pakiet: **260 plików zgodnych ze źródłami**, sześć zmienionych plików,
  osiem usuniętych SVG. Osiem konfiguracji zmienia wyłącznie ścieżki wydania.
  Przywracanie, powtórzenie i ochrona późniejszych edycji: **PASS**
  ([log](evidence/charging-material-package-test.log),
  [plan](evidence/charging-material-activation-plan.json)).

Pierwsza pełna próba miała **528 PASS / 1 FAIL** w oczekiwaniu na fokus
Night Light. Osobne uruchomienie wykazało inny błąd fokusu tego samego
zestawu: `loaded` asynchronicznego Loadera nie oznacza jeszcze zakończenia
odroczonego `focusInitial`. Test `tst_desktop.qml` czeka teraz na rzeczywisty
początkowy fokus i zakończenie układania panelu, tak jak pozostałe testy UI.
Bez zmian kodu Night Light, wyciszania ostrzeżeń ani pomijania przypadków.
Osobny odbiór po poprawce: **18 PASS / 0 FAIL**
([log](evidence/charging-material-desktop-final.log)); pierwotne logi zachowano.
Kolejna pełna próba miała **528 PASS / 1 FAIL** w teście audio: po kliknięciu
wyjść odczytano jeszcze nieutworzony delegat słuchawek. Dodano oczekiwanie
na układ panelu i obecność tego delegata. Osobny odbiór: **22 PASS / 0 FAIL**
([log](evidence/charging-material-audio-final.log)). Usługi audio bez zmian.

Obejrzano podgląd offscreen i zrzut GPU. Wszystkie próby ładowania używały
atrap oraz prywatnych XDG/D-Bus. Nie podłączano fizycznej ładowarki,
nie powtarzano całej macierzy Waylanda, integracji protokołów, pomiaru idle
ani sprzętu/PAM.

Odbiór aktywnej sesji: **PASS**. Stary shell zatrzymano przed nowym;
jedna instancja **PID 231654** jest właścicielem powiadomień. Pasek 32 px,
tapeta, Ustawienia, fokus, panele, launcher i skróty działają. Hypridle
**PID 231646** aktywny, z potwierdzoną własnością ScreenSaver. Log QML
i konfiguracja Hyprlanda bez błędów, 260 plików zgodnych z pakietem.
Ustawienia, klawiatura, blokada, audio oraz istniejące różnice chezmoi
dotyczące Hyprlanda/Zen zachowane.
[Odbiór](evidence/charging-material-activation.json),
[log](evidence/charging-material-live.log),
[przywrócenie](install.md#oryginalna-ikona-ładowania-i-szersze-pole--2026-09-20).

## Centrowanie paska i stały obrys ładowania — 2026-09-20

**Wdrożone: `20260920-bar-alignment-221eccd10c8c`.**
Padding pola ikony był równy, lecz dolny separator 2 px wchodził do obszaru
centrowania. Treść paska jest teraz centrowana w 30 px nad separatorem:
SVG 20 px, padding poziomy 6 px i pionowy 5 px. Zegar centruje widoczny
obrys znaków, z zaokrągleniem do fizycznego piksela. Pomiar podglądu:
Bluetooth **8/6 → 7/7 px**, bateria **11/9 → 10/10 px**, zegar **11/10 →
10/11 px** (góra/dół do separatora). Różnica 1 px przy nieparzystej liczbie
rzędów pikseli tekstu pozostaje naturalnym skutkiem rasteryzacji.
[Pomiar](evidence/bar-alignment-pixels.json),
[podgląd](evidence/bar-alignment-preview.png).

Oficjalne Charging … 2 mają mniejszy rysunek od Battery Android, pomimo
identycznego pola SVG. Osiem lokalnych wariantów zachowuje ścieżkę Android
0–6/Full i poziom wypełnienia; ładowanie dodaje wewnętrzny piorunek z
przezroczystą szczeliną. Obrys i terminal nie zmieniają rozmiaru. Wektory
powstają lokalnie, z zachowaniem licencji Apache 2.0 Google.

- `scripts/check`: **196 QML, 0 błędów**
  ([log](evidence/bar-alignment-check-final.log)).
- Pełna regresja QML: **537 PASS, 0 FAIL, 0 SKIP**
  ([log](evidence/bar-alignment-all-qml-final.log)); obejmuje wszystkie
  **92 wektory**, geometrię sekcji i przejścia wszystkich poziomów baterii.
- Centrowanie, trzy formaty daty w dwóch locale oraz osiem poziomów
  ładowania: **17 PASS** w skali 1
  ([log](evidence/bar-alignment-qt.log)) i **17 PASS** w skali 1,5
  ([log](evidence/bar-alignment-scale-1.5-final.log)). Porównywane są
  rzeczywiste piksele i niezmienione wypełnienie poza obszarem piorunka.
- Prywatny Hyprland/GPU: **PASS smoke only**. Obrys baterii przed i podczas
  ładowania identyczny: `[1651,10,1669,19]`; zegar ma odstępy 9/10 px.
  Przeszły też dziewięć próbek gradientu i mapowanie okien; brak pozostałych
  procesów testu. [Raport](evidence/bar-alignment-wayland/report.json),
  [ładowanie](evidence/bar-alignment-wayland/bar-charging.png),
  [rozładowanie](evidence/bar-alignment-wayland/bar-discharging.png).
- Pakiet: **268 plików zgodnych ze źródłami**, osiem zmienionych oraz osiem
  dodanych SVG. Osiem konfiguracji zmienia wyłącznie ścieżki wydania.
  Przywracanie, powtórzenie i ochrona późniejszych edycji: **PASS**
  ([log](evidence/bar-alignment-package-test.log),
  [plan](evidence/bar-alignment-activation-plan.json)).

W pierwszej pełnej próbie jeden test odrzucił cienki `fingerprint` przy
20 px: 148 pikseli rysunku, maksymalne pokrycie 0,864, bez pikseli w pełni
kryjących. Poprawiono kryterium obecności, zachowując kontrolę pojedynczego
koloru wszystkich pikseli. Pierwsza próba geometrii przy DPR 1,5 wykazała
też obcięcie fizycznego zrzutu QtTest; powiększono scenę i dodano jawny
warunek granic. Końcowe wyniki powyżej uwzględniają obie poprawki testów.

QML, podglądy i prywatny Wayland korzystały z atrap oraz osobnych XDG/D-Bus.
Nie podłączano fizycznej ładowarki, nie powtarzano całej macierzy Waylanda,
integracji protokołów, pomiaru idle ani sprzętu/PAM.

Odbiór aktywnej sesji: **PASS**. Stary shell zatrzymano przed nowym;
jedna instancja **PID 226043** jest właścicielem powiadomień. Pasek 32 px,
tapeta, Ustawienia, fokus, panele, launcher i skróty przeszły odbiór.
Hypridle **PID 226035** aktywny, z potwierdzoną własnością ScreenSaver.
Log QML i konfiguracja Hyprlanda bez błędów, 268 plików zgodnych z pakietem.
Ustawienia, klawiatura, blokada, audio i istniejące różnice chezmoi
dotyczące Hyprlanda/Zen zachowane.
[Odbiór](evidence/bar-alignment-activation.json),
[log](evidence/bar-alignment-live.log),
[przywrócenie](install.md#centrowanie-paska-i-obrys-baterii--2026-09-20).

## Mniejsze ikony paska w kolorze zegara — 2026-09-20

**Wdrożone: `20260920-bar-icons-399655afcfb6`.**
Pole wektora na topbarze zmniejszono z 24 do **20 px**, z jednakowym
paddingiem **6 px** wewnątrz pola 32 px. Każda ikona ma stały kolor
daty i czasu, `Theme.text` / `#cdd6f4`, również przy połączeniu, DND,
wyciszeniu, niskiej baterii, niedostępności i otwarciu modułu. Dotyczy
też traya, jego oznaczenia uwagi, nadmiaru i strzałek workspace.
Stan nadal zmienia symbol. Korekta obejmuje sześć plików runtime.

- `scripts/check`: **195 QML, 0 błędów**
  ([log](evidence/bar-icons-check.log)).
- Kontrakt wizualny: **15 PASS**, w tym rzeczywiste jasne piksele sześciu
  otwartych modułów i stały kolor przy zmianie stanów usług
  ([log](evidence/bar-icons-visual.log)).
- Bateria/tray: **46 PASS**, w tym poziomy baterii, ostrzeżenia,
  centrowanie i aktywacja ([log](evidence/bar-icons-status.log)).
- Wszystkie wektory i geometria sekcji, skala 1,5: **94 PASS**
  ([log](evidence/bar-icons-scale-1.5.log)). Obejrzano
  [podgląd obok zegara](evidence/bar-icons-preview.png).
- Pakiet: **260 plików zgodnych ze źródłami**. Przywracanie ośmiu
  konfiguracji, powtórzenie i ochrona późniejszych edycji: **PASS**
  ([log](evidence/bar-icons-package-test.log)).

Odbiór aktywnej sesji: **PASS**. Jedna instancja **PID 220092** jest
właścicielem powiadomień; pasek, tapeta, Ustawienia, panele, launcher
i skróty działają. Hypridle **PID 220056** aktywny, posiada ScreenSaver.
Log QML i konfiguracja Hyprlanda bez błędów. Ustawienia, klawiatura,
blokada, audio oraz istniejące różnice chezmoi w Hyprlandzie i Zen
zachowane. [Plan](evidence/bar-icons-activation-plan.json),
[odbiór](evidence/bar-icons-activation.json), [log](evidence/bar-icons-live.log),
[przywrócenie](install.md#rozmiar-i-kolor-ikon-paska--2026-09-20).

Testy QML i podgląd używały atrap oraz prywatnych XDG/D-Bus. Nie powtarzano
całej regresji, osobnych integracji protokołów, izolowanego GPU ani pomiaru
idle. Nie uruchamiano sprzętu/PAM ani drugiego shella na aktywnym pulpicie.

## Material Symbols w całym shellu — 2026-09-20

**Wdrożone: `20260920-material-icons-229766e3f287`.**
Google Material Symbols Outlined zastępuje glify Font Awesome, Papirus,
bitmapy traya i przeliczanie luminancji w Canvas. Lokalny zestaw obejmuje
82 oficjalne SVG oraz dopasowane symbole Signal i Tether. Każda ikona ma
jeden kolor; domyślnie Catppuccin Mocha Text `#cdd6f4`. Antyaliasing
wygładza krawędzie. Znaczące stany zachowują role kolorów motywu.

Rozmiar i padding określa wspólny profil sekcji, bez wyjątków dla aplikacji:
pasek/launcher/kafelki 24 + 4 px, suwaki 24 + 6 px, listy/menu 20 + 4 px,
nagłówki powiadomień 24 + 6 px i OSD 24 + 4 px. Ikony są wyśrodkowane,
także Signal w trayu. Usunięto dodatkowe 2 px paddingu domyślnych kontrolek
Qt Basic. Nieznane aplikacje mają symbol funkcji/kategorii lub `apps`;
nieznane komunikatory `chat`. Menu zachowuje akcje, check/radio i strzałki.

- Wi-Fi: `network_wifi` oraz poziomy 1/2/3 bar; brak połączenia i wyłączone
  radio mają odpowiadające trójkątne symbole z tej samej stylistyki.
- Bateria: `battery_android_0`–`6`, `full` i `question`; ładowanie:
  `battery_charging_20_2`, `30_2`, `50_2`, `60_2`, `80_2`, `full_2`.
- Dzwonek: `notifications`, `notifications_unread`, `notifications_off`.
  DND ma pierwszeństwo. Wygaśnięcie toasta pozostawia nieprzeczytany wpis;
  otwarcie centrum oznacza historię jako przeczytaną. Nowa treść zastępująca
  przeczytany wpis ponownie zapala nieprzeczytane.

Walidacja:

- `scripts/check`: **195 QML, 0 błędów**
  ([log](evidence/material-check-final.log)).
- Pełna regresja QML po głównej zmianie: **506 PASS, 0 FAIL, 0 SKIP**
  ([log](evidence/material-all-qml-final.log)). Po końcowym uzupełnieniu
  mapy komunikatorów i menu: launcher **51 PASS**
  ([log](evidence/material-launcher-qml-final.log)), bateria/tray **46 PASS**
  ([log](evidence/material-status-qml-final.log)).
- Piksele wszystkich ikon i geometria siedmiu sekcji: odnotowano **93 PASS**
  w skali 1 (pierwotny surowy log nadpisano omyłkowo podczas testu screenshot;
  zachowany pełny odbiór obejmuje [regresję QML](evidence/material-all-qml-final.log)); po dodaniu `chat` **94 PASS**
  w skali 1,5 ([log](evidence/material-icons-scale-1.5-final.log)). Testy
  sprawdzają pojedynczy kolor z antyaliasingiem, obecność rysunku, zmianę
  koloru i równy padding. Menu dodatkowo sprawdza zmianę symbolu i aktywację.
- Natywny launcher: **6 grup PASS**
  ([wynik](evidence/material-launcher-integration.json)); UPower/SNI/DBusMenu:
  **9 grup PASS, 20 cykli** po końcowej zmianie menu
  ([wynik](evidence/material-status-integration-final.json));
  powiadomienia: **13 grup PASS, 20 cykli**, w tym stany dzwonka i odczytu
  ([wynik](evidence/material-notifications-integration.json)). Prywatne
  XDG/D-Bus i atrapy; brak wywołań sprzętu/PAM hosta.
- Prywatny Hyprland/GPU: **PASS smoke only**, produkcyjne okna i dziewięć
  próbek gradientu. [Raport](evidence/material-wayland/report.json),
  [obraz](evidence/material-wayland/initial-quick.png). Brak pozostałych
  procesów testu. Obejrzano również [launcher](evidence/material-launcher-preview.png)
  i [menu Signal](evidence/material-tray-preview.png) w rendererze software.
- Pakiet: **260 plików zgodnych ze źródłami**. Osiem konfiguracji zmienia
  wyłącznie ścieżkę wydania. Przywracanie, jego powtórzenie i ochrona
  późniejszych edycji przeszły na plikach tymczasowych
  ([log](evidence/material-icons-package-test.log),
  [plan](evidence/material-icons-activation-plan.json)).

Odbiór aktywnej sesji: **PASS**. Stary shell zatrzymano przed nowym;
działa jedna instancja **PID 216450**, będąca właścicielem powiadomień.
Pasek 32 px, tapeta, fokus, okno Ustawienia, panele, launcher i skróty
działają. Hypridle **PID 216419** jest aktywny i posiada nazwę ScreenSaver.
Log QML i konfiguracja Hyprlanda bez błędów; opublikowane 260 plików
zgadza się z manifestem. Ustawienia, klawiatura, konfiguracja blokady
i stan audio zachowane. Istniejące różnice chezmoi w `hyprland.lua`
i motywie Zen pozostawiono bez zmian.
[Odbiór](evidence/material-icons-activation.json),
[log QML](evidence/material-icons-live.log),
[przywrócenie](install.md#material-symbols--2026-09-20).

Nie powtarzano pełnej macierzy GPU/skali, pomiaru idle, uwierzytelniania
ani pozostałych integracji sprzętowych. Całą regresję QML wykonano przed
ostatnimi dwoma uzupełnieniami mapy ikon; ich widoki sprawdzono oddzielnie.
Glif odcisku w zewnętrznym Hyprlocku pozostaje częścią osobnego kontraktu
blokady. Ten zakres dotyczy ikon UI Quickshell i nie rozszerza instalatora.

## Glif odcisku wewnątrz pola hasła — 2026-09-20

**Wdrożone: `20260920-fingerprint-603608293d62`.**
Ekran blokady nadal rysuje Hyprlock 0.9.6. W polu hasła, po lewej stronie
wewnątrz ramki, dodano `md-fingerprint` z JetBrainsMono Nerd Font Mono.
Catppuccin Mocha: wyjściowy Subtext0 `#a6adc8`, sukces Green `#a6e3a1`,
błąd Red `#f38ba8` i powrót po 2 s. Kolejny błąd odnawia czas; sukces
pozostaje do zniknięcia ekranu. Glif jest widoczny przy długim haśle.
Nie dodano podpowiedzi ani komunikatów.

Hyprlock tej wersji nie udostępnia etykietom zmiennej sukcesu. Mały
pomocnik, działający tylko podczas blokady, obserwuje fprintd i odświeża
glif przez SIGUSR2. Nie weryfikuje odcisków, nie czyta haseł i nie wywołuje
PAM; uwierzytelnianie oraz odblokowanie pozostają w Hyprlocku.
[Kontrakt, API i cykl życia](session.md#glif-odcisku--2026-09-20).

- `scripts/check`: **194 QML, 0 błędów** ([log](evidence/fingerprint-check.log)).
- Python: **5 PASS** ([log](evidence/fingerprint-python.log)). Produkcyjny
  launcher, prywatny D-Bus, wszystkie obsługiwane błędy, realny timeout,
  ponowienie, sukces, obcy nadawca, utrata/powrót fprintd, duplikat startu,
  przetrwanie zakończenia rodzica i usunięcie stanu po końcu lockera.
  Brak busa/importów nie zatrzymuje lockera; jego kod wyjścia jest zachowany.
  Polecenie etykiety czyta literalne ścieżki ze spacjami i metaznakami.
- Integracja sesji: **13 grup PASS, 20 cykli**, brak żywych procesów atrap
  ([wynik](evidence/fingerprint-session.json), [log](evidence/fingerprint-session.log)).
- Rzeczywisty Hyprlock w prywatnym Waylandzie: **PASS**. Piksele potwierdzają
  [glif wyjściowy](evidence/fingerprint-wayland/fingerprint-idle.png),
  [60 znaków hasła bez nakładania kropek](evidence/fingerprint-wayland/fingerprint-typed.png),
  [czerwień](evidence/fingerprint-wayland/fingerprint-error.png),
  [reset](evidence/fingerprint-wayland/fingerprint-reset.png) i
  [zieleń podczas natywnego fade 120 ms](evidence/fingerprint-wayland/fingerprint-success.png).
  Odblokowania nie opóźniano. [Raport](evidence/fingerprint-wayland/report.json),
  [log Hyprlocka](evidence/fingerprint-wayland/hyprlock-fingerprint.log),
  [sprzątanie](evidence/fingerprint-wayland/cleanup.json). Nie pozostały procesy.

Pierwsze próby ujawniły błędną ścieżkę w atrapie fprintd oraz zbyt ścisły
próg pikseli nieuwzględniający antyaliasingu glifu; oba testy poprawiono.
Usunięto też kolizję naszego i natywnego odświeżenia po błędzie przez
jednorazowe opóźnienie 60 ms. Końcowy log zachowuje oczekiwane odrzucenie
przez testowy PAM przy kończeniu lockera, bez ostrzeżeń odświeżania etykiet.

Na polecenie „wdrażaj” opublikowano **171 plików runtime**, zgodnych ze
sprawdzonymi źródłami. Względem działającego wydania
`20260920-monochrome-icons-126a9cb93feb` zmieniły się cztery pliki blokady.
Zaktualizowano ścieżki wydania w ośmiu konfiguracjach pulpitu i chezmoi,
w tym skrót blokady i `lock_cmd` Hypridle, które wskazywały starszy launcher.
Stary shell zatrzymano przed nowym; działa jedna instancja **PID 201212**,
będąca właścicielem powiadomień. Po restarcie Hypridle **PID 201167**
potwierdzono działanie usługi i własność nazwy ScreenSaver.

Odbiór aktywnej sesji: **PASS** — pasek, tapeta, Ustawienia, panele i skróty.
Konfiguracja Hyprlanda, log QML i bieżący dziennik Hypridle bez błędów.
Ustawienia, klawiatura, konfiguracja uwierzytelniania i stan audio zachowane.
Pozostawiono wcześniejszą lokalną regułę fokusu Zen oraz wynikające z niej
`MM .config/hypr/hyprland.lua` w chezmoi. Przywracanie ośmiu konfiguracji,
jego powtórzenie i ochrona późniejszych edycji przeszły na plikach tymczasowych.
[Plan](evidence/fingerprint-activation-plan.json),
[pakiet i przywracanie](evidence/fingerprint-package-test.log),
[odbiór](evidence/fingerprint-activation.json),
[ścieżki uruchamiania blokady](evidence/fingerprint-lock-entrypoints.json),
[log QML](evidence/fingerprint-live.log),
[dziennik Hypridle](evidence/fingerprint-hypridle.log),
[powrót](install.md#glif-odcisku--2026-09-20).

Nie testowano fizycznego skanera ani hasła/PAM aktywnej sesji, pełnej
macierzy skal czy ponownego logowania. Nie powtarzano pełnej regresji
wszystkich domen ani pomiaru idle. Przy ograniczonym ruchu Hyprlock znika
natychmiast; wskaźnik nie zatrzymuje odblokowania dla prezentacji zieleni.
Zakres uzupełnia integrację etapu 10, bez własnego lockera w Quickshellu
i bez rozszerzania instalatora.

## Jasne ikony i wyśrodkowany Signal — 2026-09-20

**Historyczny wariant, zastąpiony powyższym zestawem Material Symbols.**
Ikony aplikacji w launcherze oraz Signal w trayu są jasne i monochromatyczne.
Wspólny `ApplicationIcon` zachowuje różnice luminancji, proporcje i alfa;
nie spłaszcza logotypów do jednolitej sylwetki. Inne aplikacje w trayu
zachowują kolory. Signal jest rozpoznawany również po ID
`Signal_status_icon_1`, gdy tytuł jest pusty, jak w aktywnej sesji.
Przyczyną przesunięcia było 20 px ikony w 16 px pola pozostałego po paddingu.
Przyciski bez etykiet mają teraz padding 0 i wyśrodkowany obraz oraz fallback.

- `scripts/check`: **194 QML, 0 błędów**
  ([log](evidence/monochrome-check-final.log)); końcowe zmiany testów:
  **3 QML, 0 błędów** ([log](evidence/monochrome-check-tests.log)).
- Launcher QML: **47 PASS** ([log](evidence/monochrome-launcher-qml.log));
  bateria/tray QML: **29 PASS** ([log](evidence/monochrome-status-qml.log)).
  Piksele potwierdzają neutralną szarość, jasność, detale i przezroczystość;
  centrowanie obrazu i glifu, Signal po tytule/ID oraz kliknięcie.
- Skala **1,5**: po **5 PASS** w testach obrazu launchera i traya
  ([launcher](evidence/monochrome-launcher-qml-scale.log),
  [tray](evidence/monochrome-status-qml-scale.log)). QtTest przechwytuje
  piksele fizyczne; test uwzględnia DPR i zakres swojego zrzutu.
- Integracja launchera: **6 grup PASS**
  ([wynik](evidence/monochrome-launcher-integration.json));
  natywne UPower/SNI/DBusMenu: **9 grup PASS i 20 cykli**
  ([wynik](evidence/monochrome-status-integration.json)). Rzeczywisty provider
  SNI ładuje IconPixmap i reaguje na zmianę tytułu Signal; testy używają
  prywatnych XDG/D-Bus i atrap, bez sprzętu oraz sesji hosta.
- Obejrzano [podgląd](evidence/monochrome-preview.png) z prawdziwymi ikonami
  Papirusa i atrapą Signal. [Runner](evidence/monochrome-preview.py),
  [log](evidence/monochrome-preview.log). Renderowanie offscreen/software.
- Pakiet: **170 plików zgodnych ze źródłami**; przywracanie konfiguracji,
  jego powtórzenie i ochrona późniejszych edycji przeszły na plikach
  tymczasowych ([log](evidence/monochrome-icons-package-test.log)).

Nie powtarzano pełnej regresji wszystkich domen, osobnego odbioru GPU
w prywatnym Waylandzie ani pomiaru idle. Nie uruchomiono drugiego pełnego
shella na aktywnym pulpicie. Oficjalne API Qt 6.11.2 sprawdzono przed użyciem
([środowisko](development.md)); obrazy przeliczają się zdarzeniowo.

## Ikony aplikacji w launcherze — 2026-09-20

**Wdrożone: `20260920-launcher-icons-336f43911540`.**
Launcher wyświetla kolorowe ikony z pola `Icon` aplikacji przez natywnego
dostawcę Quickshell. Korzeń wybiera Papirus-Dark; motyw obejmuje również
ikony powiadomień w tym samym procesie. Obrazy mają pole 24 px, zachowują
proporcje i kolory, ładują się asynchronicznie. Puste lub nieznane źródło
pozostawia ogólny glif Nerd Font; ten sam glif jest widoczny podczas
ładowania i przy błędzie obrazu. Pliki, schowek i komendy zachowują glify.

- `scripts/check`: **PASS**, 193 pliki QML, 0 błędów
  ([log](evidence/launcher-icons-check.log)).
- QML launchera: **47 PASS, 0 FAIL, 0 SKIP**; piksele dwóch kolorów SVG,
  proporcje, fallback i Enter oraz dotychczasowe testy myszy, fokusu,
  filtrów, małego panelu, monitorów i komend ([log](evidence/launcher-icons-qml.log)).
- Integracja: **6 grup PASS**; prywatny motyw, natywne DesktopEntries
  i provider, nazwa ikony, ścieżka absolutna ze spacjami, brak i pusta
  ikona, stan renderowania, aktywacja, historia, schowek, reload i 20 cykli
  ([wynik](evidence/launcher-icons-integration.json), [log](evidence/launcher-icons-integration.log)).
- Python launchera: **7 PASS** ([log](evidence/launcher-icons-python.log)).
- Podgląd z rzeczywistym Papirusem **20260801-1**: Dolphin, Kitty i Zen,
  wyłącznie atrapy usług, prywatne HOME/XDG/D-Bus, offscreen/software;
  obraz obejrzany ([PNG](evidence/launcher-icons-preview.png),
  [log](evidence/launcher-icons-preview.log), [runner](evidence/launcher-icons-preview.py)).

Integracja wymaga qt6ct **0.11-8** z prywatną konfiguracją, ponieważ sam
offscreen zwraca wyłącznie ścieżkę ikon `:/icons`. Nie korzysta z konfiguracji
pulpitu użytkownika. API sprawdzono dla Quickshell **0.3.1** i Qt **6.11.2**;
odnośniki i zależności: [środowisko](development.md).
Nie uruchamiano pełnej regresji wszystkich domen, natywnego Waylanda
ani drugiej instancji pełnego shella na aktywnym pulpicie.

Na polecenie „wdrażaj” opublikowano 169 plików runtime; względem
poprzedniego wydania zmieniły się cztery pliki: widok, serwis, backend
launchera i deklaracja motywu w korzeniu. Pakiet odpowiada sprawdzonym
źródłom; test przywracania sześciu konfiguracji, powtórnego przywracania
i ochrony późniejszych edycji przeszedł na plikach tymczasowych.
Stary shell zatrzymano przed startem nowego. Odbiór aktywnej sesji:
**PASS**, jedna instancja PID 166730 i ten sam właściciel powiadomień,
pasek i tapeta, Ustawienia, panele, skróty i zwykły launcher.
Ustawienia, klawiatura i stan audio zachowane. Log QML, konfiguracja
Hyprlanda i chezmoi bez błędów. Poprawka fokusu Caffeinate pozostaje
w tym wydaniu. Nie sprawdzano ponownego logowania do sesji.
[Plan](evidence/launcher-icons-activation-plan.json),
[pakiet i przywracanie](evidence/launcher-icons-package-test.log),
[odbiór](evidence/launcher-icons-activation.json),
[log QML](evidence/launcher-icons-live.log),
[powrót](install.md#ikony-launchera--2026-09-20).

## Powrót fokusu w opcjach Caffeinate — 2026-09-20

**Wdrożone: `20260920-caffeinate-focus-5367ba0cec0c`.**
`QuickSettingsView.qml` odświeża listę kontrolek po `Repeater.itemAdded`
i `itemRemoved`, według istniejącego wzorca paneli baterii i zasilania.
Przy asynchronicznym tworzeniu panelu poprzednie odwołanie `upTarget`
mogło pozostać puste. `k` wraca teraz z „Pracy w tle” przez „Prezentację”
do Caffeinate i wyżej, przy nadal otwartych opcjach.

Regresja w `tests/qml/tst_quick_menu.qml` używa asynchronicznego Loadera
i rzeczywistych zdarzeń Qt: j/k, strzałki, Tab/Shift+Tab, rozmiary
1366×900 i 320×220 oraz po trzy cykle otwarcia. Sprawdza też brak
żądania zmiany trybu podczas nawigacji. Przed poprawką: **25 PASS,
2 FAIL**, oba błędy odtwarzają powrót przez `k`
([log](evidence/caffeinate-focus-before.log)). Po poprawce: **27 PASS,
0 FAIL, 0 SKIP** ([log](evidence/caffeinate-focus-after.log)).
Uruchomiono `qmltestrunner -input tests/qml/tst_quick_menu.qml -import .`
przez `dbus-run-session`, z `scripts/_common.py:isolated_environment`,
prywatnymi XDG, atrapami i rendererem offscreen/software.
`scripts/check`: **PASS**, 193 pliki QML, 0 błędów
([log](evidence/caffeinate-focus-check.log)).

Lokalne `qmake6 -query QT_VERSION`: **6.11.2**. Sprawdzono oficjalne API
[Repeater](https://doc.qt.io/qt-6/qml-qtquick-repeater.html) i
[QtTest](https://doc.qt.io/qt-6/qml-qttest-testcase.html) dla Qt 6.11.2.
Nie uruchamiano pełnej regresji wszystkich domen ani osobnego testu
klawiatury na natywnym Waylandzie.

Na polecenie „wdrazaj” opublikowano 169 plików runtime; względem
poprzedniego wydania zmienił się tylko `QuickSettingsView.qml`.
Stary shell zatrzymano przed nowym. Odbiór aktywnej sesji: **PASS**,
jedna instancja PID 141443 i ten sam właściciel powiadomień, pasek
i tapeta na monitorach, otwieranie paneli, skróty oraz okno Ustawienia.
Ustawienia, klawiatura i stan audio zachowane; Caffeinate off. Log QML,
konfiguracja Hyprlanda i chezmoi bez błędów. Sześć konfiguracji Hyprlanda
i chezmoi zmienia wyłącznie ścieżkę wydania.
[Plan](evidence/caffeinate-focus-activation-plan.json),
[raport](evidence/caffeinate-focus-activation.json),
[log QML](evidence/caffeinate-focus-live.log),
[przywrócenie](install.md#fokus-caffeinate--2026-09-20).

## Ramki Hyprlanda zgodne z Shellem — 2026-09-20

**Wdrożone: `20260920-window-borders-48f2f2f6ecec`.**

Ramki są kwadratowe, mają 2 px i bieżące kolory motywu. Aktywna ramka
ma wspólne pole `(x/w+y/h)/2` od lewego górnego do prawego dolnego rogu;
nieaktywna używa Surface1. Dotyczy to także grup okien. Podgląd, anulowanie,
zapis i reload synchronizują motyw bez pollingu ani dodatkowego procesu.
Dziesięć próbek sRGB ogranicza różnicę interpolacji Oklab Hyprlanda.
Kąt 30° wynika z jego wag `sin(angle)` / `1-sin(angle)` i daje równy udział osi.

| Sprawdzenie | Wynik |
| --- | --- |
| `scripts/check` | **PASS**, 193 pliki QML, 0 błędów; [log](evidence/window-borders-check.log). |
| Qt / synchronizacja | **PASS**, 7 wyników; gotowość, brak duplikatów, podgląd/anulowanie/zapis, zewnętrzny plik, zachowanie ostatnich poprawnych kolorów, kontrast, reload i reconnect. [Log](evidence/window-borders-qt.log). |
| Natywny Wayland | **PASS**, 11 grup; rzeczywiste ramki, ustawienia, skróty, zapis, anulowanie, oba reloady i 10 cykli okna. 16 próbek GPU, maksymalna różnica 1,515/255 względem pola sRGB; kwadratowe narożniki sprawdzone pikselami. [Raport](evidence/window-borders-wayland/result.json), [log](evidence/window-borders-wayland-run.log), [sprzątanie](evidence/window-borders-wayland/cleanup.json). |
| Przegląd obrazu | Obejrzano [ramkę domyślną](evidence/window-borders-wayland/window-border-default.png); zachowano także [ramkę po zapisie](evidence/window-borders-wayland/window-border-saved.png). |
| Parser / rollback fragmentu | **PASS**, natywny parser sprawdził promień, szerokość, kolory i geometrię gradientu oraz powrót wartości bazowych. [Log](evidence/window-borders-config-test.log). |
| Pakiet / rollback wdrożenia | **PASS**, 169 plików zgodnych ze źródłami, prywatne XDG i Lua `config ok`; odtworzenie sześciu plików, powtarzalność i ochrona późniejszych edycji. [Log](evidence/window-borders-prepare.log), [plan](evidence/window-borders-activation-plan.json). |
| Aktywna sesja | **PASS**, jedna instancja PID 136740, ten sam właściciel powiadomień, ramki 2 px / rogi 0 / właściwe końce i kąt gradientu potwierdzone przez Lua. Pasek, tapeta, skróty, Ustawienia i panele działają; ustawienia oraz klawiatura zachowane, Caffeinate off. Konfiguracja, QML i chezmoi bez błędów. [Raport](evidence/window-borders-activation.json), [log](evidence/window-borders-live.log). |

Przełączenie obejmuje sześć konfiguracji Hyprlanda/chezmoi: nowe wydanie,
kolory bazowe i promienie 0, również w istniejącej regule okna sieci.
Stary proces zatrzymano przed nowym. Gaps, opacity, blur, cienie i tiling
nie zmieniły się. [Różnica](evidence/window-borders-config.diff),
[przywrócenie](install.md#ramki-hyprlanda--2026-09-20).

Pierwsze próby natywne wykryły brak rejestracji nowych komponentów
w `services/qmldir` oraz wymaganie przekazania funkcji do dispatchera Lua;
oba problemy naprawiono przed końcowym przebiegiem. Pierwsza asercja Qt
czytała starą kopię tablicy wywołań; końcowa obserwuje nową wartość.
Nie powtarzano pełnej regresji wszystkich domen ani pomiaru idle.
Testy używały prywatnego D-Bus, XDG i kompozytora, z atrapami sprzętu/PAM.

## Doprecyzowanie przekątnej i fokus całych wierszy — 2026-09-20

**Poprzednie wdrożenie: `20260920-diagonal-rows-16d3bbc8db65`.**

Gradient ma równy udział obu osi niezależnie od proporcji całej grupy.
Lewy górny róg to akcent główny, prawy dolny dodatkowy; pozostałe dwa
rogi są mieszanką 1:1. Usunięto dominację szerokości poprzedniej wersji,
która na szerokich panelach dawała prawie poziome przejście. To nadal
jedno pole dla całego paska lub panelu, także przy scrollu i resize.
Fokus jasności oraz temperatury obejmuje ikonę, suwak i wartość na całą
szerokość wiersza. Suwaki nie dorysowują własnych ramek. Mysz nadal ukrywa
fokus, a standardowe wejście i nawigacja pozostają zachowane.

| Sprawdzenie | Wynik |
| --- | --- |
| `scripts/check` | **PASS**, 190 QML, 0 błędów; [log](evidence/diagonal-rows-check.log). |
| Regresja Qt | 372 PASS / 1 FAIL w pełnym przebiegu: stara asercja wymagała ramki wewnątrz suwaka jasności. Zmieniono ją na ramkę wiersza i brak obrysu suwaka; końcowy test jasności opisany poniżej. [Pełny log](evidence/diagonal-rows-qt-full.log). |
| Jasność po aktualizacji asercji | **PASS**, 26 testów, 9,422 s; klawiatura, pełna ramka, przeciąganie i scalanie żądań, utrata urządzenia oraz mały panel. [Log](evidence/diagonal-rows-brightness.log). Produkcyjny kod po pełnej regresji pozostał identyczny. |
| Nowe przypadki | **PASS**, 7 wyników gradientu, w tym grupa 520×32; Quick Menu 21 wyników, w tym trzy warianty wspólnej ramki; PointerFocus 34. Wczesna próba trzech nowych asercji błędnie używała forceActiveFocus na tym samym klikniętym elemencie zamiast klawiszy. Końcowe próby używają Tab/Backtab. [Pierwszy log](evidence/diagonal-rows-focused.log), [Quick Menu po korekcie](evidence/diagonal-rows-quick.log). |
| Python | **PASS**, 32 testy, 12,892 s; [log](evidence/diagonal-rows-python.log). |
| Natywny Wayland | **PASS**, 14 grup, 25 obrazów, 9 próbek GPU, 2 rozdzielczości × 4 skale, różne skale monitorów, hotplug, 20 cykli i oba reloady. [Raport](evidence/diagonal-rows-wayland/report.json), [sprzątanie](evidence/diagonal-rows-wayland/cleanup.json). |
| Odbiór obrazu | Obejrzano natywne ramki [jasności](evidence/diagonal-rows-wayland/brightness-row-focus.png) i [temperatury](evidence/diagonal-rows-wayland/temperature-row-focus.png). |
| Pakiet / rollback | **PASS**, 167 plików zgodnych ze źródłami, Lua config ok w prywatnym XDG, powtarzalne odtwarzanie sześciu plików i ochrona późniejszych edycji. [Log](evidence/diagonal-rows-prepare.log), [plan](evidence/diagonal-rows-activation-plan.json). |
| Aktywna sesja | **PASS**, jedna instancja PID 131347 i ten sam właściciel powiadomień, pasek 32 px, tapeta, skróty, Ustawienia, audio, centrum, launcher i Quick Menu. Ustawienia i klawiatura zachowane, Caffeinate off; chezmoi, konfiguracja i QML bez błędów. [Raport](evidence/diagonal-rows-activation.json), [log](evidence/diagonal-rows-live.log). |

Przełączenie zmieniło ścieżki wydania w trzech konfiguracjach Hyprlanda
i ich źródłach chezmoi. Stary proces zatrzymano przed nowym. Wszystkie
167 plików opublikowanego runtime nadal odpowiada źródłom.
[Różnica](evidence/diagonal-rows-config.diff), [przywrócenie](install.md#przekątna-i-fokus-wierszy--2026-09-20).

Nie zmieniano sprzętu ani PAM; testy korzystają z atrap i prywatnych
magistral. Nie powtarzano pomiaru idle. Ikona launchera pozostaje lupą
F002; użytkownik otrzymał [katalog Nerd Fonts](https://www.nerdfonts.com/cheat-sheet)
do wyboru symbolu z używanego fontu JetBrainsMono Nerd Font Mono
(lokalny pakiet 3.5.1-2).

## Gradient całych grup, ikony modułów i pole launchera — 2026-09-20

**Poprzednie wdrożenie: `20260920-accent-groups-be2213f6b4c0`.**

Pasek na każdym monitorze i każdy panel mają osobny, wspólny gradient
od lewego górnego do prawego dolnego rogu. Ramka, aktywne wypełnienia,
suwaki i fokus korzystają z jednego pola; przewijanie, resize i zmiana
palety zachowują spójność. Glify oraz uchwyty pobierają kolor ze swojego
położenia w grupie. Otwarty moduł Wi-Fi, Bluetooth lub baterii ma
akcentowe tło i kontrastową ikonę, czarną przy domyślnej palecie.
Pole launchera podświetla własną ramkę; kliknięcie nadal nie rysuje fokusu.

| Sprawdzenie | Wynik |
| --- | --- |
| `scripts/check` | **PASS**, 190 QML, 0 błędów; [log](evidence/accent-groups-check.log). |
| Pełna regresja Qt | **PASS**, 369 testów, 149,110 s, 0 błędów i pominięć; [log](evidence/accent-groups-qt-full.log). |
| Narzędzia Python | **PASS**, 32 testy, 12,941 s; [log](evidence/accent-groups-python.log). |
| Natywny Wayland / GPU | **PASS**, 14 grup, 23 zrzuty, 8 próbek RGB, 2 rozdzielczości × 4 skale, różne skale monitorów, hotplug, 20 cykli i oba reloady; [raport](evidence/accent-groups-wayland/report.json), [sprzątanie](evidence/accent-groups-wayland/cleanup.json). |
| Odbiór obrazu | Obejrzano [Quick Menu](evidence/accent-groups-wayland/initial-quick.png), [Wi-Fi](evidence/accent-groups-wayland/active-network.png), [baterię](evidence/accent-groups-wayland/active-battery.png) na GPU oraz [launcher](evidence/accent-groups-launcher.png) w podglądzie. |
| Pakiet i rollback | **PASS**, 167 plików zgodnych ze źródłami, prywatne XDG i Lua `config ok`, odtworzenie 6 plików, powtarzalność i ochrona późniejszych edycji; [log](evidence/accent-groups-prepare.log), [plan](evidence/accent-groups-activation-plan.json). |
| Aktywna sesja | **PASS**, jedna instancja PID 124179 i ten sam właściciel powiadomień, pasek 32 px, tapeta, skróty, Ustawienia, audio, centrum, launcher i Quick Menu. Ustawienia i klawiatura zachowane, Caffeinate off; chezmoi, konfiguracja i QML bez błędów. [Raport](evidence/accent-groups-activation.json), [log](evidence/accent-groups-live.log). |

Przełączenie zmieniło wyłącznie ścieżki wydania w trzech konfiguracjach
Hyprlanda i ich źródłach chezmoi. Stary proces zatrzymano przed nowym.
[Różnica](evidence/accent-groups-config.diff), [przywrócenie](install.md#gradient-grup-i-ikony-modułów--2026-09-20).

Pierwsza pełna regresja: 364 PASS / 5 FAIL. Cztery błędy menu ujawniły
wybór pozycji przed ukończeniem asynchronicznych delegatów Repeatera.
Menu czeka teraz na komplet pozycji, korzystając z istniejącej naprawy
fokusu i sygnału itemAdded. Test Klawiatury czeka na początkowy fokus
oraz odsłonięcie panelu przed wysłaniem klawiszy. [Pierwszy przebieg](evidence/accent-groups-qt-full-initial.log),
[punktowa regresja po naprawie — 38 PASS](evidence/accent-groups-focus-ready.log).

Pierwszy natywny odbiór zaliczył dotychczasowe interakcje, lecz przegląd
obrazu wykrył brak gradientu na GPU: przezroczysty fillColor pomijał
geometrię Shape mimo fillGradient. Aktywna ścieżka ma teraz nieprzezroczystą
bazę. Dodana kontrola ośmiu pikseli GPU zalicza wspólną przekątną panelu,
trzech kafelków i całego paska. [Początkowy obraz](evidence/accent-groups-wayland-initial/initial-quick.png),
[punktowy odbiór pikseli](evidence/accent-groups-gpu-pixels-final/report.json).

Testy używają prywatnych XDG/D-Bus i atrap; natywny odbiór działa
w osobnym compositorze. Nie powtarzano pomiaru idle ani sprzętowych
operacji radia, dźwięku, zasilania i PAM. Zakres to korekta istniejącego UI,
bez rozszerzenia etapów roadmapy ani przenośnego instalatora.

## Kafelki Quick Menu, Caffeinate i historia VoxType — 2026-09-20

**Poprzednie wdrożenie: `20260920-toggle-tiles-7a84bdec0b46`.**

Quick Menu ma dwie kolumny poziomych kafelków: Wi-Fi, Bluetooth,
Nie przeszkadzać, Światło nocne i Caffeinate. Usunięto oddzielne wejście
„Powiadomienia”. Temperatura z ikoną termometru pojawia się wyłącznie
przy włączonym świetle nocnym. Wyłączone przyciski podświetlają istniejącą
ramkę; włączone zachowują zewnętrzną. Mysz nie rysuje fokusu.

Caffeinate ma tryby Prezentacja i Praca w tle, listę przez `i`/prawy
przycisk, zatwierdzanie Enter i zwykłe on/off lewym przyciskiem.
Zachowanie i własność blokad opisuje [kontrakt](caffeinate.md).
VoxType 1.0.1 wysyła `int:transient:1`; wcześniejszy filtr usuwał takie
powiadomienia z historii. Teraz wszystkie transient pozostają w centrum
po timeout i przy DND, do limitu 100 kopii w pamięci sesji.

| Sprawdzenie | Wynik |
| --- | --- |
| `scripts/check` | **PASS**, 186 plików QML, 0 błędów; [log](evidence/toggle-tiles-check.log). |
| Zachowanie Qt | **PASS**, 359 testów, 135,345 s; początkowo 357 PASS / 2 FAIL. Naprawiono konflikt odzyskiwania fokusu po zaniku usług; kliknięcie Anuluj Wi-Fi synchronizuje się z odsłonięciem i renderowaniem przycisku. [Końcowy log](evidence/toggle-tiles-qt-full.log), [pierwszy przebieg](evidence/toggle-tiles-qt-full-initial.log). |
| Testy Python | **PASS**, 32 testy, 12,573 s; nowy runner podlega także testowi celowo brakującego importu. [Log](evidence/toggle-tiles-python.log). |
| Caffeinate / prywatny logind | **PASS**, 8 grup, 20 cykli, rzeczywiste FD, brak przerwy przy zmianie trybu, odmowa/timeout, EOF, utrata pomocnika/usługi, soft/hard reload i zamknięcie shella; wszystkie pomocniki zwolnione. [Raport](evidence/caffeinate-integration.json). |
| Powiadomienia / prywatny D-Bus | **PASS**, notify-send z dokładnymi flagami VoxType, syntetyczną treścią, zastąpieniem ID, wygaśnięciem i DND; 20 cykli oraz dotychczasowy zakres integracji. [Raport](evidence/toggle-tiles-notifications.json). Oczekiwane ostrzeżenie wyłącznie w osobnej próbie brakującego executable. |
| Night Light | **PASS**, adapter IPC/Process i 20 cykli, bez sprzętu. [Raport](evidence/toggle-tiles-desktop.json). |
| Natywny Wayland i Hypridle | **PASS**, 13 grup, 20 zrzutów, macierz 2 rozdzielczości × 4 skale, różne skale monitorów, hotplug, 20 cykli, oba reloady. Realny Hypridle blokuje słuchacze w Prezentacji, dopuszcza je w Pracy w tle przy zachowanym `sleep`, po off przywraca zwykły stan. Działania słuchaczy to wyłącznie pliki testowe. [Raport](evidence/toggle-tiles-wayland/report.json), [sprzątanie](evidence/toggle-tiles-wayland/cleanup.json). |
| Odbiór obrazu | Obejrzano [menu trybów](evidence/toggle-tiles-wayland/caffeinate-modes.png) i [ramkę wyłączonego kafelka](evidence/toggle-tiles-wayland/inactive-tile-focus.png). |
| Aktywna sesja | **PASS**, jedna instancja PID 107656 i właściciel powiadomień; pasek 32 px, tapeta, skróty, Ustawienia, audio, centrum, launcher i Quick Menu. Caffeinate off, bez oczekiwania i błędu. Ustawienia oraz klawiatura zachowane, chezmoi czyste, konfiguracja i log QML bez błędów. [Raport](evidence/toggle-tiles-activation.json), [log](evidence/toggle-tiles-live.log). |
| Pakiet i rollback | **PASS**, 164 pliki runtime zgodne ze źródłami; Lua `config ok` w prywatnych XDG, odtworzenie 6 plików, powtarzalność i ochrona późniejszych edycji. [Log](evidence/toggle-tiles-prepare.log), [plan](evidence/toggle-tiles-activation-plan.json). |

Pierwszy natywny przebieg ujawnił brak pierwszego przejęcia fokusu przy
jednoczesnym znikaniu toastu/OSD. Sam `activeChanged` nie wystarcza, gdy
okno nie dostało jeszcze pierwszej aktywacji. Dodano jednorazową kontrolę
po mapowaniu; powtórzenie zaliczyło 10 takich przejść i zwrot fokusu
obcej aplikacji. [Zachowany pierwszy raport](evidence/toggle-tiles-wayland-initial/report.json).
Nie wyciszono ostrzeżeń QML; brakujący typ ExitStatus w metadanych
Quickshella 0.3.1 obsługuje połączenie rzeczywistego sygnału, tak jak
istniejące adaptery Process.

Przełączenie zmieniło ścieżki wydania w trzech plikach Hyprlanda i ich
źródłach chezmoi; stary proces zatrzymano przed nowym. Hypridle.conf
pozostał bez zmian. [Różnica](evidence/toggle-tiles-config.diff),
[przywrócenie](install.md#kafelki-i-caffeinate--2026-09-20). Pierwsze
wywołanie skryptu bez `--apply` weszło w gałąź restore i nie zmieniło
plików ani starej instancji; poprawne wywołanie wykonało pełne przełączenie.
[Zapis próby](evidence/toggle-tiles-activation-initial.json).

Nie wykonywano transkrypcji mikrofonu, rzeczywistego usypiania, blokady
ani wygaszania hosta. Zgodność Caffeinate z lokalnym Hypridle potwierdzono
w izolacji; test nie jest próbą fizycznego suspend/resume. Historia nadal
jest tylko sesyjna i znika przy restarcie/reloadzie.

## Quick Menu i centrum powiadomień — 2026-09-20

**Poprzednie wdrożenie: `20260920-quick-menu-2062d4d22d06`.**

Audio ma jedną ramkę całego wiersza: `h/l` reguluje głośność,
`Enter/i` rozwija wyjścia; mysz obsługuje osobno suwak i przyciski.
Nazwy rozróżniają głośniki, słuchawki i HDMI/DisplayPort, z docelową
nazwą „Wbudowane głośniki”. Wi-Fi/Bluetooth w Quick Menu to kafelki
on/off; zarządzanie przeniesiono do własnych modułów paska. Usunięto
odświeżanie światła nocnego i komunikaty postępu/sukcesu. Błędy trafiają
wyłącznie do powiadomień. Centrum dostępne z dzwonka, Quick Menu i skrótu
powiadomień zawiera DND oraz do 100 ostatnich wpisów w pamięci sesji,
także wygasłych i wyciszonych; transient nie są archiwizowane. Zamknięte
wpisy nie utrzymują natywnych obrazów ani akcji. Restart czyści historię.

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 180 QML, 0 błędów. [Log](evidence/quick-menu-check.log). |
| Pełny katalog QtTest | **PASS**, 354 wyniki, 0 błędów/pominięć, 127,212 s; [log](evidence/quick-menu-regression-qt.log). Późniejsze zmiany: punktowy test spóźnionej gotowości audio oraz natywny grab, sprawdzane osobno poniżej. |
| Quick Menu, QtTest | **PASS**, 14 wyników, 0 błędów/pominięć, 5,415 s; wiersz audio, nazwy, późna gotowość urządzenia, kafelki i ich potwierdzenia, powiadomienia błędów, osobne moduły, historia, DND, klawiatura/mysz, 10 cykli 320×220; [log](evidence/quick-menu-qt.log). |
| Testy Python | **PASS**, 32 testy, 11,691 s; [log](evidence/quick-menu-python.log). |
| Prywatny NetworkManager / BlueZ | **PASS**, odpowiednio 9 i 7 grup oraz po 20 cykli; [sieć](evidence/quick-menu-network.json), [Bluetooth](evidence/quick-menu-bluetooth.json). |
| Prywatny PipeWire | **PASS**, rzeczywiste Props obu kanałów, wybór, późny start/restart, 20 cykli i soft/hard reload; [raport](evidence/quick-menu-audio.json), [log](evidence/quick-menu-audio.log). Dwie diagnostyki rozłączenia są oczekiwanymi skutkami celowych awarii. |
| Prywatny D-Bus powiadomień | **PASS**, 12 grup, 20 cykli, historia DND obejmuje dokładnie 32 wpisy, zamknięte wpisy bez akcji/obrazów, restart/konflikt właściciela; [raport](evidence/quick-menu-notifications.json), [log](evidence/quick-menu-notifications.log). Jedno oczekiwane ostrzeżenie dotyczy osobnego scenariusza brakującego programu. |
| Złożona integracja Quickshell | **PASS**, 4 grupy, 20 cykli, zwalnianie widoków/skanowania i reload; [raport](evidence/quick-menu-validation.json). |
| Natywny Wayland | **PASS**, 11 grup, 18 zrzutów, 2 rozdzielczości × 4 skale, różne skale monitorów, hotplug nowych modułów, 10 cykli fokusu przy znikaniu toastów, 20 cykli paneli i soft/hard reload; [raport](evidence/quick-menu-wayland/report.json), [log](evidence/quick-menu-wayland-run.log), [sprzątanie](evidence/quick-menu-wayland/cleanup.json). |
| Podgląd wizualny | Obejrzano [Quick Menu](evidence/quick-menu.png) i [centrum](evidence/notification-center.png), na atrapach. |
| Przygotowanie wydania | **PASS**, 159 plików zgodnych ze źródłami, prywatne XDG i `Hyprland --verify-config`: `config ok`; przywracanie wszystkich 6 konfiguracji, powtarzalność i ochrona późniejszych edycji; [log](evidence/quick-menu-prepare.log), [Lua](evidence/quick-menu-hyprland-verify.log), [plan](evidence/quick-menu-activation-plan.json). |
| Aktywna sesja po przełączeniu | **PASS**, jedna instancja i właściciel powiadomień (PID 92168), pasek 32 px, tapeta, 7 skrótów, Ustawienia, audio, centrum, oba tryby launchera i Quick Menu; aktywne wyjście „Wbudowane głośniki”; [raport](evidence/quick-menu-activation.json), [czysty log QML](evidence/quick-menu-live.log). |

Opublikowano kompletne wydanie; poprzedni proces zatrzymano przed nowym.
Zmieniono ścieżki wydania w trzech konfiguracjach Hyprlanda oraz ich
źródłach chezmoi. `chezmoi status` pusty, konfiguracja Hyprlanda bez błędów,
159 plików runtime zgodnych z manifestem. Ustawienia i plik klawiatury
zachowano; otwieranie paneli nie zmieniło stanu audio. Odbiór aktywnej
sesji nie uruchamiał modułów skanowania Wi-Fi ani discovery Bluetooth.
[Zmiany konfiguracji](evidence/quick-menu-config.diff),
[procedura powrotu](install.md#quick-menu-i-centrum-powiadomień--2026-09-20).

Wczesne testy wykryły nieaktualny cel nawigacji podczas tworzenia listy
sieci, zmianę `activeFocusOnTab` na skupionej strzałce audio oraz wyścig
odnawiania graba przy znikaniu toastu/OSD. Poprawiono produkcyjny kod
oraz oczekiwania starych testów po rozdzieleniu modułów. W natywnym
panelu usunięcie i odnowienie graba dzieli jednorazowe 16 ms, bez
odpytywania w spoczynku. Zachowano raporty wczesnych nieudanych prób:
[Qt](evidence/quick-menu-regression-qt-initial.log),
[PipeWire](evidence/quick-menu-audio-initial.log),
[Wayland — nawigacja](evidence/quick-menu-wayland-initial/report.json),
[fokus](evidence/quick-menu-wayland-focus-cycles/report.json).

Wszystkie operacje w testach używały atrap lub prywatnych usług/XDG;
nie zmieniano radia, parowania, fizycznego audio ani sesji/PAM użytkownika.
Nazwy fizycznych wyjść potwierdzono tylko odczytem PipeWire.
Nie powtarzano pomiaru idle ani sprzętowego odbioru lock/suspend.
Przenośny instalator etapu 13 i historia powiadomień na dysku pozostają
poza zakresem. Brak metadanych Git; bez commita.


## Kliknięcia bez ramki fokusu — 2026-09-19

**Wdrożone: `20260919-mouse-focus-d40d745288bc`.**
Workspace’y, moduły prawej grupy paska, Quick Settings oraz pozostałe
wspólne kontrolki pokazują ramkę wyłącznie przy obsłudze klawiaturą.
Kliknięcie lub przeciągnięcie usuwa ją także z elementu wcześniej
wybranego klawiaturą; następny klawisz przywraca obrys bez konieczności
zmiany elementu. Akcje, zwykłe wejście Qt i wpisywanie `hjkl` działają nadal.

`ControlInput` współdzieli rozpoznawanie wejścia w Button, Slider i
TextField, a `FocusIndicator` zastępuje osobne warunki `activeFocus`
w tłach paska i modułów. Koordynator, strony paneli, potwierdzenie Power,
podmenu traya i formularz Wi-Fi zachowują powód wywołania. Zamknięcie
myszą nie wznawia nawigacji paska. Zasadę dla nowych kontrolek zapisano
w `AGENTS.md` i kontraktach wyglądu/architektury. Zakres jest korektą UI,
bez rozpoczynania kolejnego etapu roadmapy i bez nowych podpowiedzi.

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 177 QML, 0 błędów; [log](evidence/mouse-focus-check.log). |
| Pełny katalog `tests/qml` przez QtTest | **PASS**, 342 wyniki, 0 błędów/pominięć, 124,016 s; [log](evidence/mouse-focus-regression-qt.log). |
| Nowy zestaw `PointerFocus` | **PASS**, 35 wyników, w tym kliknięcia wszystkich modułów paska, Quick Settings i szczegółów, przejścia między panelami, Power, podmenu, prawy/środkowy przycisk, suwak, tekst i powrót do klawiatury; [osobny przebieg](evidence/mouse-focus-qt.log). Końcowe zmiany PanelSurface objęte pełnym przebiegiem powyżej. |
| `scripts/test-panels-integration` | **PASS**, rzeczywiste IPC i LazyLoader Quickshella, 20 cykli, 0 pozostałych powierzchni; [raport](evidence/mouse-focus-panels.json), [log](evidence/mouse-focus-panels.log). |
| Przygotowanie wydania | **PASS**, 155 plików zgodnych ze źródłami, prywatne XDG i `Hyprland --verify-config`: `config ok`; przywracanie 6 plików jest powtarzalne i chroni późniejsze edycje przed zatrzymaniem shella; [log](evidence/mouse-focus-prepare.log), [walidacja Lua](evidence/mouse-focus-hyprland-verify.log). |
| Aktywacja po poleceniu „przelacz” | **PASS**, jedna instancja i ten sam PID właściciela powiadomień, pasek 32 px, tapeta, 7 skrótów bez błędu, fokus paska, okno Ustawienia, panele audio/Quick Settings i oba tryby launchera; [raport](evidence/mouse-focus-activation.json), [log QML](evidence/mouse-focus-live.log). |

Opublikowano kompletne wydanie i zatrzymano stary proces przed nowym.
Zmieniono wyłącznie ścieżki wydania w trzech konfiguracjach Hyprlanda
oraz ich źródłach chezmoi; końcowy `chezmoi status` pusty. Pliki ustawień
i klawiatury nie zmieniły się, a odbiór paneli nie zmienił wyjścia audio.
Wszystkie 155 plików runtime odpowiada manifestowi; konfiguracja
Hyprlanda bez błędów. [Plan](evidence/mouse-focus-activation-plan.json),
[zmiany konfiguracji](evidence/mouse-focus-config.diff),
[procedura wycofania](install.md#kliknięcia-bez-ramki-fokusu--2026-09-19).

Wczesne próby wykryły zachowywanie przez Qt poprzedniego powodu fokusu
na tym samym elemencie oraz przechwytywanie kliknięć przez pośredni Item.
Obserwator jest teraz pasywnym handlerem bezpośrednio na kontrolce.
Pierwsza pełna regresja miała 339 PASS / 2 FAIL: test launchera i test
przełączania stron klikały przed zakończeniem przeliczenia geometrii.
Dodano `waitForPolish` przed tymi kliknięciami; końcowy pełny przebieg
jest zielony. [Pierwsza regresja](evidence/mouse-focus-regression-qt-initial.log).
Pełny log zachowuje dwa komunikaty QINFO o zniszczeniu kontekstu podczas
inkubacji strony Klawiatura przy zmianie sekcji; ten test kończy się PASS.
Komunikatów nie wyciszano.

Potwierdzone lokalnie Qt **6.11.2** (`qt6-declarative 6.11.2-2`,
`qt6-base 6.11.2-3`) i Quickshell **0.3.1-1**. Sprawdzone oficjalne API:
[focusReason i visualFocus](https://doc.qt.io/qt-6.11/qml-qtquick-controls-control.html),
[TextField](https://doc.qt.io/qt-6.11/qml-qtquick-controls-textfield.html),
[Keys.forwardTo](https://doc.qt.io/qt-6.11/qml-qtquick-keys.html),
[TapHandler / pasywny grab](https://doc.qt.io/qt-6/qml-qtquick-taphandler.html),
[QtTest](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html).

Testy wejścia wykonywano offscreen, na atrapach oraz prywatnych XDG i D-Bus.
Po przełączeniu sprawdzono natywne powierzchnie i IPC; nie powtarzano
pełnej macierzy Waylanda, ręcznych kliknięć, dotyku ani sprzętu/PAM.
Nie powtarzano pełnego `scripts/test`
(Python i wszystkich adapterów): uruchomiono cały katalog QtTest oraz
integrację paneli odpowiednią do zmiany. Przy aktywacji sprawdzono lokalne
CLI Quickshella 0.3.1, Hyprlanda 0.56.2, chezmoi 2.72.2 i UWSM 0.27.0
oraz ich dokumentację (`--help`, zainstalowane `hyprctl(1)` i `uwsm-app(1)`).
Brak metadanych Git; bez commita.

## Przywrócenie po end-4 — 2026-09-19

Na polecenie użytkownika usunięto konfigurację, źródła `~/end-4`, cache
instalatora i środowisko Python end-4, bez tworzenia ich kopii. Użytkownik
przywrócił oficjalny pakiet `quickshell 0.3.1-1` i usunął pakiety
`illogical-impulse-*`; końcowy odczyt pacmana potwierdził brak tych pakietów.
Przywrócono wydanie **`20260917-settings-keyboard-cc7addc79750`** oraz
wcześniejsze pliki Hyprlanda, blokady, Fish, Kitty i motywu. Wykorzystano
istniejące pliki sprzed instalacji end-4 w `~/ii-original-dots-backup`.
153 pliki runtime są zgodne bajtowo ze źródłami projektu.

Autostart i skróty Putkina zapisano także w repozytorium chezmoi, aby
kolejne `chezmoi apply` nie przywracało niedziałającego odwołania do
poprzedniego shella. Ustawienia Putkina zachowano bez zmian. Zatrzymano
end-4 przed uruchomieniem Putkina, usunięto podwójny proces Hypridle,
wyłączono autostart ydotool dodany przez end-4 i włączono usługę
`hyprpolkitagent`, ponieważ po przełączeniu brakowało agenta autoryzacji.
Pozostały pomocniki wcześniejszego Quickshell DE używane przez Hypridle
oraz SSH_ASKPASS; stary shell nie jest uruchamiany.

Weryfikacja: `scripts/check` **PASS**, 174 QML, 0 błędów;
`test-launcher-integration` **PASS**, 5 grup;
`test-panels-integration` **PASS**, 20 cykli i 0 pozostałych powierzchni.
W aktywnej sesji: jedna instancja Putkina, ten sam PID jako właściciel
powiadomień, pasek 32 px i tapeta, działające wejście/wyjście fokusu paska,
7 zastosowanych skrótów bez błędu, otwieranie i zamykanie launchera,
schowka, komend, Quick Settings oraz audio. Hyprland i log runtime bez
błędów; Hypridle i Hyprpolkitagent aktywne. Końcowy `chezmoi status` pusty.
Pierwszy weryfikator błędnie oczekiwał tekstu polecenia w polu `arg`
skrótu Lua; Hyprland zwraca tam identyfikator dispatchera. Poprawiono
weryfikator i cały odbiór przeszedł.

Nie wykonywano wylogowania, blokady ani uśpienia w tej sesji; autostart
sprawdzono w zapisanej konfiguracji. [Raport odbioru](evidence/end4-removal-putkin-restored-20260919.json).

## Okno Ustawienia, gotowe działania i chip Komenda — 2026-09-17

**Wdrożone: `20260917-settings-keyboard-cc7addc79750`.**
Launcher pokazuje „Ostatnie”, a Super+Shift+średnik otwiera chip „Komenda”
i puste pole. Osobne natywne okno „Ustawienia” zawiera sekcje Wygląd
(przeniesione próbki kolorów, HEX i ograniczenie ruchu) oraz Klawiatura.
Klawiatura przypisuje skróty i komendy `:` do 49 gotowych działań shella
i Hyprlanda. Zakres nie obejmuje własnych dispatcherów ani poleceń powłoki,
zgodnie z odpowiedzią użytkownika. Nie dodano podpowiedzi.

Zapis ma osobny `keyboard.json`, walidację duplikatów i konfliktów z obcymi
skrótami, ochronę zmian zewnętrznych oraz potwierdzenie aktywacji w Hyprlandzie.
Zmiana przypisania usuwa stary skrót; restart i reload odtwarzają zapis.
Widoki używają wspólnego kontrolera akcji, bez poleceń systemowych w QML UI.
Ustawienia zachowują wersje robocze przy zmianie sekcji, pozostają otwarte
po utracie fokusu i przywołują istniejące okno. [Kontrakt](keyboard.md),
[okno i kolory](settings.md), [launcher](launcher.md).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` po ostatniej zmianie | **PASS**, 174 QML, 0 błędów; [log](evidence/settings-keyboard-final-check.log). |
| Pełna regresja QtTest | **PASS**, 306 wyników, 0 błędów/pominięć, 117,310 s; [log Qt](evidence/settings-keyboard-qt.log). |
| Końcowe testy zmienionych widoków | **PASS**, 101 wyników: klawiatura, launcher, ustawienia, panele; [log](evidence/settings-keyboard-final-qt.log). Po dopracowaniu okna 320×220: **12 wyników klawiatury PASS**, w tym widoczność fokusu listy i pól; [log](evidence/settings-keyboard-small-qt.log). |
| Wszystkie testy Python | **PASS**, 32 testy, w tym 6 nowych testów transakcji Lua, rollbacku, cytowania i konfliktów; [log](evidence/settings-keyboard-python-all.log). |
| Natywny prywatny Wayland | **PASS**, 9 grup: rzeczywiste Super+Spacja/Super+V/Super+Shift+średnik, osobne okno i fokus, zapis koloru, zmiana skrótu, komendy i przekazanie fokusu, akcje okna/workspace, konflikt, oba reloady oraz 10 cykli; [raport](evidence/settings-keyboard-native/result.json), [log](evidence/settings-keyboard-native.log), [sprzątanie](evidence/settings-keyboard-native/cleanup.json). |
| Produkcyjne FileView/IPC na atrapach | **PASS**, launcher 5 grup, ustawienia 10 grup i 20 cykli, panele 20 cykli, integracja domen 20 cykli; [launcher](evidence/settings-keyboard-launcher.json), [ustawienia](evidence/settings-keyboard-settings.json), [panele](evidence/settings-keyboard-panels.json), [całość](evidence/settings-keyboard-validation.json). |
| Wygląd | **PASS**, obejrzane zrzuty rzeczywistego prywatnego okna: [Wygląd](evidence/settings-keyboard-native/appearance.png), [Klawiatura](evidence/settings-keyboard-native/keyboard.png). |
| Konfiguracja i pakiet | **PASS**, 68 skrótów bez kolizji; [Lua](evidence/settings-keyboard-bindings.log). Hyprland 0.56.2 `--verify-config`: `config ok`; [log](evidence/settings-keyboard-hyprland-verify.log). 153 pliki zgodne ze źródłami, test przywrócenia oraz ochrony późniejszych edycji; [log](evidence/settings-keyboard-prepare.log), [plan](evidence/settings-keyboard-activation-plan.json). |

W pierwszych przebiegach poprawiono oczekiwania testów po wydzieleniu okna,
natywne przywołanie fokusu przez odświeżenie danych toplevela oraz testowe
mapowanie klawiatury `wtype`. Runner prywatnego Waylanda ma osobną nazwę,
aby negatywne testy integracji offscreen nie uruchamiały kompozytora.
Pełny zielony przebieg Python i Qt oraz końcowe próby powyżej uwzględniają
te poprawki. Limit pełnej regresji Qt zwiększono ze 120 do 180 s.

Aktywacja po wyraźnej zgodzie użytkownika **PASS**: jedna instancja i ten sam
PID właściciela powiadomień; 7 domyślnych skrótów zastosowanych bez błędu,
0 samoczynnie dodanych komend. Nowe okno „Ustawienia” ma 720×680 i jest
natywnie pływające. Produkcyjne IPC otwiera/zamyka panel audio, oba tryby
launchera i Quick Settings na właściwym monitorze; toggle audio działa.
Kolory, plik klawiatury i stan wyjścia audio pozostały niezmienione.
Wszystkie 153 opublikowane pliki odpowiadają manifestowi źródeł; brak
błędów QML i Hyprlanda. Stary proces zatrzymano przed nowym, a trzy
konfiguracje mają kopie i procedurę przywrócenia chroniącą późniejsze edycje.
[Odbiór aktywnej sesji](evidence/settings-keyboard-activation.json),
[log](evidence/settings-keyboard-live.log), [wycofanie](install.md).

Pierwszą próbę aktywacji zatrzymał automatyczny przegląd uprawnień przed
wykonaniem zmian. Po odpowiedzi „Tak, uruchom przygotowaną wersję” ponowne
wywołanie uzyskało zgodę i zakończyło się powodzeniem;
[zapis decyzji](evidence/settings-keyboard-activation-review.txt).

Nie wykonywano operacji na sprzęcie, blokady/PAM ani zmian okien użytkownika.
Nie powtarzano pełnej macierzy rozdzielczości/skali Waylanda ani pomiaru idle.
Przenośny instalator etapu 13 pozostaje poza zakresem. Brak metadanych Git;
bez commita. Sprawdzone wersje i oficjalne API: [Klawiatura](keyboard.md#sprawdzone-api).

## Podpowiedzi wyłącznie na polecenie — 2026-09-17

Zapisano w `AGENTS.md` i kontrakcie wyglądu zasadę użytkownika: żadnych
nowych podpowiedzi, tekstów pomocniczych ani tooltipów bez jego wyraźnego
polecenia. Zmiana dotyczy instrukcji i dokumentacji; runtime bez zmian.
`scripts/check`: **PASS**, 162 QML, 0 błędów;
[log](evidence/no-hints-check.log). Testów zachowania nie powtarzano,
ponieważ nie zmieniono kodu ani zachowania interfejsu.

## Osobny panel audio i skróty launchera — 2026-09-17

**Wdrożone: `20260917-audio-launcher-2cf1bad7b39c`.**
Usunięto tekst pomocniczy przy niepełnych komendach (`:w`, `:mw`, `:`).
Super+V otwiera Schowek, Super+: komendy z dwukropkiem i kursorem na końcu
(Super+Shift+średnik na układzie PL/US). Ikona głośnika otwiera osobną ramkę
z suwakami głośnika/mikrofonu, wyciszaniem i obiema listami urządzeń.
Panel zachowuje monitor, przewijanie, h/j/k/l, Enter, Tab, Escape oraz
powrót fokusu. Otwarty panel tłumi OSD głośności.

Wspólne `AudioChannelService` i `PipewireChannel` obsługują oba kierunki,
z niezależnym stanem, potwierdzeniem i timeoutem. Dotychczasowe IPC wyjścia
jest zgodne wstecz; nowe IPC: `ui openAudio/toggleAudio` oraz
`launcher openClipboard/openCommands`. Nie powstaje nowy daemon.
Błędy mikrofonu trafiają do osobnego toastu. [Kontrakt audio](audio.md),
[launcher](launcher.md), [IPC](ipc.md).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 162 QML, 0 błędów; [log](evidence/audio-launcher-check.log). Po optycznym wyrównaniu ikony mikrofonu również PASS zmienionego widoku, [log](evidence/audio-launcher-final-view-check.log). |
| Pełna regresja QtTest | **PASS**, 295 wyników, 0 błędów/pominięć, 110,346 s; [log](evidence/audio-launcher-qt.log). |
| Audio — prywatny PipeWire | **PASS**, dwa wirtualne sinki i dwa source; Props głośności/mute, niezależność kanałów, zewnętrzna zmiana, preferencja bez potwierdzenia i timeout, potwierdzony wybór, usunięcie źródła, późny start/restart, soft/hard reload i 20 cykli OSD; [raport](evidence/audio-launcher-pipewire.json), [log](evidence/audio-launcher-pipewire-run.log). Dwie diagnostyki rozłączenia pochodzą z celowo wywołanych awarii. |
| Launcher — produkcyjne IPC | **PASS**, 5 grup integracji: wejście do obu trybów, zmiana otwartego panelu, DesktopEntries, fd, schowek/MRU na atrapach akcji, reload i 20 cykli; [raport](evidence/audio-launcher-ipc.json), [log](evidence/audio-launcher-ipc-run.log). |
| Wygląd | **PASS**, obejrzane rendery offscreen: [panel](evidence/audio-panel.png), [320×220 / skala 1,5](evidence/audio-panel-small.png), [brak wejścia](evidence/audio-panel-no-input.png), [brak backendu](evidence/audio-panel-unavailable.png), [puste `:w`](evidence/launcher-incomplete.png). |
| Konfiguracja | **PASS**, 68 skrótów bez kolizji, dokładne polecenia obu trybów, cytowanie ścieżek, zachowane terminal/blokada i autostart; [Lua](evidence/audio-launcher-bindings.log). Lokalny Hyprland 0.56.2: `--verify-config` → `config ok`, [log](evidence/audio-launcher-hyprland-verify.log). |
| Przygotowanie aktualizacji | **PASS**, 142 pliki runtime zgodne ze źródłami i manifestem; test przywrócenia kopii, powtórnego przywrócenia i ochrony późniejszych edycji, [log](evidence/audio-launcher-restore-test.log), [plan](evidence/audio-launcher-activation-plan.json). |

Aktywacja **PASS**: jeden proces i właściciel powiadomień, panel audio
open/close/toggle, launcher w obu nowych trybach i Quick Settings przez
produkcyjne IPC na skupionym eDP-1. Wszystkie 142 opublikowane pliki mają
sumy zgodne ze źródłami; brak błędów QML/Hyprlanda, ustawienia identyczne,
stan wyjścia audio niezmieniony. Potwierdzono trzy wpisy skrótów launchera
(Super+Spacja, Super+V, Super+Shift+średnik). Stary proces zatrzymano przed
nowym; trzy konfiguracje mają kopie i sprawdzony rollback.
[Aktywacja](evidence/audio-launcher-activation.json),
[log shella](evidence/audio-launcher-live.log), [wycofanie](install.md).

Pierwszy przebieg Qt wykrył stary negatywny test uznający `audio` za nieznany
panel. Zmieniono przykład nieobsługiwanego ID; pełna regresja powyżej przeszła.
[Wynik początkowy](evidence/audio-launcher-qt-initial.log).
Sandbox blokował prywatne gniazdo D-Bus; testy wykonano poza nim,
z zachowaniem prywatnych XDG/D-Bus, atrap i renderowania offscreen.

Sprawdzone lokalne wersje: Qt 6.11.2, Quickshell 0.3.1, Hyprland 0.56.2.
Oficjalne API: [Pipewire i źródła](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/Pipewire/),
[PwNode](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pipewire/PwNode/),
[IpcHandler](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/),
[Slider Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-controls-slider.html),
[Lua Hyprland 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/example/hyprland.lua).

Nie wykonano nagrywania ani zmian fizycznego mikrofonu/wyjścia, fizycznego
naciśnięcia nowych skrótów, nowej pełnej macierzy Waylanda, pomiaru idle
ani pozostałych integracji domen niezwiązanych ze zmianą. Treści schowka
użytkownika nie odczytywano przez narzędzia testowe. Przenośny instalator
etapu 13 pozostaje osobnym zakresem. Brak metadanych Git; bez commita.

## Komendy workspace w launcherze — 2026-09-17

**Wdrożone: `20260917-workspace-commands-ca6230ec4aef`.**
`:wN` przełącza workspace na monitorze launchera, `:mwN` przenosi okno
zapamiętane przed otwarciem panelu, bez przełączania widoku. N to jedna
cyfra 0–9; `0` oznacza 10, zgodnie z konfiguracją skrótów. Enter lub kliknięcie
wyniku wykonuje komendę. [Kontrakt i sprawdzone API](launcher.md#komendy-workspace).

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 157 QML, zero błędów; [log](evidence/workspace-commands-check.log). Pierwsza kontrola wykryła brak jawnego typu okna w atrapie; poprawiono, [pierwszy wynik](evidence/workspace-commands-check-initial.log). |
| QtTest: launcher, pasek, panele | **PASS**, 67 wyników (42 + 13 + 12); wszystkie cyfry obu komend, rzeczywiste klawisze, podwójny Enter, monitor, brak pomocnika, zamknięcie okna, timeout, rozłączenie, opóźniona odpowiedź, dosłowne filtry i dotychczasowa nawigacja; [log](evidence/workspace-commands-qt.log). |
| `scripts/test-bar-integration` | **PASS**, Lua i Hyprlang: natywne modele, utworzenie workspace 10, jawny adres okna sprzed zmiany fokusu, ciche przeniesienie na 7, odmowa po usunięciu obiektu, hotplug i EOF; prywatne gniazda, [log](evidence/workspace-commands-hyprland.log). |
| `scripts/test-launcher-integration` | **PASS**, 4 grupy: DesktopEntries, fd, schowek/MRU, soft reload i 20 cykli; [raport](evidence/workspace-commands-launcher.json), [log](evidence/workspace-commands-launcher.log). |
| Render na atrapach | **PASS**, obejrzane [przełączenie 1366×768](evidence/workspace-commands-switch.png) i [przeniesienie 320×220, skala 1,5](evidence/workspace-commands-move-small.png). |
| Konfiguracja aktualizacji | **PASS**, [66 skrótów bez kolizji](evidence/workspace-commands-bindings.log) i [natywny parser Hyprlanda](evidence/workspace-commands-hyprland-verify.log). |
| Działająca sesja | **PASS**, jeden shell/właściciel powiadomień, launcher oraz bateria przez produkcyjne IPC, poprawny pasek, brak błędów QML/WM, ustawienia i profil zasilania niezmienione; [aktywacja](evidence/workspace-commands-activation.json), [log](evidence/workspace-commands-live.log). |

Opublikowano pełny runtime 137 plików; zmienia się 7 plików produkcyjnych.
Manifest i kopie trzech konfiguracji: [plan](evidence/workspace-commands-activation-plan.json).
Źródła, staging i opublikowane pliki mają zgodne sumy. Stary proces został
zatrzymany przed uruchomieniem nowego; [powrót do poprzedniej wersji](install.md).
Komendy nie uruchamiają procesów pomocniczych ani pollingu. Potwierdza je
natywny stan; timeout nie jest sukcesem. Nie wykonano nowej pełnej regresji
wszystkich domen, macierzy Waylanda ani pomiaru bezczynności. Przenoszenie
i tworzenie workspace sprawdzono na prywatnej atrapie Hyprlanda, bez
przestawiania okien użytkownika na pulpicie.

## Panel baterii bez separatora i dodatkowych stanów — 2026-09-17

**Wdrożone: `20260917-battery-minimal-8edd9469b482`.** Usunięto separator
nad profilami, tekst stanu obok procentu (także podczas ładowania) oraz
widoczny napis „Zmiana…” podczas przełączania profilu. Runtime zmienia
wyłącznie `BatteryView.qml`.

`scripts/check`: **PASS, 157 QML** ([log](evidence/battery-minimal-check.log));
po ostatnim usunięciu napisu dodatkowo **PASS, 1 zmieniony widok**
([log](evidence/battery-minimal-final-check.log)). Końcowe testy baterii/traya:
**26 wyników QtTest PASS** ([log](evidence/battery-minimal-qt.log)).
Obejrzany [render ładowania](evidence/battery-minimal.png), atrapy/offscreen.
Parser konfiguracji i 66 skrótów bez kolizji **PASS**.

Opublikowano komplet 137 plików. Odbiór sesji **PASS**: jeden shell i
właściciel powiadomień, otwieranie/zamykanie/toggle baterii oraz launcher,
brak błędów QML/WM, ustawienia i profil niezmienione.
[Aktywacja](evidence/battery-minimal-activation.json),
[log](evidence/battery-minimal-live.log), [rollback](install.md).
Nie powtarzano pełnej regresji, testów backendów ani macierzy Waylanda
przy tej zmianie wyglądu.

## Uproszczenie panelu baterii — 2026-09-17

**Wdrożone: `20260917-battery-clean-634ac9ebdd59`.** Usunięto nagłówek
„Bateria”, przycisk ×, komunikat „Niski poziom baterii”, nagłówek „Tryb
pracy” i widoczne „Aktywny”. Tekst oraz ikony przycisków są wyśrodkowane
w pionie. Stan aktywny zachowuje akcent i `checked` Qt. j/k/Tab zapętlają
profile; Escape działa również przy braku wszystkich trybów. Zmiana runtime
obejmuje wyłącznie `BatteryView.qml`.

Weryfikacja: `scripts/check` **PASS, 157 QML** ([log](evidence/battery-clean-check.log));
**26 wyników QtTest PASS**, w tym zmienione ścieżki fokusu i Escape,
mały ekran/mysz oraz 20 cykli ([log](evidence/battery-clean-qt.log)).
Obejrzano [render 1366×768](evidence/battery-clean.png) oraz
[320×220, skala 1,5](evidence/battery-clean-small.png), na atrapach/offscreen.
Sprawdzone API: [Text Qt 6.11.2](https://doc.qt.io/qt-6/qml-qtquick-text.html),
[Layout](https://doc.qt.io/qt-6/qml-qtquick-layouts-layout.html).

Opublikowano komplet 137 plików z kopiami trzech konfiguracji.
Parser Hyprlanda i 66 skrótów bez kolizji **PASS**. Odbiór działającej sesji:
jeden shell/właściciel powiadomień, bateria open/close/toggle i launcher,
brak błędów QML/WM, identyczne ustawienia i profil zasilania;
[aktywacja](evidence/battery-clean-activation.json), [log](evidence/battery-clean-live.log),
[sumy](evidence/battery-clean-activation-plan.json), [rollback](install.md).
Nie powtarzano integracji backendów, pełnej regresji i macierzy Waylanda
ani testów sprzętu dla tej korekty jednego widoku.

## Osobny panel baterii — 2026-09-17

**Status: wdrożony**; wersja początkowa **`20260917-battery-3028dc9e5e77`**.
Kliknięcie/Enter na ikonie baterii otwiera osobny panel: procent, pasek,
stan i czas do rozładowania / pełnego naładowania oraz Oszczędny,
Zrównoważony i Wydajność. Adaptacja `BatteryPopup.qml` i `PowerService.qml`
poprzednika ma tokeny Putkina, kwadratowe przyciski i fade. Zachowuje
nawigację j/k/Enter/Escape, monitor wywołania, powrót fokusu i przewijanie.
[Kontrakt](battery-tray.md), [IPC](ipc.md#panel-baterii--rozszerzenie).

Źródłem baterii pozostaje istniejący UPower DisplayDevice. Profile korzystają
z tej samej usługi PPD co poprzednik; adapter uzupełnia brak potwierdzenia
zapisu i cyklu właściciela w natywnym PowerProfiles 0.3.1. Bez własnego
algorytmu czasu, nowego daemona i zależności od starego repozytorium.

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 157 QML, zero błędów; [log](evidence/battery-check.log). |
| Testy bramki | **PASS**, 6 testów Python; [log](evidence/battery-gate-tests.log). |
| Wszystkie testy Qt | **PASS**, 263 wyniki, zero błędów/ostrzeżeń; [log](evidence/battery-regression-qt.log). |
| Bateria/tray | **PASS**, 26 wyników Qt, w tym 5 nowych scenariuszy panelu; procent/czas/stan, klawiatura, brak profilu, brak optymistycznego sukcesu, fokus po usunięciu, mysz i scroll 320×220, monitor/hotplug/20 cykli; [log](evidence/battery-qt.log). |
| Integracja statusu | **PASS**, 8 grup i 20 cykli; rzeczywiste gdbus/busctl i typowane Set/GetAll z atrapą PPD, odmowa, brak potwierdzenia, zewnętrzne zmiany, ograniczenie wydajności, utrata/powrót/późny start, soft/hard reload i sprzątanie procesów; [raport](evidence/battery-integration.json), [log](evidence/battery-integration.log). |
| Integracja paneli | **PASS**, produkcyjne IPC/LazyLoader, 20 cykli i zero pozostawionych powierzchni; [log](evidence/battery-panels-integration.log). |
| Render | **PASS**, obejrzane [ładowanie 1366×768](evidence/battery-charging.png) i [niski stan 320×220, skala 1,5](evidence/battery-small.png); dane atrapowe, offscreen. |
| Konfiguracja | **PASS**, 66 skrótów bez kolizji i natywny parser `config ok`; [skrótów](evidence/battery-bindings.log), [parsera](evidence/battery-hyprland-verify.log). |
| Działająca sesja | **PASS**, jeden shell/właściciel powiadomień, bateria open/close/toggle na skupionym eDP-1 i otwieranie launchera; brak błędów QML/WM, ustawienia identyczne, profil Oszczędny zachowany; [aktywacja](evidence/battery-activation.json), [log](evidence/battery-live.log). |

W pierwszych testach uzupełniono rejestr qmldir i poprawiono nawigację
po utworzeniu przycisków oraz fokus usuniętego profilu. Końcowe wyniki
powyżej obejmują poprawki. [Pierwszy test Qt](evidence/battery-qt-initial.log),
[pierwszy import Quickshell](evidence/battery-integration-initial.log).

Pierwsza aktywacja poprawnie załadowała runtime, lecz weryfikator porównał
szerokość okna z 360 px powierzchni, pomijając istniejący margines 8 px.
Automatyczny rollback przywrócił poprzedni shell i trzy konfiguracje.
Po korekcie kontroli ponownie aktywowano ten sam runtime, bez zmian źródeł.
[Pierwsza próba](evidence/battery-activation-first.log),
[plan z sumami](evidence/battery-activation-plan.json).
Opublikowano 137 plików; autostart i ścieżki IPC wskazują nową wersję.
Poprzedni proces został zatrzymany przed nowym. [Rollback](install.md).

**Granice odbioru:** nie przełączano fizycznego profilu zasilania dla testu,
nie powtarzano pełnych 13 integracji ani macierzy Waylanda. Zmiany profilu
potwierdzono protokołem na prywatnej atrapie; sprzętowy PPD odczytano
bez zapisu. Nie wykonano nowego pomiaru bezczynności/wielogodzinnego ani
odbioru sprzętowej dokładności czasu UPower. Brak metadanych Git;
przenośny instalator pozostaje osobnym zakresem.

## Launcher aplikacji, plików i schowka — 2026-09-17

**Status: wdrożony jako osobne rozszerzenie wybrane przez użytkownika.**
Wersja po dodaniu launchera: **`20260917-launcher-769491c1e9b8`**.
`Super+Spacja` otwiera launcher na skupionym monitorze. `:a `, `:f `, `:c `
zamieniają prefiks w usuwalną etykietę; puste pole pokazuje ostatnie użycia.
Enter uruchamia aplikację/plik albo kopiuje wpis schowka. Dostępne są
Escape/Tab, hjkl w liście, zwykłe wpisywanie hjkl w polu i przewijanie.
Wygląd korzysta ze wspólnych tokenów, ostrych rogów, ramek i fade.
[Kontrakt i granice](launcher.md), [IPC](ipc.md#launcher--rozszerzenie).

Przeniesiono parser/ranking poprzednika do `LauncherQuery.js`; nowy
`LauncherService` ma jawny backend i istniejący koordynator/PanelHost.
Pomocnik Python obsługuje ograniczone fd, atomowe MRU i prywatny schowek
cliphist. Bez zależności od poprzedniego repozytorium i bez nowego instalatora.
Historia aplikacji/plików jest trwała, schowek wyłącznie w sesji procesu.
Widok nie uruchamia poleceń; zmiany zapytania anulują wyszukiwanie, a spóźniona
odpowiedź nie zmienia zaznaczenia ani nie zamyka nowej sesji panelu.

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 153 QML, zero błędów; [log](evidence/launcher-check.log). |
| `scripts/test` | **PASS**, kod 0: 26 testów Python, 256 wyników QtTest, wszystkie 13 integracji (w tym nowy launcher); [log](evidence/launcher-tests.log). |
| Końcowe poprawki monitora i położenia toastu | **PASS**, 54 wyniki QtTest dla launchera, paneli, powiadomień i wyglądu; 13 przypadków samego launchera. Wykonane po pełnej regresji powyżej; [log](evidence/launcher-final-qt.log). |
| Końcowa integracja launchera | **PASS**, rzeczywiste DesktopEntries/Process/fd/cliphist/IPC/LazyLoader, prywatne dane, atrapy aplikacji i wl-clipboard, soft reload oraz 20 cykli; [raport](evidence/launcher-integration.json), [log](evidence/launcher-integration.log). |
| Render | **PASS**, obejrzane [MRU 1366×768](evidence/launcher-recent.png), [aplikacje](evidence/launcher-apps.png), [schowek 320×220, skala 1,5](evidence/launcher-small.png); podglądy na atrapach, offscreen. |
| Bezczynność pomocnika | **PASS**, 60,000 s, 0 dodatkowych ticków CPU, RSS 23 348 → 23 348 KiB; dwa zdarzeniowe watchery na atrapach, brak pozostałych procesów/bazy po wyjściu; [pomiar](evidence/launcher-idle.json). Nie jest to pomiar całego pulpitu. |
| Skróty i konfiguracja | **PASS**, 66 skrótów bez kolizji w rzeczywistym rejestrze Lua, natywny `Hyprland --verify-config` = `config ok`; [rejestr](evidence/launcher-bindings.log), [parser](evidence/launcher-hyprland-verify.log). |
| Działająca sesja | **PASS**, jeden Putkin i właściciel powiadomień, jeden `Super+Spacja`, otwieranie/zamykanie/toggle przez produkcyjne IPC, wyśrodkowana warstwa na eDP-1, pomocnik i dwa prawdziwe wl-paste; bez błędów QML/konfiguracji; [odbiór](evidence/launcher-live.json), [log](evidence/launcher-live.log). |

Pierwsza pełna regresja wykryła opóźnione wywołanie do zniszczonego widoku.
Dodano ochronę cyklu życia; kolejne testy przeszły. [Pierwotny FAIL](evidence/launcher-tests-initial.log).
Pierwsza próba przełączenia uruchomiła nowy kod, lecz weryfikator błędnie
oczekiwał tekstu polecenia w `hyprctl binds`: Lua zwraca `dispatcher=__lua`
i numer callbacku. Automatyczny rollback faktycznie przywrócił poprzednią
wersję i cztery konfiguracje. Po poprawieniu kontroli ponowiono przełączenie
tej samej, zweryfikowanej sumami wersji. [Pierwsza próba](evidence/launcher-activation-first.log),
[plan](evidence/launcher-activation-plan.json), [aktywacja](evidence/launcher-activation.json).

Opublikowano komplet 133 plików. Zmieniono autostart, ścieżki IPC i wpis
menu; stary skrót launchera usunięto, bez kolizji. `settings.json`, Hypridle
i konfiguracja blokady nie zostały zmienione. Poprzedni proces zatrzymano
przed uruchomieniem nowego. [Powrót do poprzedniej wersji](install.md).

**Granice odbioru:** nie odczytywano ani nie modyfikowano rzeczywistej treści
schowka i nie uruchamiano aplikacji/plików użytkownika dla testu. Te ścieżki
mają dowody z rzeczywistych fd/cliphist/DesktopEntries i atrap akcji.
Fizycznego naciśnięcia Super+Spacja, pełnej nowej macierzy Waylanda,
wielogodzinnej pracy i VRAM nie testowano; nie przypisujemy im wyników
poprzedniego odbioru. Przenośny instalator etapu 13 pozostaje osobnym zadaniem.
Brak metadanych Git; nie deklarujemy commita.

## Ikony i oznaczenie workspace’ów — 2026-09-17

Aktywna wersja: **`20260917-icons-cd3b25f5725c`**. Glify Wi-Fi, głośności
i wyciszenia mają korektę wielkości we wspólnym `Glyph.qml` (font 32 zamiast
20 px); zachowano rodzinę JetBrainsMono Nerd Font Mono i pola statusu 32 px.
W tej rodzinie przy 20 px rysunek Wi-Fi/głośnika miał około 12 px wysokości,
a Bluetooth 20 px. Po korekcie Wi-Fi/audio mają około 19 px.
Zajęty, nieaktywny workspace ma numer w kolorze akcentu i wadze DemiBold
(zainstalowany krój SemiBold), bez kropki. Aktywny zachowuje tło akcentu,
a pilny czerwony pogrubiony numer, również bez kropki.

Weryfikacja: `scripts/check` **PASS, 146 QML**, zero błędów;
**8 testów zachowania PASS** (14 wyników QtTest z inicjalizacją/sprzątaniem):
stany i przełączanie workspace’ów między monitorami, h/l/Enter przy nadmiarze
pozycji, zachowanie fokusu po aktualizacji modelu, audio oraz układ i kolory
paska/panelu. [Bramka](evidence/12-icons-workspaces-check.log),
[testy](evidence/12-icons-workspaces-tests.log). Obejrzane podglądy na
atrapach, z prywatnym XDG/D-Bus, w [skali 1](evidence/12-icons-workspaces-scale1.png)
i [1,5](evidence/12-icons-workspaces-scale1.5.png) **PASS**. Logi podglądów
zachowują znane ograniczenie masek platformy offscreen, bez błędów QML.
API sprawdzone dla lokalnego Qt 6.11.2 w dokumentacji
[Text](https://doc.qt.io/qt-6.11/qml-qtquick-text.html) i
[QFontMetricsF](https://doc.qt.io/qt-6.11/qfontmetricsf.html).

Opublikowano kompletny runtime 126 plików; zmienione są trzy źródła.
Sprawdzono sumy źródeł i opublikowanej kopii, 66 skrótów bez kolizji,
jedną działającą instancję i właściciela powiadomień, otwieranie/zamykanie
paneli i fokus paska. Log i konfiguracja WM bez błędów; ustawienia identyczne.
[Aktywacja](evidence/12-icons-workspaces-activation.json),
[odbiór](evidence/12-icons-workspaces-verification.json),
[log](evidence/12-icons-workspaces-putkin.log), [powrót](install.md).
Nie powtarzano pełnej regresji integracji, macierzy natywnego Waylanda
ani testów sprzętu/PAM dla tej korekty wyglądu. Wyniki poniżej są historyczne.

## Korekta wyglądu po uwagach użytkownika — 2026-09-16

Poprzedni odbiór funkcjonalny nie potwierdza zgodności wyglądu z referencjami:
użytkownik zgłosił konkretne odstępstwa. W tej korekcie zmieniono:

- ramki na 2 px i font na `JetBrainsMono Nerd Font Mono`; aktywny workspace
  ma sam numer na akcencie; statusy mają równe pola, bez procentów audio/baterii;
- potwierdzone Wi-Fi/Bluetooth mają kolor; Quick Settings ma dwa suwaki,
  krótkie wiersze i trzy kafelki, ze szczegółami jednego modułu naraz;
- OSD ma ikonę, poziomy gruby pasek i wartość w jednym rzędzie; menu Power
  używa kafelków, a Hyprlock przyciemnionej tapety, zegara, daty i jednego pola;
- przejścia zmieniają wyłącznie opacity przez 120 ms; ograniczony ruch
  pomija przejścia; fragment Lua usuwa dodatkowe animacje warstw Putkin;
- usunięto tooltipy i pomocnicze akapity; błędy trafiają do osobnych toastów,
  także przy otwartym panelu i DND, bez zmiany układu kontrolek.

Wersja po tej korekcie: **`20260916-visual-3d0c562aa347`**, opublikowana jako kompletny runtime
126 plików i uruchomiona po kontrolowanym zatrzymaniu poprzedniej instancji.
Autostart, skróty, reguła warstw i wejścia blokady wskazują nową instalację.
Zachowano oryginalny blok uwierzytelniania Hyprlock oraz niezmieniony
`settings.json`. Końcowy odczyt: jedna instancja, jeden właściciel powiadomień,
działające otwieranie/zamykanie paneli, brak błędów QML i konfiguracji WM.
[Wdrożenie](evidence/12-visual-activation.json),
[odbiór sesji](evidence/12-visual-verification.json),
[log](evidence/12-visual-putkin.log), [powrót](install.md).

`scripts/check`: **PASS, 146 plików QML**, zero błędów.
[Log bramki](evidence/12-visual-check.log).

Rzeczywiste wyniki: `scripts/test` **PASS** — 19 testów Python, 243 wyniki
QtTest oraz wszystkie 12 integracji. [Pełny log](evidence/12-visual-regression.log).
Natywny Wayland **PASS** — 18 zrzutów, klawiatura/fokus/kliknięcia, osiem
kombinacji trybu i skali, dwa monitory, hotplug, 20 cykli, soft/hard reload,
zero pozostawionych procesów. [Raport](evidence/12-visual-wayland/report.json).
Rzeczywisty Hyprlock wyrenderowany w prywatnym compositorze z atrapą PAM
i wyłączonym fingerprint: [zrzut](evidence/12-visual-lock/lock-preview.png),
[raport](evidence/12-visual-lock/report.json). Podglądy
[błędu przy otwartym panelu](evidence/12-visual-error.png) i
[Power](evidence/12-visual-power.png) również przeszły i zostały obejrzane.
Parser pełnej przygotowanej konfiguracji Hyprlanda: `config ok`;
66 skrótów bez kolizji i poprawny launcher blokady; rollback przetestowany
na plikach tymczasowych, z ochroną późniejszych edycji.

W trakcie testów naprawiono utratę treści toastu podczas fade, powrót fokusu
przy znikaniu biernej warstwy w Hyprland 0.56.2 oraz odczyt usuniętego ekranu.
Odbiór po pierwszej aktywacji wykrył ponadto fałszywy toast BlueZ podczas
inicjalizacji. Usługa zgłasza teraz brak właściciela dopiero po odpowiedzi
obserwatora. Dodatkowy test startu oraz 7 grup integracji Bluetooth/20 cykli
**PASS**, ponowny lint zmienionych dwóch plików **PASS**.
[Log](evidence/12-visual-bluetooth-integration.log),
[bramka](evidence/12-visual-bluetooth-check.log). Opublikowano kolejny cały
runtime; końcowy odczyt warstw nie zawiera pozostawionego toastu startowego.

Pierwszy pełny bieg integracji sieci został unieważniony przez edycję
importowanego pliku podczas testu; końcowy bieg jest odrębnym PASS.

Nie wykonywano nowego testu prawdziwego hasła/odcisku, blokady ani uśpienia
aktywnego pulpitu, pełnego audytu PAM lub nowego pomiaru spoczynku.
Nie deklarujemy akceptacji estetyki przez użytkownika. Przenośny instalator
z etapu 13 nadal jest poza zakresem tej korekty. Wyniki poniżej są historyczne.



Aktualizacja: 2026-09-16. **Etap 12 ukończony dla wersji
`20260916-5132708bd8f7`**: kandydat wydania spełnia
obowiązkowe kryteria [promptu](prompts/12-validation.md).
Końcowa regresja **PASS**: 137 QML bez błędów, 17 testów Python,
235 wyników QtTest i wszystkie 12 integracji. Odbiór UI prywatnego Waylanda
**PASS**: 18 zrzutów, skale, fokus/grab, hotplug, 20 cykli, soft/hard reload
i 60 s spoczynku. Naprawiono natywny fokus paneli/powiadomień i diagnostykę
runnerów. Dodatkowo zachowano 16 podglądów offscreen oraz 60 cykli paneli.
Użytkownik potwierdził działanie jasności, audio, Bluetooth, Wi-Fi, baterii,
monitorów, blokady ekranu, uśpienia/wybudzenia i wizualnego włączania oraz
wyłączania Night Light. Końcowy odczyt hosta potwierdził jedną instancję
Putkin, jednego właściciela powiadomień, tożsamość Hypridle i brak błędów QML.
Hyprsunset działa; odczyt wykazał 4500 K i włączony autostart jednostki.

Odbiór dotyczy powyższej działającej wersji. Równoległe zmiany wyglądu
w repozytorium, wykryte od 21:05 UTC już po zaliczonej regresji, zachowano;
nie są objęte tym PASS i wymagają własnego odbioru.

Scenariusze awarii i odmów przeszły na atrapach, zgodnie z wymaganiami
etapu. Nie deklarujemy audytu PAM, pełnej macierzy sprzętu ani pomiarów
wielogodzinnych/VRAM. [Raport i powiązanie kryteriów z dowodami](validation.md),
[zbiorczy wynik](evidence/12-closeout.json).
Aktywna sesja i autostart są przełączone na Putkin na wcześniejsze polecenie
użytkownika; lokalny odbiór przełączenia PASS. Etap 13 pozostaje częściowy:
przenośnego instalatora jeszcze nie wdrożono. [Instalacja i powrót](install.md).

| Etap | Nazwa | Status | Dowody / pozostała praca |
| --- | --- | --- | --- |
| 00 | Fundament i bezpieczne środowisko pracy | Zweryfikowany w etapie 12 | Kod, bramka i testy offscreen PASS; [dowody](evidence/00-foundation.md). Natywny Wayland/layer-shell potwierdzony w [etapie 12](validation.md). [Prompt](prompts/00-foundation.md) |
| 01 | Pasek, workspace i zegar | Zweryfikowany w etapie 12 | Pasek, adapter, IPC i testy PASS; [dowody](evidence/01-bar.md). Natywny layer-shell, fokus i wirtualny hotplug PASS w etapie 12; działanie fizycznych monitorów potwierdzone przez użytkownika. [Prompt](prompts/01-bar-workspaces.md) |
| 02 | Quick Settings, okna i fokus | Zweryfikowany w etapie 12 | Kod, 32 wyniki QtTest, IPC/LazyLoader i 20 cykli PASS; [dowody](evidence/02-panels.md). Natywne okno, grab i fokus PASS w etapie 12; tooltipy osobno nieodebrane natywnie. [Prompt](prompts/02-panels-focus.md) |
| 03 | Ustawienia wyglądu i edycja akcentów | Zweryfikowany w etapie 12 | Edytor, podgląd, walidacja i rzeczywisty zapis FileView PASS; 67 wyników QtTest, 20 zmian/reloadów, restart i błędy uprawnień; [dowody](evidence/03-appearance.md). Grab i skale wirtualnych wyjść PASS w etapie 12; działanie fizycznych monitorów potwierdzone przez użytkownika. [Prompt](prompts/03-appearance-settings.md) |
| 04 | Audio i OSD głośności | Zweryfikowany w etapie 12 | Wspólny model audio, tracker, suwak/mute/wyjścia, IPC i OSD; 85 wyników QtTest, prywatny PipeWire, restart/reload i 20 cykli PASS; [dowody](evidence/04-audio.md). OSD i fokus Waylanda PASS w etapie 12; działanie regulacji audio potwierdzone przez użytkownika. [Prompt](prompts/04-audio-osd.md) |
| 05 | Jasność i wspólny OSD | Zweryfikowany w etapie 12 | Suwak 1–100%, IPC, potwierdzający odczyt, kolejka i wspólny OSD; 111 wyników QtTest, Process na atrapach, timeout/SIGKILL, reload i 20 cykli. [Dowody](evidence/05-brightness.md). Natywne UI/OSD PASS w etapie 12; regulacja fizycznego backlight potwierdzona przez użytkownika. [Prompt](prompts/05-brightness.md) |
| 06 | Bateria i tray | Zweryfikowany w etapie 12 | Bateria/UPower, tray z overflow, menu/podmenu, 132 wyniki QtTest, natywny D-Bus i 20 cykli PASS; [dowody](evidence/06-battery-tray.md). Natywne UI traya PASS w etapie 12; bateria działa według użytkownika; obce aplikacje traya bez osobnego odbioru. [Prompt](prompts/06-battery-tray.md) |
| 07 | Sieć i zwykłe Wi-Fi | Zweryfikowany w etapie 12 | Wspólny status, potwierdzone radio, skanowanie, otwarte/zapisane/PSK, edytor zewnętrzny; 27 wyników Qt, 9 grup integracji, 20 cykli i 60 s spoczynku PASS. [Dowody](evidence/07-network.md). Natywne UI/skan lease/hotplug PASS w etapie 12; Wi-Fi działa według użytkownika; scenariusze awarii NM i odmowy Polkit PASS na atrapach, bez wymuszania ich na sprzęcie. [Prompt](prompts/07-network.md) |
| 08 | Podstawowy Bluetooth | Zweryfikowany w etapie 12 | Radio, adaptery, sparowane urządzenia, bateria peryferium i Blueman; 16 wyników Qt, 7 grup integracji, 20 cykli i 60 s spoczynku PASS. [Dowody](evidence/08-bluetooth.md). Natywne UI PASS w etapie 12; Bluetooth działa według użytkownika; awarie BlueZ i odmowy uprawnień PASS na atrapach, bez wymuszania ich na sprzęcie. [Prompt](prompts/08-bluetooth.md) |
| 09 | Powiadomienia i DND | Zweryfikowany w etapie 12 | Jeden serwer, toasty, akcje, DND, 19 wyników Qt, 12 grup protokołu, 20 cykli i 60 s spoczynku PASS. [Dowody](evidence/09-notifications.md). Wayland i fokus osobnej aplikacji PASS w etapie 12; rzeczywiste przejęcie nazwy powiadomień PASS podczas [przełączenia](install.md). [Prompt](prompts/09-notifications.md) |
| 10 | Menu sesji i zewnętrzna blokada | Zweryfikowany w etapie 12 | Menu, adapter, IPC, przykłady Hyprlock/Hypridle i testy; [dowody](evidence/10-session.md), [kontrakt](session.md). Natywne Power/anulowanie/hotplug PASS; 13 grup integracji sesji i błędów PASS na atrapach. Blokada, uśpienie i wybudzenie potwierdzone przez użytkownika; tożsamość Hypridle potwierdzona odczytem hosta. [Prompt](prompts/10-session-lock.md) |
| 11 | Opcjonalne dopasowanie pulpitu i Night Light | Zweryfikowany w wybranym zakresie | Tapeta w Quickshellu, Night Light, Lua/rollback i testy; [kontrakt](desktop.md), [dowody](evidence/11-desktop.md). Natywne tło Mocha PASS, osobista czysta tapeta aktywna. Wizualne włączanie/wyłączanie Night Light potwierdzone przez użytkownika, odczyt backendu PASS. Opcjonalnego fragmentu wyglądu WM nie nałożono na osobistą konfigurację. [Prompt](prompts/11-desktop-extras.md) |
| 12 | Odbiór funkcjonalny, wygląd i wydajność | Ukończony dla `20260916-5132708bd8f7` | Wszystkie siedem zadań i obowiązkowe kryteria spełnione; 137 QML, 17 Python, 235 QtTest i 12 integracji PASS. Natywne 18 PNG, osiem trybów/skali, dwa monitory, hotplug, klawiatura, 20 cykli i reload PASS; 60 s idle: 0,033% rdzenia, RSS −408 KiB. Odbiór sprzętu i sesji przez użytkownika zapisany oddzielnie. Późniejsze równoległe zmiany wyglądu wymagają osobnej regresji. [Raport](validation.md), [wynik końcowy](evidence/12-closeout.json), [prompt](prompts/12-validation.md). |
| 13 | Instalacja, przełączenie i rollback | Lokalna sesja przełączona; przenośny instalator niewdrożony | Runtime 110 plików opublikowany przez staging, kopie trzech plików Hyprlanda, autostart, jedna instancja i właściciel powiadomień; panele, pasek i rollback PASS. Pełny przenośny instalator i jego macierz testów niewykonane. [Wyniki i powrót](install.md), [prompt](prompts/13-installation.md). |

Poniższe wpisy sesji zachowują wyniki historyczne. Aktualny stan jest
w tabeli powyżej, końcowym wpisie zamknięcia etapu 12 i raporcie.
Starsze oznaczenia „w toku”, braki Waylanda oraz niewykonany wówczas odbiór
Night Light nie cofają potwierdzonych później wyników.

## Sesja 2026-09-16 — etap 00

### Rezultat i pliki

- `shell.qml` i niezależny `preview.qml`: cienki korzeń Quickshell, zwykłe
  okno demonstracyjne. `preview/`: jawny MockState, współdzielony widok i host.
- `core/Theme.qml`, `Metrics.qml`, minimalne `qmldir`: Mocha, Mauve/Blue,
  nieprzezroczyste powierzchnie, zerowe rogi, monospace.
- `components/`: przycisk, ikona, ramka, suwak i używany przez nie tooltip;
  standardowe wejście Qt, nazwy dostępności, czytelny obrys fokusu.
  `assets/icons/reset.svg`: lokalny zasób, niezależny od fontu ikonowego.
- `scripts/check`, `preview`, `test`, `measure-idle`, `_common.py`:
  kontrola błędów, izolowany render i pomiar. `tests/`: regresje bramki
  i rzeczywiste zdarzenia wejścia Qt.
- `AGENTS.md`, `.gitignore`, README, [development.md](development.md),
  [testing.md](testing.md) i [dowody odbioru](evidence/00-foundation.md).

### Zależności i kontrakty

Potwierdzono Quickshell 0.3.1, Qt 6.11.2, Hyprland executable 0.56.2
(pakiet 0.56.2-3), Qt Quick Controls/Test/SVG, D-Bus i Python.
Narzędzia Qt znaleziono poza PATH; nie trzeba było instalować zależności
potrzebnych do odbioru offscreen. Podgląd nie importuje usług hosta ani PAM.
Nie dodano IPC, trwałych ustawień, usług ani paneli dalszych etapów.
Rola koloru `onAccent` nazywa się w QML `accentText` ze względu na składnię
handlerów sygnałów. Własne entrypointy podglądu są w głównym katalogu konfiguracji.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 13 plików QML, 0 błędów składni/importów/typów |
| `scripts/test` — Python | **PASS**, 6 testów bramki; zła składnia i brak importu → 1, brak narzędzia/wejścia → 2, dobra próbka → 0 |
| `scripts/test` — Qt Quick | **PASS**, 5 testów zachowania + init/cleanup, 7 wyników, 0 błędów/ostrzeżeń |
| `scripts/preview --screenshot docs/evidence/00-foundation.png` | **PASS**, Quickshell ładuje podgląd; zrzut obejrzany, kwadratowe rogi i widoczny fokus |
| `scripts/preview --root --screenshot artifacts/root.png` | **PASS**, główny entrypoint ładuje się; PNG identyczny bajtowo ze zrzutem `preview.qml` |
| `scripts/measure-idle --output docs/evidence/00-idle-60s.json` | **PASS**, 60.000275 s; RSS stałe 79 540 KiB, CPU 0 zarejestrowanych ticków, 3 procesy środowiska / 0 dzieci shella |
| Start prywatnego D-Bus w sandboxie | **Błąd środowiska**, socket: `Operation not permitted`; właściwe testy PASS po dopuszczeniu lokalnych socketów przy zachowanej izolacji |
| `git status --short --branch` | Metadane niedostępne: `not a git repository`; brak deklaracji commitów |

Końcowa kontrola składni skryptów Python i lokalnych linków dokumentacji
również przeszła. Po pomiarze nie pozostał żaden z jego trzech procesów.

Qt offscreen zgłasza dokładnie znane ograniczenie masek okien:
`This plugin does not support setting window masks`. Pozostaje w logach;
pozostałe ostrzeżenia/błędy powodują FAIL. W toku prac wykryto i usunięto
błędy rozwiązywania importów poza katalogiem entrypointu, kolizję nazwy
`onAccent` oraz odczyt nieustawionej zmiennej zrzutu jako `null`. Końcowy
podgląd i pomiar nie mają tych błędów.

### Niewykonany zakres

Prawdziwy Wayland, layer-shell, fokus kompozytora, monitory/hotplug i skale
inne niż 1 nie zostały sprawdzone. Prywatny compositor opisano oddzielnie
w instrukcji testowania; Weston nie jest dostępny w tym środowisku.
Nie wykonywano testów sprzętu, powiadomień hosta, PAM ani lock/suspend.
Nie aktywowano Putkin na pulpicie. Status pozostaje **gotowy do odbioru
środowiskowego**, bez uznawania testu offscreen za pełny odbiór Wayland.

## Ustalenie 2026-09-16 — nawigacja vimowa

Na polecenie użytkownika zapisano stały kontrakt: **h/j/k/l = lewo/dół/góra/prawo,
Enter potwierdza/aktywuje wybraną pozycję**. Zaktualizowano AGENTS.md, projekt
UI, architekturę, prompty 01–02 oraz wymagania testów. Jest to aktualizacja
wymagań; obsługę h/l + Enter w pasku wdrożono następnie w etapie 01.
Wyniki testów etapu 00 dotyczą standardowego wejścia Qt.

## Sesja 2026-09-16 — etap 01

### Rezultat i pliki

- `shell.qml`: jeden adapter, jeden zegar minutowy i jeden kontroler fokusu;
  `Variants` tworzy `BarWindow` dla każdego ekranu Qt.
- `modules/bar/`: pełnoszeroki pasek 32 px z rezerwacją miejsca, workspace
  1–5 oraz aktywne/zajęte/pilne numery poza zakresem. Ograniczona szerokość,
  przewijanie, przypięty aktywny numer, osobny stan widoczności na innym
  monitorze. Zegar według locale, skracana data i tooltip z pełną datą.
- `services/WorkspaceService.qml`, `HyprlandService.qml`: natywne modele
  zdarzeń, zachowanie delegatów przy zmianie stanu, akcja z kontekstem
  monitora i limitem 2 s. Wspólny pasywny socket wykrywa rozłączenie;
  brak cyklicznego `hyprctl`. Stan po utracie połączenia jest niedostępny.
- `core/BarFocus.qml`, `modules/bar/BarIpc.qml`: `bar focus/close`, h/l,
  Enter/Enter numeryczny, Escape i obrys fokusu. Zwykły pasek ma
  `WlrKeyboardFocus.None`; tylko jawna nawigacja używa `Exclusive`.
- `bar-preview.qml`, `preview/BarPreviewWindow.qml`, `MockHyprland.qml`:
  osobny podgląd z atrapami. `scripts/preview --bar` nie ładuje produkcyjnego
  adaptera; dawną opcję `--root` usunięto, gdy korzeń stał się produkcyjny.
- `tests/qml/tst_bar.qml`, `tests/hyprland_protocol.py`, `bar-test.qml`,
  `scripts/test-bar-integration`: wejście Qt oraz rzeczywisty adapter i IPC
  na prywatnych socketach. `scripts/test` obejmuje oba zestawy.
- Tokeny geometrii w `Metrics`, możliwość zmiany koloru tekstu wspólnego
  przycisku, rozszerzony pomiar spoczynku; dokumenty [workspace](workspaces.md),
  [IPC](ipc.md), rozwój, testowanie i README. Logi dowodowe są dozwolone w Git.

### Kontrakty i ograniczenia API

Ponownie potwierdzono Quickshell 0.3.1, Qt 6.11.2 i Hyprland 0.56.2 oraz
oficjalne API tych wersji. `activate(id, monitor)` najpierw skupia monitor,
czeka na zdarzenie i dopiero aktywuje workspace. Widoczny na innym monitorze
workspace zamienia się z bieżącym; niewidoczny jest przenoszony.
Obsługiwane są dispatchery Hyprlang i Lua.

Quickshell 0.3.1 nie udostępnia QML stanu połączenia i zachowuje modele po
zerwaniu IPC. Jeden dodatkowy pasywny socket na proces wykrywa EOF; dane
nadal pochodzą wyłącznie z natywnych modeli. Restart kompozytora wymaga
ponownego uruchomienia Putkin w nowej sesji. Lista obejmuje dodatnie numery,
bez workspace nazwanych o ujemnych ID i `special`.

`PanelWindow` ma w metadanych tej wersji abstrakcyjny interfejs mimo
rejestracji fabryki w runtime. Lokalny wyjątek `uncreatable-type` obejmuje
wyłącznie jego deklarację; błędy importów i właściwości nadal powodują FAIL.
Właściwe utworzenie okna na Waylandzie pozostaje do odbioru.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 27 plików QML |
| `scripts/test` — Python | **PASS**, 6 regresji bramki |
| `scripts/test` — Qt Quick | **PASS**, 11 testów paska + 5 fundamentu, z init/cleanup 20 wyników, bez ostrzeżeń |
| `scripts/test-bar-integration` | **PASS**, osobno Hyprlang i Lua: natywne modele, pilność, potwierdzona sekwencja akcji, realne IPC, zdarzenia dodania/usunięcia monitora i EOF |
| Geometria i wejście Qt | **PASS**, szerokości 1920/1366/600/320, 30 workspace, h/l do numeru 30, kliknięcie, Enter i Enter numeryczny, fokus, timeout, wpisywanie hjkl w polu |
| `scripts/preview --bar` | **PASS**, zrzuty 1920×1080 i 1366×768; osobny zrzut widocznego fokusu; [dowody](evidence/01-bar.md) |
| `scripts/measure-idle --bar --output docs/evidence/01-idle-60s.json` | **PASS**, 60.000261 s, RSS stałe 87 552 KiB, 0 zarejestrowanych ticków CPU, 3 procesy środowiska / 0 dzieci shella |
| Prywatny Hyprland w bubblewrap | **Nieudany start środowiska**, kod 134, `CBackend::create() failed!`; [log](evidence/01-wayland-attempt.log) |

Test natywny celowo działa bez `wl_display` i zrywa socket. Dokładne
diagnostyki braku Waylanda/mapowania toplevel i `PeerClosedError` pozostają
widoczne i są oczekiwane; inne ostrzeżenia powodują FAIL. Podgląd ma tylko
znaną diagnostykę masek okien offscreen. Nie wyciszono błędów importów.

Uśpienie komputera przerwało końcowe dokumentowanie. Pomiar i testy były
już zakończone, pliki zachowane; kontrola po wznowieniu nie wykazała
pozostawionych procesów testowych. Metadane Git nadal są niedostępne;
nie utworzono commitów.

### Niewykonane kryteria

Rzeczywisty layer-shell/rezerwacja 32 px, tworzenie i usuwanie okien po
hotplug ekranów Qt, oddawanie fokusu aplikacjom oraz skale inne niż 1
pozostają niezweryfikowane. Prywatny compositor nie wystartował; brak
`/dev/dri`, a Aquamarine 0.15.0 wymaga alokatora DRM. Zdarzenia na atrapach
nie zastępują tego odbioru. Nie aktywowano Putkin na pulpicie i nie rozpoczęto
etapu 02. Status: **gotowy do odbioru środowiskowego**, bez deklaracji
pełnego ukończenia etapu.

## Sesja 2026-09-16 — etap 02

### Rezultat i pliki

- `core/PanelCoordinator.qml`, `PanelHost.qml`, `PanelIpc.qml`: jawne
  otwieranie/przełączanie/zamykanie, jedna sesja na cały shell, wybór
  monitora i błędy nieznanej powierzchni/braku ekranu. Loader wstrzykiwany
  jawnie; produkcja używa `LazyLoader.activeAsync` bez przedwczesnego
  odczytu `item`. Zamknięcie wyłącza interakcję od razu, niszczy po 120 ms.
- `modules/quicksettings/`: natywne `InteractivePanelWindow` z maską
  wejścia i `HyprlandFocusGrab`, współdzielone `PanelSurface` z przewijaniem
  oraz `QuickSettingsView`. `modules/settings/`: opis Mocha, dwa akcenty,
  tło i krój pisma. Bez edytora, zapisu ani atrap usług kolejnych etapów.
- `shell.qml`: jeden koordynator/host/loader; `modules/bar/` i `BarFocus`:
  działający przycisk Quick Settings, aktywne wypełnienie, tooltip, wejście
  z końca listy workspace i powrót fokusu. Zwykłe aktualizacje workspace
  zachowują fokus na przycisku panelu. Produkcyjne tooltipy używają
  `Popup.Window`, by wyjść poza okno paska.
- `components/NavigationButton.qml`, `PanelText.qml`, `Button.qml`,
  `Metrics`: współdzielone przyciski z h/j/k/l, Enter/Enter numerycznym,
  standardowym wejściem Qt, tokeny szerokości/odstępu/fade panelu.
- `preview/PanelPreviewScene.qml`, `PanelPreviewWindow.qml`,
  `panels-preview.qml`, `panels-test.qml`: jawne atrapy, rzeczywisty
  Quickshell/LazyLoader w podglądzie i testowy handler obserwacyjny.
- `tests/qml/tst_panels.qml`, `scripts/test-panels-integration`,
  rozszerzone `scripts/test`, `preview`, `measure-idle` oraz dokumentacja
  [paneli](panels.md), [IPC](ipc.md), rozwoju, testowania i README.

### Kontrakty i napotkane ograniczenia

Ponownie sprawdzono lokalne Quickshell 0.3.1 / Qt 6.11.2 i ich oficjalne
API. `PanelHost` i koordynator nie importują modułów Quickshella, bo ich
pluginy w tej instalacji są częścią executable i nie mogą być ładowane
przez `qmltestrunner`. Test Qt otrzymuje adapter `QtQuick.Loader`, a test
integracyjny używa właściwego `LazyLoader`. Nie przepisano importów.

Fabryka `PanelWindow` zachowuje lokalny wyjątek metadanych z etapu 01.
Nierozwiązywalny przez qmllint typ `Margins` zastąpiono przezroczystym
odstępem z dokładną maską wejścia. Importy i typy właściwości są nadal
kontrolowane. Próba użycia nazwy metody `escape` została odrzucona przez
runtime Qt; zmieniono ją na `dismissOrCollapse`, po czym testy przeszły.

Kliknięcie poza panelem korzysta z natywnego graba Hyprlanda. Putkin nie
odtwarza zdarzenia; dostarczenie go oknu pod spodem zależy od kompozytora.
Testowy `MouseArea` zastępuje tylko tę granicę, a nie cały koordynator.
Dokładne reguły powrotu fokusu i wyłączności zapisano w [panels.md](panels.md).

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 42 pliki QML, 0 błędów składni/importów/typów |
| `scripts/test` — Python | **PASS**, 6 regresji bramki |
| `scripts/test` — Qt Quick | **PASS**, 32 wyniki: 10 testów paneli, 11 paska, 5 fundamentu oraz init/cleanup; 0 ostrzeżeń |
| `scripts/test` — natywny adapter | **PASS**, prywatne sockety Hyprlanda, osobno Hyprlang i Lua |
| `scripts/test-panels-integration` (także w `scripts/test`) | **PASS**, realne IPC `ui`, LazyLoader, fokus po IPC, zmiana strony/monitora, hotplug atrap, błędy i 20 cykli; po zamknięciu 0 żywych powierzchni i 0 dzieci shella |
| h/j/k/l, Enter, Enter numeryczny, Tab, strzałki, Spacja, pole tekstowe | **PASS**, rzeczywiste zdarzenia Qt, pomijanie wyłączonych kontrolek, lokalne Escape i powrót fokusu |
| Geometria i przewijanie | **PASS**, 320×220 oraz szerokości 320/600/1366/1920; długi tekst i zmiana rozmiaru zachowują widoczny fokus |
| `scripts/preview --panels` | **PASS**, obejrzane zrzuty Quick Settings 1920×1080, ustawień 1366×768 i 320×220; [dowody](evidence/02-panels.md) |
| `scripts/measure-idle --panels --output docs/evidence/02-idle-60s.json` | **PASS**, 60 s, RSS stałe 87 772 KiB, 0 zarejestrowanych ticków CPU, 3 procesy środowiska / 0 dzieci shella |
| Pamięć w ostatnim teście 20 cykli | RSS 95 376 → 99 472 KiB, maksimum 99 732 KiB; skok na początku, od cyklu 13 do 20 stałe 99 472 KiB. [Próbki](evidence/02-panels-cycles.json) |
| Pierwszy start testów w sandboxie | **Błąd środowiska**, socket D-Bus `Operation not permitted`; testy PASS po dopuszczeniu prywatnych socketów, z zachowaną izolacją |
| Środowisko Waylanda | Nadal brak `/dev/dri` i zainstalowanego Westona/Sway/Cage; nie ponawiano znanej nieudanej próby Aquamarine ani nie uruchamiano shella na aktywnym pulpicie |

Pomiary nie ustanawiają limitu pamięci ani dowodu braku wszystkich wycieków;
końcowa część serii jest stabilna, a liczniki potwierdzają niszczenie
podwidoków. Podgląd zachowuje znaną diagnostykę masek offscreen; test natywny
adaptera zachowuje diagnostyki braku Waylanda i celowego EOF. Inne błędy
powodują FAIL, bez wyciszania importów.

### Niewykonane kryteria

Natywne utworzenie `PanelWindow`, jego geometria/maska, zwolnienie klawiatury
innej aplikacji, `HyprlandFocusGrab` przy kliknięciu poza panelem i na innym
monitorze, tooltip `Popup.Window`, hotplug ekranów Qt oraz mieszane skale
pozostają **niezweryfikowane na Waylandzie**. Widoki offscreen i atrapy
potwierdzają logikę, nie te zachowania kompozytora. Putkin nie został
aktywowany na pulpicie. Brak dostępnych metadanych Git; bez commitów.
Etap 03 nie został rozpoczęty. Status etapu 02: **gotowy do odbioru
środowiskowego**, bez deklaracji pełnego ukończenia.

## Sesja 2026-09-16 — etap 03

### Rezultat i pliki

- `modules/settings/SettingsView.qml`, `ColorEditor.qml`: strona Wygląd,
  po sześć presetów i pole HEX dla dwóch akcentów, ograniczenie ruchu,
  jawny zapis, anulowanie i reset wersji roboczej. Widoczne błędy i
  rozwiązywanie konfliktu przez odrzucenie podglądu/wczytanie pliku.
- `core/Appearance.js`, `Settings.qml`, `SettingsFile.qml`: pojedyncze
  defaults, ścisła walidacja schematu, stan utrwalony/roboczy/podgląd,
  kolejka FileView z porównaniem przed zapisem i odczytem po `saved`.
  Pierwszy zapis tworzy także katalogi; bez dodatkowego procesu i pollingu.
- `Theme.qml`, `components/Button.qml`, `TextField.qml`,
  `WorkspaceButton.qml`: reaktywne akcenty, kontrast tekstu czerni/bieli,
  jasny obrys przy ciemnym akcencie i standardowe wejście Qt. Role
  success/warning/error zachowują wartości. PanelHost/PanelSurface
  respektują ograniczenie ruchu.
- `shell.qml`, `PanelCoordinator.qml`: jeden model w korzeniu, jawny
  adapter i przekazanie do widoków; odrzucenie podglądu przy wszystkich
  ścieżkach zamknięcia niezależnie od ładowania panelu.
- `preview/MockSettingsFile.qml`, podgląd paneli, `settings-test.qml`,
  `tests/qml/tst_settings.qml`, `scripts/test-settings-integration`:
  osobno testy wejścia z atrapą storage i testy prawdziwego pliku.
  `scripts/test` obejmuje nową integrację. `scripts/preview` przyjmuje
  akcenty wyłącznie do prywatnego pliku testowego.
- `config/settings.example.json`, [settings.md](settings.md), README,
  kontrakty architektury/wyglądu/paneli, rozwój/testy i
  [dowody etapu 03](evidence/03-appearance.md).

### Zależności i decyzje API

Potwierdzono lokalne **Quickshell 0.3.1 / Qt 6.11.2** oraz odpowiadające
im oficjalne API i kod FileView. Nie dodano zależności. FileView tej wersji
tworzy katalogi, ale nie emituje `saved` dla identycznej treści i zeruje
bieżącą operację dopiero po sygnale. Operacje następują po `Qt.callLater`;
identyczny zapis potwierdza świeży odczyt. Dodatkowa weryfikacja po `saved`
chroni też przed uznaniem samego sygnału za dowód udanego commitowania.

Nieobsługiwany schemat i nieznane pola blokują zapis, również po resecie.
Uszkodzony plik pozostaje nietknięty; model zachowuje ostatni poprawny stan
procesu, a na zimnym starcie używa defaults. Konflikt nie niszczy pola,
kursora ani podglądu. Pełny reload shella odrzuca edycję. Produkcyjne IPC
nie zostało poszerzone; `probe` istnieje tylko w entrypoincie testowym.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 49 plików QML, 0 błędów składni/importów/typów |
| `scripts/test` — Python | **PASS**, 6 regresji bramki |
| `scripts/test` — Qt Quick | **PASS**, 67 wyników, w tym 35 ustawień; 0 błędów/ostrzeżeń. [Log](evidence/03-tests.log) |
| `scripts/test` — natywne integracje | **PASS**, adapter Hyprlang/Lua, IPC/LazyLoader, 20 cykli paneli i rzeczywiste ustawienia FileView |
| `scripts/test-settings-integration --output docs/evidence/03-settings.json` | **PASS**, 10 grup: brak pliku/rodzica, atomowy zapis, restart, reset, konflikt i porównanie przed zapisem, malformed/wersja/HEX, chmod odczytu/zapisu/tworzenia katalogu, odtworzenie pliku, soft/hard reload i hotplug atrapy. [Raport](evidence/03-settings.json) |
| 20 zmian zewnętrznych i reloadów | **PASS**, zapisy in-place i atomowe, ten sam panel/pole, fokus `accentField`, kursor 7, bez nadpisania pliku ani pętli zapisu |
| Zapis po potwierdzeniu | **PASS**, wersja utrwalona i komunikat sukcesu nie zmieniają się podczas oczekiwania; sygnały prawdziwego FileView, odczyt pliku i ponowienia po błędach |
| Klawiatura i anulowanie | **PASS**, presety, własny HEX, hjkl jako tekst, h/j/k/l poza polami, Enter/Enter numeryczny, Spacja, Tab/Shift+Tab, 10 dróg zamknięcia, mały ekran i długi tekst |
| `scripts/preview --panels --scenario settings` | **PASS**, obejrzane dwa widoki 1366×768: [Mauve/Blue](evidence/03-appearance-mauve.png) i [Teal/Peach](evidence/03-appearance-teal.png); dodatkowo ciemny/biały akcent i 320×220 |
| `scripts/measure-idle --panels --output docs/evidence/03-idle-60s.json` | **PASS**, 60.000274 s, RSS 91 996 → 92 124 KiB, 0 ticków CPU, 3 procesy środowiska / 0 dzieci shella. [Pomiar](evidence/03-idle-60s.json) |
| Pierwsze testy w sandboxie | Socket D-Bus: `Operation not permitted`; właściwe przebiegi po dopuszczeniu prywatnych socketów, z zachowaniem izolacji |
| Środowisko Waylanda | Nadal brak `/dev/dri`, Westona, Sway i Cage; nie uruchamiano drugiego pełnego shella na aktywnym pulpicie |

W trakcie implementacji poprawiono zależne od dawnego układu testy
przewijania, kolizję nazwy pomocnika testowego z właściwością Qt `focus`
i dobór kontrastu dla średnio jasnej szarości. Końcowe wyniki powyżej
dotyczą poprawek; po uporządkowaniu początkowego odczytu powtórzono bramkę
oraz integrację FileView. Dokładne komunikaty offscreen, natywnego testu
Hyprlanda i inotify przy celowym chmod(000) pozostają w logach. Pozostałe
diagnostyki powodują FAIL; nie wyciszono importów.

### Niewykonane kryteria i ograniczenia

Natywny layer-shell, HyprlandFocusGrab/kliknięcie poza panelem, oddanie
fokusu innej aplikacji, rzeczywiste monitory/hotplug i mieszane skale nadal
pozostają **niezweryfikowane na Waylandzie**. Test dwóch pasków sprawdza
reaktywność współdzielonego Theme, nie fizyczne wyjścia. Nie aktywowano
Putkin na pulpicie. Metadane Git nadal niedostępne, bez commitów.

Ochrona konfliktu jest optymistyczna: FileView nie udostępnia atomowego
porównania i podmiany ani blokady respektowanej przez obce edytory.
Odczyty przed/po zapisie i watch nie eliminują wąskiego wyścigu z zapisem
innej aplikacji pomiędzy porównaniem a podmianą. Szczegóły:
[settings.md](settings.md). Nie deklarujemy transakcji między aplikacjami.

Status etapu 03: **gotowy do odbioru środowiskowego**. Na koniec etapu 03 etapy 04+ nie zostały
rozpoczęte; nie uznano offscreen za pełny odbiór.

## Sesja 2026-09-16 — etap 04

### Rezultat i pliki

- `services/AudioService.qml`, `PipewireBackend.qml`, `AudioIpc.qml`: jeden
  model wyjścia, dostępność, poziom, mute, lista, walidacja i błędy operacji.
  Natywny tracker śledzi wyłącznie domyślny sink. Dane urządzeń płyną
  zdarzeniowo; brak `wpctl`, pollingu i procesów pomocniczych produkcji.
- `modules/quicksettings/AudioSection.qml` i istniejące widoki: suwak
  0–100%, wyciszenie i rozwijany wybór wyjścia. Pionowa nawigacja, h/l,
  Enter, standardowe wejście Qt, przewijanie i odzyskiwanie fokusu po
  utracie urządzenia. Pasek ma ikonę, procent i regulację kółkiem.
- `services/OsdService.qml`, `core/OsdHost.qml`, `modules/osd/`:
  jeden host i loader, neutralny widok poziomu/etykiety/ikony,
  reaktywny akcent i timeout 1500 ms. OSD przy dolnej krawędzi właściwego
  monitora; bez fokusu, obszaru zastrzeżonego ani wejścia. Aktywne
  Quick Settings pomija OSD. `shell.qml` nadal jest korzeniem kompozycji.
- `assets/icons/volume*.svg`, wspólne tokeny w Metrics; podgląd `--audio`
  z `MockAudioBackend`/`MockAudioNode`. Istniejące podglądy etapów 00–03
  zachowują osobne scenariusze.
- `tests/qml/tst_audio.qml`, `audio-test.qml`, `tests/pipewire.conf`,
  `scripts/test-audio-integration`, rozszerzone `scripts/test` i `preview`.
  Test natywny uruchamia rzeczywisty PipeWire tylko z wirtualnymi sinkami;
  nie korzysta z urządzeń, menedżera sesji ani sprzętowych modułów.
- [Kontrakt audio](audio.md), [IPC i przykłady skrótów](ipc.md), dokumenty
  architektury, wyglądu, testów, środowiska, README i [dowody](evidence/04-audio.md).

### Wersje i decyzje API

Ponownie potwierdzono Quickshell 0.3.1 i Qt 6.11.2, dodatkowo PipeWire
1.6.8 i zainstalowany WirePlumber 0.5.17. Sprawdzono metadane lokalne,
oficjalną dokumentację tych wersji i źródła Quickshell 0.3.1.
WirePlumber nie był uruchamiany przez testy.

Settery natywnego audio emitują optymistyczny stan bez sygnału błędu/
potwierdzenia. Po 100 ms od ostatniej komendy adapter ponownie wiąże
tracker i odczytuje stan serwera. Dopiero zgodna próbka kończy operację;
timeout 1800 ms lub utrata wyjścia daje błąd. Preferowany sink nie udaje
rzeczywistego domyślnego wyjścia. Zewnętrzne wzmocnienie ponad 100% jest
wyświetlane, a własne komendy pozostają ograniczone do 0–100%.

Pragma `QS_PIPEWIRE_IMMEDIATE_RECONNECT=1` zapewnia obsługę serwera
uruchomionego po shellu. Natywny reconnect 0.3.1 działa dla domyślnego
socketa `pipewire-0`; niestandardowy `PIPEWIRE_REMOTE` wyłącza watcher
i wymaga restartu shella po powrocie takiego serwera. [Szczegóły](audio.md).

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 61 plików QML, 0 błędów; [log](evidence/04-check.log). |
| `scripts/test` | **PASS**, 6 testów Python, 85 wyników QtTest, natywny Hyprland w obu wariantach, IPC/LazyLoader paneli, FileView i natywne audio; [log](evidence/04-tests.log). |
| Końcowy QtTest po ochronie fokusu innych kontrolek | **PASS**, 85 wyników, 0 błędów; [log](evidence/04-qt.log). |
| `scripts/test-audio-integration --idle --output docs/evidence/04-audio.json` | **PASS**: start bez serwera i późniejsze połączenie, brak sinka, poziom/mute/0/100, serie, zewnętrzne Props, wybór/timeout, usunięcie sinka, restart, soft/hard reload i 20 cykli OSD; [raport](evidence/04-audio.json). |
| Zasoby po 20 cyklach OSD | 20 utworzonych / 20 zniszczonych widoków; 0 żywych OSD. RSS 134 692 → 126 236 KiB, ostatnie 11 próbek 126 236 KiB, bez narastania. |
| 60 s spoczynku, świeży proces po 2 s rozgrzewki | **PASS**, 60,000177 s; RSS 98 336 → 99 588 KiB, zakres 98 308–99 588 KiB; 0 zarejestrowanych ticków CPU; 3 procesy środowiska, 0 dzieci shella. Prywatny serwer testu osobno: 6 632 KiB. |
| `scripts/preview --audio`, 1920×1080 / 1366×768 / 320×220 | **PASS**; panel, OSD z Teal oraz brak usługi. Wszystkie cztery zrzuty otwarto i oceniono; [dowody](evidence/04-audio.md). |
| Składnia zmienionych skryptów Python i sprzątnięcie | **PASS**; zapisane PID-y shella, D-Bus i prywatnego PipeWire nie istnieją po zakończeniu. |

Warunki pomiaru odpowiadają etapowi 03: offscreen/software, skala 1,
1920×1080, 30 workspace, zegar minutowy i zamknięty panel; doszły natywne
audio i niezaładowany host OSD. W porównaniu z 03 startowy RSS wzrósł
o 6 340 KiB. Podczas bieżącej minuty wystąpiła mała korekta w 29 s
oraz pojedynczy skok o 1 280 KiB w 35 s; do końca RSS był stały.
Przyczyny skoku nie ustalono; nie opisujemy wyniku jako stałej pamięci
ani pełnego dowodu braku wycieków. Dwadzieścia cykli widoku nie wykazało
narastania, a dłuższy odbiór pozostaje częścią etapu 12.

Sandbox blokował lokalne sockety (`Operation not permitted`); właściwe
uruchomienia wykonano poza nim, zachowując prywatne XDG, D-Bus i PipeWire.
Oczekiwane diagnostyki braku/zerwania PipeWire są dopasowane dokładnie,
zapisane w raporcie i pozostają w logu. Pozostałe ostrzeżenia/importy
powodują FAIL. Nie wyciszano globalnie żadnej kategorii logowania.

### Niewykonane kryteria

Fizyczne audio, polityka WirePlumber, rzeczywiste przełączenie urządzeń
USB/Bluetooth/HDMI, natywne warstwy Waylanda, przepuszczanie kliknięć
przez OSD, brak przejęcia fokusu innej aplikacji oraz rzeczywiste monitory,
hotplug i mieszane skale pozostają **niezweryfikowane**. Testy Item/offscreen
potwierdzają zachowanie modeli i kontrolek, nie kontrakt kompozytora.

Nie aktywowano Putkin na pulpicie i nie zmieniano konfiguracji skrótów
użytkownika. Metadane Git nadal są niedostępne (`not a git repository`);
nie utworzono commita. Status etapu 04: **gotowy do odbioru środowiskowego**.
Na koniec etapu 04 etapu 05 ani dalszych nie rozpoczęto.

## Sesja 2026-09-16 — etap 05

### Rezultat i pliki

- `services/BrightnessService.qml`, `BrightnessBackend.qml`, `Backlight.js`
  i `BrightnessIpc.qml`: jeden model, jeden proces w locie, deterministyczny
  wybór backlight, walidacja zakresu, kolejka najnowszego celu i odczyt
  potwierdzający. Ograniczenie zapisów do jednego na 120 ms, timeout
  1500 ms, SIGTERM/SIGKILL i obsługa braku executable/uprawnień/urządzenia.
- `modules/quicksettings/BrightnessSection.qml`, `QuickSettingsView.qml`,
  `PanelSurface.qml`, `core/PanelHost.qml`: suwak 1–100%, drugi akcent,
  diagnostyka/odświeżenie, h/j/k/l i standardowe wejście Qt, odczyt przy
  każdym otwarciu panelu, również podczas fade. Brak urządzenia ukrywa
  regulację; błąd zapisu nie pokazuje żądanego poziomu jako sukcesu.
- `services/OsdService.qml`, `modules/osd/LevelOsd.qml`, `OsdWindow.qml`,
  `assets/icons/brightness.svg`, `shell.qml`: audio i jasność współdzielą
  jeden host/loader. Typ, ikona, etykieta i akcent zmieniają się po akcji;
  panel tłumi oba OSD. Nie dodano właściciela logind ani kolejnych usług.
- `preview/MockBrightnessBackend.qml`, istniejąca scena/okno podglądu,
  `scripts/preview --brightness`; `tests/qml/tst_brightness.qml`,
  `brightness-test.qml`, `tests/brightnessctl_fake.py` i
  `scripts/test-brightness-integration`, dołączony do `scripts/test`.
  Integracja używa prawdziwego Process/IPC i atrapy executable operującej
  wyłącznie na prywatnym JSON. Test bez wskazania atrapy nie może wywołać
  hostowego brightnessctl.
- [Kontrakt jasności](brightness.md), [IPC i skróty](ipc.md), README,
  kontrakty wyglądu/architektury/paneli/audio, środowisko i testowanie.
  [Pięć obejrzanych zrzutów i raporty](evidence/05-brightness.md).

### API, zależności i ograniczenia backendu

Potwierdzono lokalne Quickshell 0.3.1, Qt 6.11.2 i brightnessctl 0.5.1-3
(`--version`: 0.5), oficjalną dokumentację oraz źródła odpowiednich wersji.
Nie instalowano zależności. Proces dostaje listę argumentów i locale C.
Brak pełnych metadanych `QProcess::ExitStatus` obsłużono przez udokumentowane
połączenie sygnału `connect()`, bez wyłączenia diagnostyki lintu/importów.
Brak programu obsługuje `runningChanged`, bo w 0.3.1 nie emituje `exited`.

`set` wypisuje żądaną wartość, dlatego dopiero osobne `info` potwierdza
sukces. Stare identyfikatory i rewizje żądań nie nadpisują nowszego celu.
Odczytane 0 jest widoczne, lecz własny zapis nie schodzi poniżej 1% ani
jednostki sprzętowej. Drobne zmiany na grubym zakresie nadal przesuwają
o przynajmniej jeden poziom. Pierwszy wybór preferuje największy max,
a potem stabilną nazwę; zachowuje urządzenie do jego zniknięcia.

Odczyty: start, własna akcja, otwarcie panelu i jawne `refresh()`.
Brak wiarygodnej subskrypcji zmian w brightnessctl: nie dodano watchera
sysfs ani pollingu, również przy otwartym panelu. Zewnętrzna zmiana
pojawia się po odświeżeniu, bez OSD. `brightness` sterownika nie jest
pomiarem `actual_brightness` ani luminancji. Etap 10 może podłączyć refresh
do wznowienia; nie implementowano tego wcześniej.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 68 plików QML, 0 błędów. [Log](evidence/05-check.log). |
| `scripts/test` | **PASS**, 6 testów Python, 111 wyników QtTest, integracje Hyprland Hyprlang/Lua, paneli, FileView, prywatnego PipeWire i jasności. [Log](evidence/05-tests.log). |
| QtTest jasności | **PASS**, 26 wyników: 0/brak/nieznane max, 1–100%, mały zakres, uprawnienia, timeout, drag/końcowa wartość, odwrócone stare odpowiedzi, ponowne otwarcie, klawiatura, fokus, 320×220 i współdzielenie OSD. |
| `scripts/test-brightness-integration --idle --output docs/evidence/05-brightness.json` | **PASS**, rzeczywisty Process/IPC/LazyLoader na atrapowym executable: zapis/odczyt, błędy, SIGKILL po ignorowanym SIGTERM, brak narzędzia, soft/hard reload, 20 cykli i pomiar. [Raport](evidence/05-brightness.json), [log](evidence/05-brightness.log). |
| Zasoby po 20 cyklach OSD jasności | **PASS**, 20 utworzonych / 20 zniszczonych, 0 żywych widoków i 0 dzieci adaptera. RSS 132 784 → 127 552 KiB, minimum 122 944 KiB; ostatnie sześć próbek 127 552 KiB. |
| 60 s spoczynku, świeży proces po 2 s rozgrzewki | **PASS**, 60,000102 s; 0 nowych komend brightnessctl, 0 zarejestrowanych ticków CPU, RSS 96 532 → 97 684 KiB, 3 procesy środowiska / 0 dzieci shella. |
| `scripts/test-audio-integration --output docs/evidence/05-audio-regression.json` | **PASS**, regresja po zmianie wspólnego OSD i oczekiwania na destrukcję; 20 cykli, restart/reload, prywatne wirtualne sinki. [Raport](evidence/05-audio-regression.json). |
| `scripts/preview --brightness` | **PASS**, panel 1920×1080, OSD/Teal 1366×768, brak urządzenia, odmowa zapisu i fokus na jasności przy 320×220. Pięć obrazów otwarto i oceniono. |
| Składnia zmienionych skryptów Python | **PASS**, pięć skryptów sprawdzonych przez `ast.parse`. |

Pierwszy pełny test miał **111/111 PASS Qt**, ale nieudany test audio:
OSD został utworzony i zniszczony, zanim sprawdzenie IPC zobaczyło 100-ms
okno. Testowy timeout cykli zwiększono do 400 ms; produkcyjny nadal 1500 ms.
Kolejna kontrola zasobów wykryła moment `loaded=false`, lecz jeszcze przed
`Component.onDestruction` (12/11). Testy audio/jasności czekają teraz na
oba warunki; nie zmniejszono wymagań względem zwolnienia zasobów.
Po tej zmianie ponownie przeszły osobne integracje audio oraz jasności
z pomiarem. Kod QML i 111 wyników pełnej regresji pozostały bez zmian.

Pomiar: offscreen/software, skala 1, 1920×1080, 30 workspace, zegar minutowy,
zamknięty panel i OSD. Prawdziwy adapter Process zakończył odczyt; audio
i monitory są atrapami. Nie porównujemy więc RSS wprost z etapem 04,
który mierzył natywne PipeWire. RSS w tej minucie wzrósł o 1152 KiB;
seria cykli zawierała spadki i późniejszy skok, potem sześć równych próbek.
Wyniki nie są deklaracją stałej pamięci ani pełnym dowodem braku wycieków.
Wszystkie zapisane PID-y atrap, shella i prywatnego D-Bus zniknęły po teście.

Sandbox blokował prywatne sockety D-Bus (`Operation not permitted`).
Testy uruchomiono po dopuszczeniu socketów, z zachowaną izolacją.
Celowy brak executable ma dokładnie dopasowaną diagnostykę w logu/raporcie;
pozostałe ostrzeżenia/importy powodują FAIL. Nie wyciszano kategorii logów.

### Niewykonane kryteria

Fizyczne podświetlenie laptopa, polityka uprawnień/udev/logind, mapowanie
kilku urządzeń backlight, sprzętowe klawisze firmware, rzeczywisty Wayland,
przepuszczanie kliknięć przez OSD, fokus innej aplikacji, monitory/hotplug
i mieszane skale pozostają **niezweryfikowane**. Potwierdzono ponownie brak
`/dev/dri`, Westona/Sway/Cage; nie ponawiano wcześniejszego nieudanego
uruchomienia Aquamarine ani nie uruchamiano pełnego shella na pulpicie.

Nie zmieniano fizycznej jasności, skrótów ani autostartu. Brak dostępnych
metadanych Git (`not a git repository`), bez commita. Status etapu 05:
**gotowy do odbioru środowiskowego**. Etapu 06 ani dalszych nie rozpoczęto.

## Sesja 2026-09-16 — etap 06

### Rezultat i pliki

- `services/BatteryService.qml`, `UPowerBackend.qml`: pojedynczy model
  DisplayDevice, procent, ładowanie, czas z backendu, brak/nieznany stan
  i ostrzeżenia niezależne od akcentów. Peryferia nie tworzą baterii
  komputera. Brak głównej baterii usuwa przycisk paska.
- `services/TrayService.qml`, `TrayMenuAdapter.qml`, `modules/tray/`:
  natywny model SNI, aktywacja/secondary activation, prawdziwe tooltipy,
  menu QsMenuOpener, separatory, checkbox/radio i podmenu. Tray ma limit
  szerokości oraz overflow. h/j/k/l, Enter i standardowe kontrolki Qt;
  Menu/Shift+F10 otwiera menu, Shift+Enter wywołuje secondary activation.
- `core/PanelCoordinator.qml`, `PanelHost.qml`, istniejący host okna
  i `PanelSurface`: menu/overflow zastępuje Quick Settings i Wygląd;
  podmenu zachowuje tę samą rodzinę i jedno okno. Kotwiczenie przy
  przycisku, ograniczenia rozmiaru, przewijanie i odzyskiwanie fokusu.
- `modules/bar/BatteryButton.qml`, `BarView.qml`, `BarWindow.qml`,
  `WorkspaceStrip.qml`, `QuickSettingsView.qml`, `Metrics.qml`,
  `components/ToolTip.qml`, `shell.qml`: wspólne zależności i tokeny,
  kompaktowy pasek od 320 px, krótki stan baterii w panelu i zawijanie
  długiego tooltipa. Korzeń pozostaje kompozycją usług i hostów.
- `preview/MockBatteryBackend.qml`, `MockObjectModel.qml`, `MockTray.qml`,
  `MockTrayItem.qml`, `MockMenuEntry.qml`, istniejąca scena/okno podglądu,
  `scripts/preview --status --scale`: dane zastępcze wyłącznie w testach.
- `tests/qml/tst_status.qml`, `tests/status_dbus_fake.py`, `status-test.qml`,
  `scripts/test-status-integration` i integracja z `scripts/test`.
  [Kontrakt](battery-tray.md), [zrzuty i raporty](evidence/06-battery-tray.md),
  aktualne README, architektura, wygląd, panele, środowisko i testowanie.

### Wersje i decyzje API

Sprawdzono Quickshell **0.3.1**, Qt **6.11.2**, UPower **1.91.4-1**,
glib2 **2.88.3-1**, systemd **261.3-1** oraz oficjalne API/źródła tych
wersji. Testy wykorzystują zastane python-dbus **1.4.0-2** i
python-gobject **3.56.3-1**. Nie instalowano pakietów.

Natywny UPower 0.3.1 nie obserwuje właściciela usługi: brak przy starcie
nie jest ponawiany, zanik może pozostawić stare dane. Adapter uzupełnia
wyłącznie tę lukę zdarzeniowym `gdbus monitor` i odczytami JSON przez
`busctl` po powrocie usługi. Jeden stały proces obserwatora, najwyżej jeden
przejściowy odczyt, brak pollingu i zapisu do sprzętu. Normalny pierwszy
start korzysta z natywnego DisplayDevice; fallback obsługuje też reload
ze starym singletonem. Obserwator oraz jego PID są zwalniane przy reloadzie.
Awaria samego systemowego D-Bus/obserwatora wymaga restartu Putkin.

Menu używa natywnego DBusMenu i utrzymuje otwieracze rodziców do zamknięcia
potomków. W tej wersji AboutToShow/GetLayout pobiera całe drzewo od korzenia;
wejście do podmenu emituje opened. Nie dodano własnego klienta protokołu,
plugina C++ ani demona. Format ustawień i produkcyjne IPC pozostają bez zmian.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 84 pliki QML, 0 błędów; [log](evidence/06-check.log). |
| `scripts/test` | **PASS**, 6 regresji Python, **132 wyniki QtTest** i integracje Hyprland Hyprlang/Lua, paneli, FileView, audio, jasności oraz natywnego UPower/SNI/DBusMenu; [log](evidence/06-tests.log). |
| Końcowa regresja geometrii paneli | **PASS**, 12 testów paneli + 21 baterii/traya; [Qt](evidence/06-final-qt.log), natywne IPC/LazyLoader i 20 cykli [raport](evidence/06-panels-regression.json). |
| QtTest etapu 06 | **21 PASS**: stany baterii/peryferia, 0/błędny procent, czasy, role ostrzeżeń, klawiatura/mysz/tooltip, overflow, podmenu, wyłączone pozycje, usuwanie klienta i fokusu, hotplug atrapy oraz geometria 320–1920 px. |
| `scripts/test-status-integration --idle --output docs/evidence/06-status.json` | **PASS**, 7 grup: natywne dane/sygnały, brak i powrót UPower, 16 klientów SNI, menu/podmenu/akcje i aktualizacja układu, usuwanie oraz Passive, 20 cykli i soft/hard reload; [raport](evidence/06-status.json), [log](evidence/06-status.log). |
| Zasoby menu po 20 cyklach | **PASS**: wszystkie powierzchnie zniszczone; po 20 opened i closed korzenia oraz podmenu. RSS 127 940 → 127 668 KiB, zakres 127 412–128 152 KiB. |
| 60 s spoczynku | **PASS**, 60,002846 s; 0 nowych odczytów baterii, 0 nowych ticków CPU shella i gdbus. RSS shella 105 148 → 105 276 KiB; gdbus stałe 6008 KiB. |
| Sprzątnięcie | **PASS**: sprawdzone 10 PID-ów shella, obserwatorów, atrapy i D-Bus nie istnieje po zakończeniu; stare obserwatory znikają także po obu reloadach. |
| Podgląd `--status` | **PASS**, sześć otwartych i ocenionych zrzutów: 1920×1080, 1366×768 i 320×220; skale 1 / 1,25 / 1,5 / 2; ostrzeżenie z akcentem Teal, brak baterii, ładowanie, menu i overflow. [Dowody](evidence/06-battery-tray.md). |
| Składnia zmienionych skryptów Python | **PASS**, `ast.parse` dla preview, test, test-status-integration i status_dbus_fake.py. |

Pomiar spoczynku: świeży proces po 2 s rozgrzewki, offscreen/software,
1920×1080, 30 workspace, zegar minutowy, skala 1, zamknięty panel,
natywne UPower i 13 zarejestrowanych klientów traya (jeden Passive).
Audio/jasność wyłączone. Shell ma jedno stałe dziecko gdbus; atrapa i D-Bus
są narzędziami testowymi. Warunki różnią się od etapu 05, więc RSS nie
jest bezpośrednim porównaniem. Wynik 0 ticków ma rozdzielczość licznika
systemowego i nie dowodzi zerowej pracy; krótki pomiar nie dowodzi braku
wszystkich wycieków. Seria cykli nie wykazuje narastania RSS.

Pierwsza pełna regresja miała **129 PASS / 3 FAIL** w nowym zestawie.
Wykryto opóźnione wywołanie fokusu po zniszczeniu menu i ponowne ustawienie
fokusu podczas aktualizacji; zastąpiono callbacki timerami należącymi do
widoku oraz usunięto powtórną inicjalizację tej samej sesji. Test Shift+F10
czeka teraz na zakończenie wcześniejszego wejścia w pasek. Natywna
integracja wcześniej ujawniła też utratę fokusu po zniszczeniu obiektu SNI
oraz dostęp do zwolnionego modelu menu; poprawiono obie ścieżki.
[Pierwszy log](evidence/06-tests-initial.log) pozostaje w źródłach.

Końcowy przegląd poprawił także kotwiczenie Quick Settings po powiększeniu
monitora: zwykłe panele śledzą aktualny prawy brzeg, menu zachowuje kotwicę
przycisku i ograniczenie do ekranu. Po tej zmianie ponownie przeszły bramka,
33 testy Qt paneli/baterii/traya i natywna regresja IPC/LazyLoader. Pomiar
spoczynku ma zamknięty panel i nie zależy od tej korekty geometrii.

Oczekiwane ostrzeżenia natywnego braku UPower oraz jednej brakującej pixmapy
są dopasowane dokładnie i pozostają w raporcie/logu. Inne błędy/ostrzeżenia
kończą test niepowodzeniem. Nie wyciszano importów. Sandbox blokował
lokalne sockety; testy wykonano po dopuszczeniu ich tworzenia, z prywatnymi
XDG i oboma adresami D-Bus. Nie połączono adapterów testowych z hostem.

### Niewykonane kryteria

Fizyczna bateria/firmware, rzeczywiste aplikacje traya i ich warianty
DBusMenu, Wayland/layer-shell, natywne tooltipy, HyprlandFocusGrab,
fokus innej aplikacji, fizyczne monitory/hotplug i mieszane skale są
**niezweryfikowane**. Potwierdzono brak `/dev/dri`, Westona, Sway i Cage;
nie uruchamiano drugiego pełnego shella na aktywnym pulpicie.

Nie zmieniano autostartu ani konfiguracji pulpitu. Brak metadanych Git
(`not a git repository`), bez commita. Status etapu 06:
**gotowy do odbioru środowiskowego**. Etapu 07 ani dalszych nie rozpoczęto.

## Sesja 2026-09-16 — etap 07

### Rezultat i pliki

- `services/NetworkBackend.qml`, `NetworkService.qml`, `NetworkValues.js`
  i `NetworkScanLease.qml`: wspólne natywne urządzenia/sieci, Ethernet,
  radio, rfkill, osobny stan internetu, potwierdzanie akcji i własność
  skanowania. Jeden pasywny obserwator D-Bus, bez pollingu w spoczynku.
- `modules/quicksettings/NetworkSection.qml`: przełącznik radia, lista
  według adapterów z sygnałem/zabezpieczeniem, otwarte/zapisane/PSK,
  rozłączenie, anulowanie, timeout i komunikaty błędów. Maskowane pole
  czyści się przed przekazaniem PSK natywnemu API i po zmianie celu/zamknięciu.
  VPN, enterprise i profile mają wejście do opcjonalnego edytora.
- `modules/bar/`, `assets/icons/network.svg`, `QuickSettingsView`,
  `PanelSurface`, `PanelHost` i `shell.qml`: jawne przekazanie tej samej
  usługi do wskaźnika oraz panelu. Korzeń ma 73 linie. Widoki nie uruchamiają
  poleceń systemowych; pasek nie żąda skanowania.
- `preview/MockNetwork*.qml`, scena/okno podglądu i `scripts/preview --network`:
  scenariusze PSK, portalu, rfkill, pustej listy i braku usługi wyłącznie na atrapach.
- `tests/qml/tst_network.qml`, `tests/network_dbus_fake.py`, `network-test.qml`,
  `scripts/test-network-integration` i `scripts/test`: rzeczywiste wejście Qt,
  natywne modele oraz prywatny protokół NM, w tym kontrola nadawcy wywołania
  Update i braku sekretów w argv, logach i prywatnych plikach.
- [Kontrakt sieci](network.md), architektura, wygląd, środowisko, testy,
  README i [dowody wizualne/pomiarowe](evidence/07-network.md).

### Zależności i ograniczenia API

Sprawdzono lokalne Quickshell 0.3.1-1, Qt 6.11.2, NetworkManager 1.58.1-1,
oficjalną dokumentację odpowiadających wersji, źródła tagu Quickshell
i zainstalowane XML interfejsów D-Bus NM. Testy użyły dostępnych python-dbus
1.4.0-2 i python-gobject 3.56.3-1. gdbus/busctl były już dostępne; pakietów
nie instalowano. Opcjonalny `nm-connection-editor` nie jest zainstalowany:
sprawdzono komunikat braku oraz uruchomienie kontrolowanej atrapy programu.
Nie dodano pluginu C++, trwałych ustawień ani produkcyjnego IPC.

Quickshell 0.3.1 optymistycznie zmienia radio i może pomijać ponowienie po
odmowie. Wyłącznie tę flagę zapisuje typowany `busctl`, po czym osobny odczyt
potwierdza stan. PSK trafia do `WifiNetwork.connectWithPsk(string)`.
NetworkManager może zapisać go we własnym profilu; Putkin nie przechowuje
sekretu w ustawieniach ani stanie usługi.

Natywny singleton nie odzyskuje połączenia po utracie/późnym starcie NM.
UI ukrywa stare dane i wymaga restartu procesu Putkin. Miękki reload
zachowuje historię właściciela przez `PersistentProperties`; twardy reload
ją usuwa, zachowując singleton, więc także wymaga restartu procesu.
Skanowanie, widoki i obserwatory są zwalniane przy obu rodzajach reloadu.
Natywne grupowanie duplikatów odbywa się po SSID na urządzeniu; wybór BSSID,
nowe ukryte SSID i zaawansowane zabezpieczenia pozostają w edytorze.
Pełny opis ograniczeń i timeoutów: [network.md](network.md).

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 93 pliki QML, 0 błędów; [log](evidence/07-check.log) |
| `scripts/test` | **PASS**, 6 regresji Python, 159 wyników QtTest (44,540 s), wszystkie integracje: Hyprland Hyprlang/Lua, panele, FileView, PipeWire, brightnessctl, UPower/SNI/DBusMenu i Networking; [log](evidence/07-tests.log) |
| Końcowy QtTest sekcji sieci | **PASS**, 27 wyników, 0 błędów/ostrzeżeń, 9,591 s po korekcie prezentacji rfkill i dostępności akcji; [log](evidence/07-qt.log) |
| `scripts/test-network-integration --idle --output docs/evidence/07-network.json` | **PASS**, 9 grup sprawdzeń, 20 cykli LazyLoadera, reload/restart i 60,001370 s spoczynku; [JSON](evidence/07-network.json), [log](evidence/07-network.log) |
| Skanowanie i wejście | **PASS**, 11 sposobów zakończenia listy/operacji, niezależne urządzenia i właściciele, stabilne delegaty, h/j/k/l i Enter, litery w polu PSK, mały panel 320×220 |
| Podgląd `--network` | **PASS**, 7 obejrzanych zrzutów: 1920×1080, 1366×768 i 320×220; skale 1 / 1,25 / 1,5 / 2; [obrazy](evidence/07-network.md) |

Pomiar dotyczył świeżego procesu offscreen/software, z zamkniętym panelem,
natywnym adapterem sieci i prywatnym NM; inne usługi były atrapami.
Przez 60 s nie przybyło żadnego odczytu ani RequestScan. CPU shella
i jego jedynego dziecka `gdbus` wzrosło o **0 zarejestrowanych ticków**.
RSS shella: 108 996 → 109 132 KiB (+136 KiB); obserwatora: stałe 5 904 KiB.
W 20 cyklach RSS wyniosło 128 432 → 128 728 KiB, zakres 128 236–128 984 KiB.
Test potwierdził destrukcję powierzchni, wyłączenie skanerów oraz brak
pozostałych 14 zarejestrowanych procesów po zakończeniu. Krótki pomiar
nie stanowi dowodu braku wycieków podczas wielogodzinnej sesji.

Pierwszy pełny zestaw Qt przekroczył wcześniejszy limit 40 s, bez zgłoszonego
błędu asercji; [log](evidence/07-tests-initial.log). Limit zwiększono do 70 s
dla rozszerzonego zestawu, po czym cała regresja przeszła. Końcową korektę
wyglądu/dostępności sprawdzono ponownie bramką, 27 wynikami Qt, integracją
natywną i podglądami. Nie zastępowano zachowania kontrolą tekstu źródeł.

Oczekiwana diagnostyka natywnego braku NM i znane ograniczenie masek okien
offscreen pozostają w logach; pozostałe ostrzeżenia/importy powodują FAIL.
Testy potrzebowały dopuszczenia lokalnych socketów poza sandboxem, zachowując
prywatne XDG i oba adresy D-Bus. Nie korzystały z magistral ani sprzętu hosta.

### Niewykonane kryteria

Rzeczywiste połączenie z AP, fizyczne WPA/WPA2/SAE, sterowniki i karty Wi-Fi,
systemowy NetworkManager/Polkit, sprzętowy rfkill i portal HTTP są
**niezweryfikowane**. Atrapa protokołu potwierdza wywołania natywnego API,
nie uwierzytelnienie radiowe. Wayland/layer-shell, HyprlandFocusGrab, fokus
innej aplikacji, fizyczny hotplug i mieszane skale również wymagają odbioru.
Brak `/dev/dri`, Westona, Sway i Cage uniemożliwiał kontrolowany odbiór Waylanda.

Nie uruchamiano drugiego pełnego shella na pulpicie, nie zmieniano autostartu
ani konfiguracji hosta. Brak metadanych Git (`not a git repository`), bez
commita. Status etapu 07: **gotowy do odbioru środowiskowego**.
Etapu 08 ani dalszych nie rozpoczęto.

## Sesja 2026-09-16 — etap 08

### Rezultat i pliki

- `services/BluetoothBackend.qml` i `BluetoothService.qml`: jeden adapter
  domeny, natywne modele Quickshell.Bluetooth, wybór adaptera, filtrowanie
  już sparowanych urządzeń i potwierdzanie radia/connect/disconnect.
  Operacje mają identyfikator i limit czasu; seria kliknięć nie uruchamia
  równoległych żądań. Zmiana wyboru nie przypisuje starych odpowiedzi do
  nowego adaptera. Brak discovery i pollingu.
- `modules/quicksettings/BluetoothSection.qml`: wiersz radia i rozwijana
  lista, wybór adaptera, nazwa/stan i opcjonalna bateria, błędy, tooltipy,
  h/j/k/l + Enter i stabilny fokus. „Sparuj nowe urządzenie…” otwiera
  opcjonalny Blueman. Brak programu jest komunikatem w panelu.
- `QuickSettingsView`, `PanelSurface`, `PanelHost`, `shell.qml` i rejestry
  QML: jawne przekazanie jednej usługi. Korzeń ma 76 linii. Etykiety
  „Bateria urządzenia” i „Bateria komputera” rozdzielają peryferium i UPower.
  Widoki nie uruchamiają komend systemowych.
- `preview/MockBluetoothBackend.qml`, `MockBluetoothAdapter.qml`,
  `MockBluetoothDevice.qml`, scena/okno podglądu oraz `scripts/preview
  --bluetooth`: stan włączony/wyłączony, kilka adapterów, brak usługi,
  pusta lista, oczekiwanie, brak menedżera i mały ekran na atrapach.
- `tests/qml/tst_bluetooth.qml`, `tests/bluetooth_dbus_fake.py`,
  `bluetooth-test.qml`, `scripts/test-bluetooth-integration`, `scripts/test`
  i dopasowanie etykiety w regresji baterii: rzeczywiste wejście Qt,
  protokół BlueZ na prywatnym D-Bus, 20 cykli oraz reload podczas operacji.
- [Kontrakt Bluetooth](bluetooth.md), architektura, wygląd, środowisko,
  testy, README i [dowody wizualne/pomiarowe](evidence/08-bluetooth.md).

### API i zależności

Przed implementacją sprawdzono lokalne Quickshell **0.3.1-1**, Qt **6.11.2**,
BlueZ/bluez-utils **5.87-2**, qmltypes, oficjalną dokumentację odpowiednich
wersji i źródła Quickshell v0.3.1. Dostępne gdbus/busctl oraz testowe
python-dbus/python-gobject wystarczyły; nie instalowano pakietów.
`blueman-manager` nie jest zainstalowany. Test jego dostępności uruchamia
wyłącznie własny executable; PATH fixture wyklucza menedżera hosta.

Natywny setter radia jest optymistyczny; wynik Connect/Disconnect nie jest
sygnałem QML. Wyłącznie te trzy operacje wykonuje typowany `busctl`,
a potwierdzony stan nadal pochodzi z natywnych obiektów. Jeden pasywny
obserwator gdbus wykrywa właściciela BlueZ. Nie dodano C++, demona,
trwałych ustawień, produkcyjnego IPC, skanowania ani agenta PIN/passkey.

W 0.3.1 utrata/restart/późny start BlueZ wymaga restartu **procesu Putkin**;
UI informuje o tym, ukrywa stare modele i blokuje ich akcje. Zwykły reload
zachowuje historię właściciela; twardy reload istniejącego modelu również
wymaga restartu procesu. Przejściowe procesy i poprzedni obserwator są
zwalniane, również przy reloadzie z oczekującym żądaniem. Zamknięcie panelu
nie anuluje połączenia zleconego współdzielonej usłudze. Pełne granice,
limity i przejście do zewnętrznego parowania opisuje [bluetooth.md](bluetooth.md).

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 101 plików QML, 0 błędów; [log](evidence/08-check.log) |
| `scripts/test` | **PASS**, 6 regresji Python, 175 wyników QtTest (51,966 s), wszystkie integracje Hyprland Hyprlang/Lua, panele, FileView, PipeWire, brightnessctl, UPower/SNI/DBusMenu, Networking i Bluetooth; [log](evidence/08-tests.log) |
| QtTest sekcji Bluetooth | **PASS**, 16 wyników, 0 błędów/ostrzeżeń, 7,233 s; [log](evidence/08-qt.log) |
| Integracja Bluetooth w końcowej regresji | **PASS**, 7 grup sprawdzeń, 20 cykli, reload z oczekującą operacją, utrata/późny start BlueZ, menedżer; [JSON](evidence/08-bluetooth-validation.json), [log](evidence/08-bluetooth-validation.log) |
| `scripts/test-bluetooth-integration --idle --output docs/evidence/08-bluetooth.json` | **PASS**, 7 grup sprawdzeń, 20 cykli i 60,001676 s spoczynku; [JSON](evidence/08-bluetooth.json), [log](evidence/08-bluetooth.log) |
| Podgląd `--bluetooth` | **PASS**, 7 obejrzanych zrzutów: 1920×1080, 1366×768 i 320×220; skale 1 / 1,25 / 1,5 / 2; [obrazy i polecenia](evidence/08-bluetooth.md) |

W pomiarze offscreen/software zamknięty panel, zegar minutowy i świeży
proces z natywnym Bluetooth nie wykonały nowych odczytów ani żądań D-Bus
przez 60 s. CPU shella i obserwatora wzrosło o **0 zarejestrowanych ticków**.
RSS shella: 103 068 → 103 196 KiB (+128 KiB); gdbus: stałe 5 972 KiB.
W 20 cyklach RSS: 125 716 → 127 440 KiB, zakres 125 372–128 012 KiB.
Pomiar zakończył własne 14 zarejestrowanych procesów. Nie stanowi to dowodu
braku wycieków w wielogodzinnej sesji. Końcowa regresja osobno sprawdziła
zakończenie procesów operacji podczas reloadu.

Pierwsza pełna regresja: **174 wyniki Qt PASS / 1 FAIL** (hover tooltipu
przed przeliczeniem układu) i FAIL integracji zakładającej indeks urządzenia
w nieuporządkowanym ObjectManagerze. [Zachowany log](evidence/08-tests-initial.log).
Testy poprawiono: oczekiwanie na układ i identyfikacja konkretnego urządzenia
fixture. Po korekcie przeszły osobno testy Qt/natywne i pełna regresja.
Wcześniejszy odbiór natywny wykrył też chwilową niezdefiniowaną właściwość
usuwanego urządzenia; delegat obsługuje ten stan bez ostrzeżeń.

Testy nie wyciszają błędów importów ani QML. Dopuszczają tylko znaną maskę
okna offscreen i dokładny komunikat niedostępnego ObjectManagera w celowym
scenariuszu braku BlueZ; komunikaty pozostają w logach. Sandbox blokował
socket (`Operation not permitted`); testy uruchomiono z dopuszczonymi
lokalnymi socketami, nadal w prywatnych XDG i obu prywatnych magistralach.
Atrapa potwierdziła **zero StartDiscovery, StopDiscovery, Pair i RemoveDevice**.
Nie wykonano żadnego parowania ani operacji Bluetooth hosta.

### Niewykonane kryteria

Fizyczne adaptery Bluetooth, połączenia radiowe/profile, prawdziwe baterie
peryferiów, sprzętowy rfkill, uprawnienia systemowego BlueZ i parowanie
w rzeczywistym oknie Blueman są **niezweryfikowane**. Uruchomienie atrapy
executable nie potwierdza gotowości/fokusu programu na Waylandzie.
Wayland/layer-shell, HyprlandFocusGrab, fokus innej aplikacji, fizyczny
hotplug i mieszane skale wymagają osobnego odbioru. Nadal brak `/dev/dri`,
Westona, Sway i Cage; nie uruchamiano drugiego pełnego shella na pulpicie.

Nie zmieniano autostartu ani konfiguracji hosta. Workspace nie zawiera
metadanych Git (`not a git repository`), bez commita. Etap 08:
**gotowy do odbioru środowiskowego**. Etapu 09 ani kolejnych nie rozpoczęto.

## Sesja 2026-09-16 — etap 09

### Rezultat i pliki

- `services/NotificationBackend.qml`, `notification-watch.py`: jeden natywny
  serwer po sprawdzeniu właściciela nazwy, potwierdzenie rejestracji,
  ograniczony obserwator zastąpień i jawny stan niedostępności.
- `services/NotificationService.qml`, `NotificationEntry.qml`: życie obiektów,
  replace, akcje, trzy powody zamknięcia, resident/transient, timeouty, DND,
  wybór monitora i ograniczenie pamiętanej kolejki.
- `modules/notifications/`: prostokątne toasty z ikoną, aplikacją, tytułem,
  treścią, czasem i zamknięciem; obraz i akcje w ograniczonym przewijanym
  obszarze. `Variants` i `LazyLoader` tworzą okno tylko dla zajętych monitorów.
  `core/Metrics.qml`, `assets/icons/notification.svg`: wspólne tokeny i ikona.
- `core/NotificationFocus.qml`, `services/NotificationIpc.qml`,
  `modules/quicksettings/NotificationSection.qml`: DND, jawne wejście do
  toastów, h/j/k/l i Enter, zwolnienie klawiatury, współpraca z paskiem
  i panelem. Zależności przekazane przez mały `shell.qml` i `PanelHost`.
- Atrapy `preview/MockNotification*.qml`, scena/okno podglądu,
  `scripts/preview --notifications`, `tests/qml/tst_notifications.qml`,
  fixture obrazu, `notifications-test.qml`, `scripts/test-notifications-integration`
  oraz włączenie integracji do pełnego `scripts/test`.
- [Kontrakt i instrukcja migracji/rollbacku](notifications.md), IPC,
  architektura, wygląd, środowisko, testy, README i [dowody](evidence/09-notifications.md).

### API, zależności i reguły

Potwierdzono lokalne Quickshell **0.3.1-1**, Qt **6.11.2**, dbus **1.16.2-1**,
systemd/busctl **261.3-1**, python-dbus **1.4.0-2** i python-gobject **3.56.3-1**.
Sprawdzono qmltypes, oficjalną dokumentację i źródła Quickshell tagu v0.3.1.
Pakietów nie instalowano. Python/dbus/gobject są teraz także zależnością
produkcyjnego obserwatora. Natywne API nie sygnalizuje identycznego replace
i błędnie aktualizuje etykiety akcji; jeden pasywny `BecomeMonitor` dostarcza
wyłącznie ograniczone metadane zastąpienia. Nie przesyła body ani obrazów
do QML przez stdout, nie zapisuje plików i nie odpytuje cyklicznie magistrali.

Serwer ogłasza dokładnie `body`, `actions`, `icon-static`. UI używa PlainText;
brak HTML, inline replies, historii i zapisu treści. Timeout domyślny to
6000 ms, 0 pozostawia obiekt, krytyczne nie wygasają automatycznie i omijają
DND. Włączenie DND wygasza zwykłe obiekty bez późniejszego odtwarzania.
Maksimum globalne: 3 widoczne i 12 oczekujących, mniej na małym ekranie;
deterministyczna kolejka z pierwszeństwem krytycznych. Reload wygasza stare
obiekty i przywraca wyłączone DND. Każdy toast ma jeden monitor; hotplug
przekierowuje go bez odnowienia czasu albo wygasza przy braku ekranów.

Preflight nie tworzy serwera przy istniejącym obcym właścicielu, także
oferującym allow-replacement. Późniejsze zwolnienie nazwy nie aktywuje tej
zablokowanej instancji. Sam preflight nie jest atomowy z `RequestName`;
ograniczenie natywnego singletonu i konieczność zakończenia **procesu**
przy migracji opisano w kontrakcie. Utrata obserwatora zwalnia stare treści
i wymaga restartu procesu. Nie zatrzymano żadnego serwera hosta.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 115 plików QML, 0 błędów; [log](evidence/09-check.log) |
| `scripts/test` | **PASS**, 6 regresji Python, 194 wyniki QtTest (54,289 s), wszystkie integracje etapów 01–09; [pełny log](evidence/09-tests.log) |
| QtTest powiadomień w pełnej regresji | **PASS**, 17 testów zachowania oraz init/cleanup: 19 wyników, 0 błędów/ostrzeżeń; [wyciąg](evidence/09-qt.log) |
| `scripts/test-notifications-integration --idle --output docs/evidence/09-notifications.json` | **PASS**, 12 grup rzeczywistego protokołu, 20 cykli LazyLoader, soft/hard reload, konflikt nazwy, awaria i brak obserwatora; [JSON](evidence/09-notifications.json), [log](evidence/09-notifications.log) |
| Treść, obraz i zalew | **PASS**, brakujące dane, limity tekstów, 8 MiB RGBA i jego zastąpienie, 100 zdarzeń, ograniczona kolejka i timeout od nadejścia; znacznik treści nie trafił do argv, logów, cache ani prywatnych plików XDG |
| Klawiatura i geometria Qt | **PASS**, pasywne nadejście/kliknięcie zachowuje fokus pola, h/j/k/l, Enter, Tab/Backtab, Escape, DND i wejście z panelu, pauza timera, hotplug/resize atrap, ósma akcja dostępna w 320×220 |
| Podgląd `--notifications` | **PASS**, 6 obejrzanych zrzutów: 1920×1080, 1366×768 i 320×220, skale 1 / 1,25 / 1,5 / 2; [obrazy i polecenia](evidence/09-notifications.md) |

Końcowy pomiar offscreen/software obejmował świeży proces z zegarem minutowym,
30 workspace, zamkniętym panelem i bez toastów. Przez **60,000732 s** CPU shella
wzrosło o **1 zarejestrowany tick**, a obserwatora o **0**. RSS shella:
103 068 → 103 196 KiB (+128 KiB); obserwatora: stałe 27 544 KiB.
Drzewo zawierało shell i jednego obserwatora Python, bez busctl po preflight.
W osobnej serii 20 cykli RSS shella: 136 344 → 135 552 KiB;
minimum 135 552, maksimum 136 344 KiB. Zakończono wszystkie 11 zarejestrowanych
procesów testu, bez pozostawionych PID-ów. To krótka obserwacja, nie dowód
braku wycieków w wielogodzinnej sesji. Limity UI nie ograniczają surowego
payloadu, który natywny serwer dekoduje przed sygnałem QML.

Pierwsza integracja ujawniła SIGSEGV po dużym obrazie: wcześniejszy strumień
`busctl monitor --json` przenosił pełne obrazy jako tablice liczb do QML.
[Wynik](evidence/09-notifications-initial.json), [log](evidence/09-notifications-initial.log)
i [stos GDB](evidence/09-initial-gdb.log) zachowano. Zastąpiono go obserwatorem
Python z `byte_arrays=True` i ograniczonymi metadanymi; finalny test obrazu,
jego zastąpienia, reloadów i wszystkich cykli przechodzi. Osobno usunięto
ostrzeżenia metadanych IPC przez wrapper QtObject i synchronicznie pobierano
obrazy z natywnego providera żyjącego razem z obiektem Notification.

Pierwszy test Qt miał 17 wyników PASS i 1 FAIL: symulował Shift+Tab jako
Tab z modyfikatorem zamiast zdarzenia Qt Backtab; [log](evidence/09-qt-initial.log).
Poprawiono zdarzenie testowe. Pierwszy pełny pomiar natywny zaliczył zachowania,
ale zakończył się FAIL klasyfikatora celowego braku Pythona;
[JSON](evidence/09-notifications-idle-initial.json). Test oczekuje teraz dokładnie
jednej diagnostyki konkretnej komendy w scenariuszu `missing-helper`;
komunikat pozostaje w logu i wyniku. Końcowa regresja i pomiar przeszły.

Nie wyciszono importów ani ostrzeżeń QML. Natywny test zachowuje znaną
diagnostykę masek offscreen oraz powyższy kontrolowany brak executable;
inne ostrzeżenia powodują FAIL. Sandbox blokował prywatne sockety D-Bus;
testy uruchomiono po dopuszczeniu lokalnych socketów, nadal na prywatnych
obu adresach D-Bus i XDG. Pozostałe domeny są atrapami, bez sprzętu i PAM.

### Niewykonane kryteria

Natywne okno layer-shell, maska i grab, zachowanie fokusu **obcej aplikacji**
przy nadejściu/zamknięciu/akcji oraz zwolnienie klawiatury po Escape pozostają
**niezweryfikowane na Waylandzie**. Dotyczy to także rzeczywistego hotplug,
kilku fizycznych monitorów i mieszanych skal. Nadal brak `/dev/dri`, Westona,
Sway i Cage; nie uruchamiano drugiego pełnego shella na aktywnym pulpicie.
Testy wejścia Qt i atrapy monitorów nie zastępują tego odbioru.

Instrukcję późniejszej migracji i rollbacku przygotowano, lecz nie wykonano
przełączenia, zmian autostartu ani zatrzymania mako/dunst/SwayNC/starego shella.
Workspace nie zawiera metadanych Git (`not a git repository`), bez commita.
Etap 09: **gotowy do odbioru środowiskowego**. Etapów 10+ nie rozpoczęto.

## Sesja 2026-09-16 — etap 10

### Rezultat i pliki

- `modules/power/PowerView.qml`: wyśrodkowane menu Wyloguj / Uruchom ponownie /
  Wyłącz / Uśpij, ikony SVG, przyczyny niedostępności, przewijanie i osobne
  potwierdzenie kończących pracę akcji. Domyślny fokus na Anuluj; h/j/k/l,
  Enter oraz standardowe wejście Qt.
- Quick Settings, `PanelCoordinator`, `PanelHost` i `PanelSurface`: Blokada,
  Ustawienia i Zasilanie, jeden wspólny loader i monitor wywołania.
  `InteractivePanelWindow` otrzymało geometrię środka monitora dla Power.
- `services/SessionBackend.qml`, `SessionService.qml`, `SessionIpc.qml`,
  `session_backend.py`, `session_lock.py`, `core/SessionController.qml`
  i małe uzupełnienie `shell.qml` (89 linii). Typowane login1, potwierdzenie
  blokady, obsługa błędów i wznowienie do istniejącego refresh() jasności.
- `scripts/lock-session`, `config/hyprlock.example.conf` i
  `config/hypridle.example.conf`: wspólny launcher oraz osobne przykłady,
  bez edycji konfiguracji użytkownika, autostartu i PAM.
- Atrapy w `preview/` i `tests/`, `tests/qml/tst_session.qml`,
  `session-test.qml`, `scripts/test-session-integration` włączony do
  `scripts/test`; rozszerzony bezpieczny podgląd `--session`.
- [Kontrakt sesji](session.md), IPC i szablony skrótów, architektura,
  design, rozwój, testowanie, README i [dowody](evidence/10-session.md).

### Kontrakty i API

Ponownie sprawdzono Quickshell 0.3.1 i Qt 6.11.2. Lokalne wersje:
Hyprland 0.56.2, Hyprlock 0.9.6, Hypridle 0.1.8, uwsm 0.26.7,
systemd 261.3. Oficjalne źródła tagów potwierdzają ścieżkę
session-lock.sendLocked → lock-notify → Hypridle ActiveChanged/GetActive.
Nie dodano obserwatora C++, własnego PAM, lockscreen QML ani nowych
trwałych ustawień. Proces Pythona jest jednym zdarzeniowym dzieckiem
shella, bez okresowego pollingu.

Weryfikacja obserwatora sprawdza właściciela D-Bus, executable/UID,
wersję 0.1.8, wyświetlacz i instancję Hyprlanda. Nieznany właściciel
wyłącza Uśpij. PID ani kod wyjścia nie potwierdzają blokady.
Każde żądanie ma numer i termin. Suspend jest wysyłany dopiero po
potwierdzeniu protokołu; timeout, spóźniony wynik i utrata obserwatora
nie uruchamiają uśpienia. Flock i niezależny proces Hyprlocka zachowują
blokadę po reloadzie Putkin; wszystkie przykładowe wyzwalacze używają
wspólnego launchera. Brak potwierdzenia nie zabija lockera.

Wylogowanie używa oficjalnego dla logind/uwsm
TerminateSession(XDG_SESSION_ID), po sprawdzeniu własnej aktywnej sesji.
Nie wywołuje exit kompozytora ani zakończenia wszystkich sesji użytkownika.
Wznowienie jest parą PrepareForSleep true → false od właściciela login1;
powtórzone i obce sygnały są ignorowane. Szczegóły i ograniczenie
nieatomowej komunikacji między serwisami opisano w kontrakcie.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 123 pliki QML, 0 błędów; [log](evidence/10-check.log) |
| `scripts/test` | **PASS**, kod 0; 6 regresji Python, 204 wyniki QtTest (60,066 s), wszystkie integracje etapów 01–10; [log](evidence/10-tests.log) |
| QtTest sesji | **PASS**, 8 testów zachowania plus init/cleanup, 10 wyników; [osobny log](evidence/10-qt.log), następnie PASS w pełnej regresji |
| `scripts/test-session-integration --idle --output docs/evidence/10-session.json` | **PASS**, 13 grup protokołu i pomiar 60 s, 20 cykli LazyLoader, reload, brak żywych procesów po zakończeniu; [JSON](evidence/10-session.json), [log](evidence/10-session.log) |
| Podglądy `--session` | **PASS**, cztery obejrzane zrzuty: 1920×1080, 1366×768, 320×220; skale 1 / 1,25 / 1,5 / 2; [obrazy i polecenia](evidence/10-session.md) |
| Składnia Python i lokalne linki dokumentacji | **PASS**, 9 zmienionych/dodanych skryptów; brak nieistniejących celów linków w zmienionej dokumentacji |

Potwierdzono: anulowanie bez operacji, domyślny fokus Anuluj, klawiaturę,
brak podwójnych wywołań, lock requested → lock confirmed → Suspend,
ignorowanie obcych nadawców, brak/spóźnione potwierdzenie, odmowę i timeout,
późną odpowiedź bez ponowienia, brak/powrót logind, obcy UID, stan challenge,
utratę obserwatora, soft/hard reload z zachowaniem pojedynczego lockera,
wyjście lockera z kodem 0 bez gotowości oraz odświeżenie jasności po parze
sygnałów. Produkcyjne sprawdzanie tożsamości odrzuciło testowy ScreenSaver.

Pomiar offscreen/software obejmował świeży proces, zegar minutowy,
30 workspace i zamknięty panel. W fazie pomiaru produkcyjny helper odrzucał
fikcyjną tożsamość ScreenSaver; to nie jest pomiar aktywnej sesji Hypridle.
Przez **60,000703 s** przyrost CPU shella i pomocnika wyniósł **0 ticków**.
RSS shella: **98 232 → 98 616 KiB** (+384 KiB); helpera: stałe
**30 936 KiB**. Drzewo: shell i jedno dziecko Python, bez trwałych procesów
poleceń. Osobna seria 20 cykli: RSS **135 980 → 128 204 KiB**;
minimum 127 948, maksimum 136 620 KiB.
Po testach nie pozostały żywe procesy środowiska. Krótki pomiar nie dowodzi
braku wycieków podczas wielogodzinnej sesji. W trakcie pomiaru działała
również osobna regresja projektu na własnych prywatnych magistralach;
podane CPU/RSS dotyczą wyłącznie wskazanych PID-ów pomiaru.

Historia korekt: pierwsza bramka wykryła brak typu delegata w nawigacji;
pierwszy QtTest miał 9 PASS / 1 FAIL dla kierunku k. Uzupełniono typ
ActionRow i aktualizowanie odnośników po tworzeniu delegatów. Pierwsza
integracja nie ładowała MockSessionBackend — uzupełniono preview/qmldir.
Pierwsza pełna regresja miała 203 PASS / 1 FAIL: przycisk Ustawienia
wyłączony w teście nie był pomijany przez j. Przywrócono regułę pomijania.
[Logi początkowe](evidence/10-session.md#zachowanie).

Drugi pełny przebieg miał 204 PASS QtTest, ale nie przeszedł timeoutu
integracji Bluetooth po reloadzie oraz kontroli liczników cyklu sesji;
[log](evidence/10-tests-run2.log), [Bluetooth](evidence/10-bluetooth-regression-failure.log),
[sesja](evidence/10-session-regression-failure.json). Zmiany pliku podglądu
podczas testów wywoływały auto-reload; osobny pomiar przerwał się po zmianie
PID-u pomocnika ([log](evidence/10-session-idle-interrupted.log)). Test cykli
czeka teraz na oba warunki: nieaktywny loader i wykonane zniszczenie widoku.
Końcowa pełna regresja i pomiar na ustalonych źródłach przeszły bez tych
błędów. Nie zmieniano produkcyjnej implementacji Bluetooth.

Sandbox początkowo odmówił prywatnego socketu D-Bus. Właściwe testy
wykonano po dopuszczeniu lokalnych socketów, zachowując oba prywatne
adresy D-Bus, XDG, PATH i atrapowy locker. Nie wyciszono ostrzeżeń/importów.
Integracja sesji dopuszcza tylko znany komunikat maski offscreen; pełna
regresja zachowuje udokumentowaną diagnostykę celowych awarii innych domen.

### Niewykonane kryteria

Nie wykonywano rzeczywistej blokady/uwierzytelniania, suspend/resume,
wylogowania, restartu, wyłączenia ani odmowy Polkit na hoście. Nie
zweryfikowano parsera/renderu przykładu Hyprlock ani identyfikacji
prawdziwego Hypridle w wybranej sesji. Test protokołu zastępuje wyłącznie
tożsamość obserwatora jawną podklasą testową; osobno produkcja odrzuca
fikcyjny ScreenSaver. Nie traktujemy prywatnego D-Bus jako izolacji PAM.

Natywny layer-shell/grab, fokus obcej aplikacji, rzeczywisty hotplug,
kilka fizycznych monitorów i mieszane skale pozostają niezweryfikowane.
`hyprctl -j version` zwróciło `Couldn't set socket timeout (2)`;
wersja aktywnej sesji nie została potwierdzona. Nie aktywowano Putkin
na pulpicie ani nie zmieniono konfiguracji osobistej. Brak metadanych Git,
bez commita. Etap 10: **gotowy do odbioru środowiskowego**.
Etapów 11+ nie rozpoczęto.

## Sesja 2026-09-16 — etap 11

### Rezultat i pliki

- Zgodnie z doprecyzowaniem użytkownika tapeta jest w Quickshellu.
  `WallpaperService.qml`, `modules/wallpaper/`: opcjonalna warstwa
  Background per ekran, lokalny obraz lub Mocha, bez wejścia/fokusu
  i rezerwowania miejsca. Hyprpaper nie jest zależnością. Nie ma
  dostarczonego czystego obrazu; referencyjne PNG nie są tapetą.
- `NightLightService.qml`, `NightLightBackend.qml`, `night_light.py`:
  klient istniejącej jednostki użytkownika hyprsunset 0.4.0. Potwierdzone
  on/off, suwak 1000–6500 K, brak fikcyjnego stanu przy niedostępności,
  timeout/odmowa/restart bez automatycznego ponowienia.
- `NightLightSection.qml`, jawne zależności w `PanelHost`, Quick Settings,
  powierzchni i podglądzie; h/j/k/l, Enter i standardowe wejście Qt.
  Korzeń `shell.qml` ma 95 linii. Brak nowych pól settings.json i IPC.
- `config/desktop-appearance.lua`: ostre rogi, ramka Mauve 1 px,
  gaps 6/12, pełna nieprzezroczystość. Osobne przykłady konfiguracji
  hyprsunset i drop-in istniejącej jednostki; instrukcje włączenia/rollbacku.
- `tests/qml/tst_desktop.qml`, osiem testów Pythona, atrapa protokołu,
  `desktop-test.qml`, `scripts/test-desktop-integration`, podgląd `--desktop`
  i `--wallpaper`; włączenie do pełnej regresji.
- [Kontrakt pulpitu](desktop.md), rozwój, testowanie, architektura,
  design, prompt etapu, README i [dowody](evidence/11-desktop.md).

### API i własność

Przed implementacją potwierdzono Quickshell 0.3.1, Qt 6.11.2 i Hyprland
0.56.2 / Lua. Użytkownik zainstalował hyprsunset 0.4.0-3; agent nie
instalował pakietów. Sprawdzono oficjalne tagi IPC, CLI, konfiguracji
i jednostki, Hyprutils 0.14.2 i lokalny systemd 261.3. Starsze hyprsunset
nie ma bezpiecznego odczytu `identity get`; kontrola procesu, jednostki
i wersji następuje przed wysłaniem tego polecenia.

Backend zachowuje jeden zewnętrzny daemon. Putkin go nie uruchamia ani
nie kończy; posiada tylko krótki pomocnik transakcji i jego ograniczone
w czasie polecenia odczytu wersji/jednostki. PID/starttime wiąże zamiar
z konkretnym daemonem. Stan pojawia się po odczycie potwierdzającym,
nie po samym `ok`. Brak pollingu; odświeżanie przy starcie, otwarciu panelu,
akcji i ręcznym Odśwież. Przykład używa XDG, ponieważ lokalne 0.4.0
błędnie obsługuje argument ścieżki `--config`.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 133 QML, 0 błędów; [log](evidence/11-check.log) |
| `scripts/test` | **PASS**, kod 0, 14 Python, 222 QtTest (62,887 s), wszystkie integracje; [log](evidence/11-tests.log) |
| QtTest etapu 11 | **PASS**, 18 wyników, 2,681 s; [log](evidence/11-qt.log) |
| `scripts/test-desktop-integration --output docs/evidence/11-desktop.json` | **PASS**, 10 grup, protokół/Process i 20 cykli; [JSON](evidence/11-desktop.json), [log](evidence/11-desktop.log) |
| `scripts/test-desktop-integration --idle --output docs/evidence/11-desktop-idle.json` | **PASS**, integracja i 60 s spoczynku; [JSON](evidence/11-desktop-idle.json), [log](evidence/11-desktop-idle.log) |
| Lua / rollback | **PASS**, dwa wywołania natywnego `Hyprland --verify-config`, kontrola wartości ramki; wyniki w JSON |
| Konfiguracja hyprsunset | **PASS parsera**, przykład i celowo błędna sekcja; następnie oczekiwany kod 1 przy niedostępnym Waylandzie, bez działającego backendu |
| Prywatna kopia jednostki i drop-in | **PASS**, `systemd-analyze --user --man=no --generators=no verify`, kod 0; [log](evidence/11-systemd.log) |
| Podglądy | **PASS**, cztery obejrzane zrzuty 1920×1080 / 1366×768 / 320×220, skale 1 / 1,25 / 1,5 / 2; [obrazy](evidence/11-desktop.md#podglądy) |

Potwierdzono brak drugiego demona, brak zapisu przy samym odczycie stanu
już aktywnego, fragmentację strumienia, odmowę, spóźniony wynik,
niepotwierdzony zapis, timeout i zakończenie dziecka po SIGKILL/reloadzie,
restart bez ponowienia starego zamiaru oraz odrzucenie atrapowego procesu
przez produkcyjną identyfikację. QtTest obejmuje temperaturę, nawigację,
mały panel, ładowanie/zwolnienie obrazu, fallback i przepuszczanie kliknięć.

Po 20 cyklach: 20 widoków utworzonych i zniszczonych, brak aktywnego
pomocnika; RSS 125 804 → 125 444 KiB (min. 125 420, maks. 126 188 KiB).
Osobny pomiar po serii cykli: **60,000962 s**, **1 tick CPU**,
RSS **122 260 → 119 276 KiB**, bez odpytywania backendu i bez dzieci
shella w próbce końcowej. Offscreen 1920×1080, 30 workspace, zegar
minutowy, panel zamknięty, tapeta Mocha. Backend jest prywatną atrapą.
Na początku pomiaru kończył się też niezależny pełny QtTest;
metryki dotyczą wyłącznie PID-u shella z JSON.
Krótki pomiar nie dowodzi braku wycieków w długiej sesji.
Niezależny [zapis pełnego QtTest](evidence/11-all-qt.log) również ma
222 PASS (62,943 s). Sprawdzenie składni siedmiu skryptów Python
i lokalnych linków zmienionej dokumentacji: **PASS**.
Historia początkowych błędów bramki, próby negatywnej parsera, dopasowania
oczekiwanego błędu obrazu oraz blokady socketów w sandboxie jest zapisana
w [dowodach](evidence/11-desktop.md#historia-korekt-i-ograniczenia).
Nie wyciszano importów ani nie podmieniano testów zachowania na szukanie tekstu.

### Niewykonane kryteria

Nie włączono zmian na aktywnym pulpicie. CTM/gamma, prawdziwa jednostka
hyprsunset, natywne okna Background/maski/fokus, fizyczny hotplug i mieszane
skale pozostają niezweryfikowane. Prywatny D-Bus i offscreen nie zastępują
tego odbioru. Nie ma czystej tapety użytkownika, więc nie wykonano pełnego
porównania pulpitu do referencji. Motywy Kitty/Fish/Neovim i blokada
Hyprlock mają oddzielnych właścicieli; akcenty Putkin dotyczą tylko jego UI.
Brak metadanych Git, bez commita. Etap 11: **gotowy do odbioru środowiskowego**.
Etapów 12–13 nie rozpoczęto.

## Sesja 2026-09-16 — etap 12

### Rezultat i pliki

- [Raport odbioru](validation.md) rozdziela potwierdzone wyniki od
  niewykonanych kryteriów. Zawiera komendy, obrazy, CPU/RSS, pracę w tle,
  opis napraw i konkretne scenariusze dalszego odbioru.
- `scripts/_common.py` oraz wszystkie 12 integracji: kontrola procesu
  i źródłowego logu QML przed odczytem odpowiedzi IPC. Niepoprawny JSON
  jest błędem, nie pustym stanem. Odczyt przez `pread` nie przestawia
  pozycji, z której proces potomny zapisuje log.
- `scripts/test`, `tests/test_runtime.py`: limit QtTest 120 s, zakończenie
  po błędzie wcześniejszej bramki i regresja rzeczywistego brakującego
  importu w 15 uruchomieniach CLI. Błąd QML nie ginie za wtórnym błędem JSON.
- `tests/qml/tst_validation.qml`, `validation-test.qml`,
  `scripts/test-validation-integration`: pełna kompozycja domen na
  jawnych atrapach, rzeczywiste wejście Qt i IPC, monitor docelowy,
  zwolnienie skanowania, soft/hard reload, niszczenie widoków i procesów.
- `preview/PanelPreviewWindow.qml`, `scripts/preview`,
  `scripts/validate-visuals`: scenariusz z 30 workspace, 40 ikonami traya
  i długimi nazwami; poprawiona samoczynna ekspansja Bluetooth w podglądzie.
  Macierz renderów uwzględnia rozmiar logiczny ekranu przy każdej skali.
- README, [testowanie](testing.md), [środowisko](development.md),
  `.gitignore` i dowody `docs/evidence/12-*`. Logi również w podkatalogach
  dowodów nie są ignorowane. Produkcyjny korzeń, publiczne IPC i format
  ustawień nie zostały rozszerzone; etap 13 nie został rozpoczęty.

### API i środowisko

Ponownie odczytano lokalne Quickshell 0.3.1, Qt 6.11.2, Hyprland 0.56.2,
Aquamarine 0.15.0, hyprsunset 0.4.0-3, Python 3.14.7 i D-Bus 1.16.2.
Przed użyciem sprawdzono oficjalne API QtTest, okien, grabu i reloadu oraz
źródła backendu kompozytora i `hyprctl`; odnośniki są w raporcie.
Wszystkie testy miały prywatne XDG i D-Bus. Wirtualny PipeWire, atrapy
protokołów/executable oraz offscreen nie dotykały hostowego sprzętu ani PAM.
Początkowa próba w sandboxie nie przeszła przez zakaz lokalnych socketów;
właściwe testy wykonano po ich dopuszczeniu, zachowując izolację.

### Weryfikacja

| Polecenie / sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 135 QML, 0 błędów; [log](evidence/12-check.log) |
| `scripts/test` | **PASS**, kod 0; 17 Python, 235 QtTest (67,584 s), wszystkie 12 integracji; [log](evidence/12-tests.log) |
| Nowa ścieżka Qt | **13 PASS**: workspace → Quick Settings → dwa akcenty/zapis → audio/jasność → PSK z hjkl → BT → DND/toast → anulowanie Power, zachowanie fokusu oraz osiem rozmiarów logicznych; [log](evidence/12-validation-qt-run4.log) |
| Test błędów uruchamiania | **PASS**: 12 integracji, preview, measure-idle i główny runner rzeczywiście ładowały brakujący import; każdy zwrócił niezerowy kod i źródłową diagnostykę; część 17 regresji Python |
| `scripts/test-validation-integration` | **PASS**, 20 cykli, routing IPC i hotplug na atrapach monitorów, oba reloady przy skanowaniu i szkicu kolorów; [JSON](evidence/12-validation.json) |
| `scripts/validate-visuals --output docs/evidence/12-visuals` | **PASS offscreen**, 16 PNG otwartych i ocenionych; dwie rozdzielczości × cztery skale oraz osiem dodatkowych stanów; [manifest](evidence/12-visuals/manifest.json) |
| `scripts/measure-idle --panels --output docs/evidence/12-baseline-idle.json` | **PASS**, 60,000206 s, 0 ticków CPU; RSS 98 004 → 98 132 KiB; [JSON](evidence/12-baseline-idle.json) |
| `scripts/test-validation-integration --idle --cycles 60 --output docs/evidence/12-combined-idle.json` | **PASS**, 60,000132 s, 0 ticków CPU; idle RSS 101 824 → 103 104 KiB, bez scan/discovery; 60 widoków utworzonych i zniszczonych, brak żywych procesów po sprzątnięciu; [JSON](evidence/12-combined-idle.json) |
| Kontrola końcowa | **PASS**, SHA-256 204 źródeł, składnia 24 plików Python, 271 lokalnych odnośników; brak procesów obu pomiarów i końcowej integracji; [log](evidence/12-final-review.log) |

Pomiary wykonano kolejno po testach i renderach, bez zmian QML w trakcie.
Oba używały świeżego procesu, 2 s rozgrzewki, 30 workspace, zegara
minutowego i offscreen/software. Każdy miał trzy procesy środowiska
(Quickshell, dbus-run-session, dbus-daemon), bez dzieci shella. Baza
`--panels` nie dołącza sekcji domen, ale tworzy obiekty ich atrap.
Zero ticków oznacza brak zmierzonego przyrostu przy rozdzielczości 10 ms.

Po wzroście RSS w serii 20 cykli zbadano 60 cykli: zakres
129 936–132 788 KiB, koniec 131 012 KiB. Mediany kolejnych bloków 20:
131 234 / 131 332 / 131 200 KiB. W tej serii nie utrzymuje się wzrost.
Nie jest to dowód braku wielogodzinnego wycieku ani pomiar pamięci GPU.
Odczyty jasności/Night Light w idle pozostały 1 → 1; po cyklach było
60 scanStarts / 60 scanStops, zero discovery i operacji sesji.
Przyczyny pracy w tle każdej produkcyjnej domeny opisano oddzielnie
w raporcie; pomiar atrap nie jest pomiarem całego produkcyjnego shella.

Zachowano logi początkowych nieudanych prób oraz końcowe wyniki.
Naprawiono błędne oczekiwania nowego testu dotyczące nazw, fokusu
i ponownego wejścia do paska po aktywacji workspace, a także zbyt wczesną
kontrolę PID-ów po SIGTERM. Nie zmieniano produkcyjnej nawigacji pod test.
Nie wyciszano importów ani nowych ostrzeżeń; wąskie wyjątki dla celowych
awarii usług pozostają jawne. Brak metadanych Git, bez commita;
zapisano [sumy SHA-256 źródeł](evidence/12-source-sha256.json).

### Niewykonane kryteria

Całkowicie prywatny Hyprland bez wyświetlacza hosta i urządzeń zakończył
się kodem 134: `Cannot open backend: no allocator available`;
[log i polecenie](evidence/12-wayland-attempt.log).
Odczyt poza sandboxem potwierdził istnienie `card0` i `renderD128` na hoście.
Automatyczny przegląd uprawnień odrzucił przed wykonaniem proponowaną
12-sekundową próbę zagnieżdżonego kompozytora z socketem Waylanda rodzica
i węzłem renderującym. Wskazał zakaz drugiego shella na aktywnym pulpicie
z AGENTS.md oraz ryzyko zakłócenia sesji. Nie ponowiono akcji inną drogą;
[zapis odmowy](evidence/12-wayland-approval.txt),
[skrypt pierwotnej próby](evidence/12-wayland-nested-proposed.py).
To opis pierwotnej odmowy; późniejsza zgoda i wykonanie są zapisane poniżej.

Na tym historycznym etapie layer-shell/grab, fokus obcej aplikacji, skale,
hotplug i pomiar Waylanda były **NIEWYKONANE**; późniejszy wynik jest poniżej.
Niewykonane pozostawały także fizyczne audio, backlight,
Wi-Fi/BT/bateria, CTM/tapeta oraz Hyprlock/Hypridle, PAM, suspend/resume,
Polkit i uwsm. Nie włączono Putkin na pulpicie. Raport podaje scenariusze
i komendy do ich domknięcia na przeznaczonej do tego sesji; żaden taki
punkt nie jest PASS. Etap 12 pozostaje **w toku**, etap 13 nie rozpoczęty.

### Kontynuacja po zgodzie na próbę zagnieżdżonego kompozytora

Użytkownik odpowiedział „tak” na pytanie o 12-sekundowy start Hyprlanda
z dostępem do socketu rodzica i `renderD128`. Tę próbę wykonano:
kompozytor uruchomił backend Waylanda, utworzył wyjście i wszedł w pętlę
zdarzeń; [log](evidence/12-wayland-nested-attempt.log),
[wynik](evidence/12-wayland-nested-result.json). Nie uruchomiono Putkin.
Log wykazał zbyt długą ścieżkę `.socket2.sock`, więc sam start nie był
jeszcze dowodem działającego IPC.

W tym samym, zatwierdzonym zakresie powtórzono 12-sekundową próbę
z krótkim prywatnym `XDG_RUNTIME_DIR=/tmp/pw-*/r` i wyłączonym XWaylandem.
Jawne `hyprctl -i <prywatna sygnatura> -j monitors` zwróciło monitor;
socket zdarzeń powstał przy ścieżce 100 bajtów. Kompozytor działał do
limitu 12,000217 s, po czym zakończono własną grupę procesów;
[JSON](evidence/12-wayland-short-runtime.json),
[log](evidence/12-wayland-short-runtime.log),
[skrypt](evidence/12-wayland-nested-short-runtime.py).
Wyjście zagnieżdżone miało 941×557 przy odczycie, zgodnie z rozmiarem
okna nadanym przez rodzica; nie zalicza to wymaganej macierzy monitorów.
Ostrzeżenia DRM/libseat, kursora i zarządzania kolorem pozostają w logu.

Przygotowano `scripts/test-wayland`, `wayland-validation.qml`,
`wayland-client-test.qml` i `wayland-capture-test.qml`: produkcyjne okna
z atrapami domen, osobna aplikacja do kontroli fokusu, klawiatura `wtype`
oraz ScreencopyView przechwytujący wyłącznie prywatne wyjścia HEADLESS.
Scenariusz obejmuje ścieżkę klawiaturą, geometrię i skale, dwa wyjścia,
hotplug, reload, 20 cykli i opcjonalny pomiar 60 s. Zawiera skróconą
ścieżkę runtime. Potwierdzono lokalne `wtype 0.4-2` i dokumentację v0.4,
API QsWindow/ScreencopyView 0.3.1 oraz Item.grabToImage Qt 6.11.2.

| Sprawdzenie po przygotowaniu | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 138 QML, 0 błędów; [log](evidence/12-check-after-wayland-preparation.log) |
| `python3 -m unittest discover -s tests -p test_runtime.py -v` | **PASS**, 3 regresje, 8,065 s; rzeczywiste brakujące importy w prywatnych uruchomieniach offscreen; [log](evidence/12-runtime-after-wayland-preparation.log) |
| `scripts/test-wayland --nested --smoke ...` | **NIEWYKONANE**, automatyczny przegląd uprawnień odrzucił akcję przed uruchomieniem; [zapis odmowy](evidence/12-wayland-ui-approval.txt) |
| Kontrola przygotowania | **PASS**, 204 wcześniejsze źródła bez zmian, 208 sum po dodaniu testów, składnia 26 plików Python i 293 lokalne odnośniki; procesy i katalog próby kompozytora usunięte; [log](evidence/12-wayland-preparation-review.log) |

Przegląd uznał test okien Putkin za szerszy niż zatwierdzona próba samego
kompozytora: dodatkowe okna na Waylandzie/GPU aktywnej sesji, pierwotnie
limit 300 s, zakaz z AGENTS.md i brak wyraźnej zgody na dodatkowe skutki.
Nie ponowiono testu UI inną drogą przed zgodą. W tamtym momencie runner
miał limit 45 s dla smoke i 600 s dla pełnego przebiegu i oczekiwał na zgodę
na dalszy odbiór UI oraz konieczne powtórzenia. Zgodę i wyniki zapisano poniżej.
Wyniki 235 QtTest / 17 Python / 12 integracji nadal dotyczą poprzedniej
pełnej regresji; nowych scenariuszy natywnych nie zaliczono przez sam lint.
Fizyczny sprzęt, PAM i operacje sesji pozostają poza tymi atrapami.

### Końcowa kontynuacja — pełny odbiór natywnego UI

Użytkownik zatwierdził produkcyjne okna na prywatnym Waylandzie z atrapami,
wirtualne wejście, zrzuty prywatnych wyjść, skale/hotplug, reload i pomiary,
łącznie z powtórzeniami do 10 minut. [Historia zgody](evidence/12-wayland-ui-approval.txt).
Końcowy przebieg był niezakłócany zmianą fokusu/workspace rodzica.

Naprawiono produkcyjne `InteractivePanelWindow.qml` i `NotificationWindow.qml`:
`OnDemand` pozwala `HyprlandFocusGrab` zarządzać klawiaturą i wyjściem po
kliknięciu poza powierzchnią. `Exclusive` blokowało zamykanie panelu
oraz zakłócało wejście do toastów w Hyprlandzie 0.56.2.
Test prywatnym wskaźnikiem i osobnym procesem potwierdza naprawę.

`scripts/test-wayland`, `wayland-validation.qml`, `wayland-client-test.qml`
i `tests/wayland_click.c` tworzą powtarzalny scenariusz. Protokół wskaźnika
zachowuje licencję w `tests/protocols/`. Zrzuty wykonuje grim; usunięto
niestabilny pomocniczy `wayland-capture-test.qml`. Oficjalny grim 1.5.0-2
rozpakowano do `/tmp`, po sprawdzeniu sumy pakietu, bez instalacji systemowej.
Bramka obejmuje stąd 137 QML. Korzeń produkcji nadal ma 95 linii.

| Końcowe sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, 137 QML, 0 błędów; [log](evidence/12-check-final.log) |
| `scripts/test` po naprawach | **PASS**, kod 0; 17 Python (8,875 s), 235 QtTest (67,441 s), wszystkie 12 integracji; [log](evidence/12-tests-final.log) |
| `PUTKIN_GRIM=/tmp/putkin-grim/usr/bin/grim scripts/test-wayland --nested --idle --output docs/evidence/12-wayland-run13` | **PASS**, kod 0, 127,754 s; [raport](evidence/12-wayland-run13/report.json), [log](evidence/12-wayland-run13.log) |
| Natywne renderowanie | **PASS**, 18 PNG otwartych i ocenionych; [ocena i sumy](evidence/12-wayland-run13/review.json), [obrazy](validation.md#obrazy-natywne) |
| Sprzątnięcie | **PASS**, brak żywych procesów potomnych, wrapper zebrany, prywatny katalog usunięty; [JSON](evidence/12-wayland-run13/cleanup.json) |

Potwierdzono pełną ścieżkę hjkl/Enter, oba akcenty i FileView, PSK z hjkl,
BT/DND/Power na atrapach, bierne OSD/toasty, jawne wejście/wyjście z toastów,
kliknięcie poza panelem i powrót tekstu do osobnej aplikacji. Osiągalna
pozycja 40 traya, podmenu i pojedyncza aktywacja. Dwie rozdzielczości ×
cztery skale, mieszane 1/1,5, IPC na drugim monitorze i hotplug podczas
sieci, szkicu kolorów, podmenu oraz potwierdzenia Power. Jedna rezerwacja
32 logicznych px na wyjście. 20 cykli, bilans 37/37 widoków i 22/22 skanów
wraz z wcześniejszymi interakcjami; soft/hard reload z zachowaniem zapisu.
Zero operacji sesji. Logi QML bez błędów; diagnostyka kompozytora zachowana.

Macierz 1366 przy ułamkowych skalach wymaga testowego
`debug:disable_scale_checks=true`; domyślny Hyprland zaokrągla te skale do 1.
Rzeczywisty tryb/skala jest sprawdzany przez IPC. PNG 1366×768/1,25 ma
1366×767 przez zaokrąglenie logical size w grim; raport podaje oba wymiary.
Nie zmieniono konfiguracji hosta. Początkowe nieudane próby pozostały
w dowodach; szczegóły przyczyn i korekt są w [raporcie](validation.md).

60,000024 s spoczynku: shell **2 ticki CPU / 0,033% rdzenia**,
RSS **203 888 → 203 480 KiB**; kompozytor **57 ticków / 0,950%**,
RSS **147 796 KiB** bez zmian. Zero dzieci shella, scan/discovery/akcji,
stan i odczyty jasności/Night Light 1 → 1. Klient wejścia i grim wystartowały
po pomiarze. Późniejsza seria 20 cykli: **244 360 → 247 552 KiB**,
zakres 244 360–248 352; koniec 10 → 20: 247 584 → 247 552 KiB.
Nie widać dalszego wzrostu w końcach dwóch bloków; krótki pomiar nie
rozstrzyga o wielogodzinnym wycieku i nie mierzy VRAM.

**Niewykonane:** fizyczne audio/backlight/Wi-Fi/BT/bateria/monitory,
Hyprlock/Hypridle/PAM, lock → suspend → resume, Polkit/uwsm oraz opcjonalny
rzeczywisty CTM/czysta tapeta. Natywne UI na GPU z wirtualnymi wyjściami
nie zalicza tych kryteriów. Etap 12 nadal **w toku**; etap 13 nie rozpoczęty.
Putkin nie został aktywowany jako shell użytkownika; brak metadanych Git,
bez deklaracji commita. [Końcowy manifest źródeł](evidence/12-final-source-sha256.json).
[Przegląd końcowy](evidence/12-completion-review.log): 250 plików źródłowych
wraz z kontraktami/promptami i referencjami, składnia 37 skryptów Python,
istniejące cele lokalnych linków. Archiwum końcowych integracji zachowuje
wyniki oddzielnie od wcześniejszej regresji.

## Sesja 2026-09-16 — odbiór użytkownika i uruchomienie Night Light

Po lokalnym przełączeniu na Putkin użytkownik potwierdził działanie regulacji
jasności i audio, Bluetooth, Wi-Fi, baterii i monitorów. Zapisano podstawowy
odbiór tych funkcji na rzeczywistym sprzęcie. Wiadomość nie zawiera wyników
osobnych prób awarii usług, odmowy uprawnień ani długotrwałego pomiaru GPU/VRAM;
nie przypisujemy jej takich wyników. Lock/suspend pozostają otwarte.

Użytkownik następnie zgłosił niedostępny Night Light i doprecyzował, że
zainstalował hyprsunset, lecz go nie uruchamiał. Diagnoza: zainstalowane
0.4.0, jednostka `inactive/dead`, `MainPID=0`, brak demona; adapter → `absent`.
Środowisko managera użytkownika odpowiadało aktywnej sesji Hyprlanda.

Zastosowano istniejące przykłady konfiguracji w osobnym namespace Putkin
i drop-in `hyprsunset.service.d/putkin.conf`, następnie `daemon-reload`
i `start hyprsunset.service`. Filtr startuje przez `--identity`, bez profili
czasowych. Nie włączono autostartu. Wynik: `active/running`, MainPID 297039,
adapter z opublikowanej instalacji zwraca `enabled: false`, `temperature: 6000`,
`error: ""`. Potwierdzono dostępność backendu; włączenie filtra i wizualny
odbiór zmiany barw pozostają do sprawdzenia. [Dowód](evidence/12-night-light-session.json),
[log usługi](evidence/12-night-light-session.log), [konfiguracja i wycofanie](desktop.md).

Zmieniono dokumentację odbioru/statusu; runtime Putkin pozostaje bez zmian.
`scripts/check`: **PASS**, 137 QML, zero błędów;
[log](evidence/12-user-acceptance-check.log). Nie powtarzano regresji zachowania
QML po zmianie wyłącznie dokumentacji i konfiguracji usługi. Weryfikacją
integracji jest odczyt przez produkcyjny adapter do rzeczywistego hyprsunset.

## Sesja 2026-09-16 — potwierdzenie blokady ekranu

Po wskazaniu skrótu Super+Shift+L i przycisku Blokada w Quick Settings
użytkownik odpowiedział „dziala”. Zapisano **PASS podstawowego działania
blokady — odbiór użytkownika**. Zgłoszenie nie rozróżnia obu sposobów
uruchomienia; nie zalicza osobno pełnego cyklu lock → suspend → resume,
odświeżenia jasności po wznowieniu ani scenariuszy awarii/uprawnień.
Etap 12 pozostaje w toku. Zaktualizowano dokumentację; runtime bez zmian.

## Sesja 2026-09-16 — potwierdzenie uśpienia i wybudzenia

Użytkownik potwierdził wprost: „uśpienie i wybudzenie potwierdzone”.
Zapisano **PASS podstawowego działania suspend/resume — odbiór użytkownika**,
obok wcześniejszego potwierdzenia blokady i sprzętu. Te funkcje nie są już
oznaczone jako niewykonane. Zgłoszenie nie określa osobno automatycznej
kolejności/potwierdzenia blokady, odświeżenia jasności po wznowieniu ani
odmowy uśpienia po awarii lockera; szczegółowe kryteria mają własne wpisy
w [raporcie odbioru](validation.md#odbiór-użytkownika-i-pozostałe-kryteria).
Zmiana dotyczy dokumentacji, bez modyfikacji runtime i bez ponawiania
uśpienia na pulpicie użytkownika.

Po obu potwierdzeniach zakończono tę samą kontrolę `scripts/check`:
**PASS**, 137 QML, zero błędów; [log](evidence/12-lock-user-check.log).
Lokalne linki zmienionej dokumentacji są poprawne. Odbiór blokady oraz
suspend/resume pochodzi od użytkownika, niezależnie od tej bramki QML.

## Sesja 2026-09-16 — zamknięcie etapu 12

**Status: ukończony dla `20260916-5132708bd8f7`.** Porównano rzeczywiste dowody z siedmioma zadaniami
i trzema warunkami odbioru [niezmienionego promptu](prompts/12-validation.md).
Każdy obowiązkowy punkt ma wynik PASS w [macierzy odbioru](validation.md#zamknięcie-kryteriów).
Nie wykryto nowych usterek wymagających zmiany odebranego runtime.
Działająca instalacja zawiera te same 110 plików co repozytorium w chwili
regresji zakończonej o 20:52:43 UTC. Zgodność kodu i testów z natywnym
odbiorem potwierdzono o 20:55 UTC. Zweryfikowano też sumy i wymiary
18 zapisanych zrzutów, zamiast powtarzać niezmieniony scenariusz na pulpicie.

| Sprawdzenie | Rzeczywisty wynik |
| --- | --- |
| `scripts/check` | **PASS**, kod 0, 137 QML, 0 błędów; [log](evidence/12-closeout-check.log). |
| `scripts/test` | **PASS**, kod 0; 17 testów Python, 235 wyników QtTest (67,494 s, 0 błędów/pominięć), wszystkie 12 integracji; [log](evidence/12-closeout-tests.log), [25 plików archiwum](evidence/12-closeout-integrations/manifest.json). |
| Negatywne scenariusze sesji | **PASS na izolowanych protokołach/atrapach**: brak suspend bez potwierdzenia blokady, odmowy, timeouty, spóźnione odpowiedzi, odrzucenie obcego obserwatora oraz jedno odświeżenie jasności po resume; [13 grup integracji](evidence/12-closeout-integrations/session.json). |
| Aktywna sesja — tylko odczyt | **PASS**, jedna instancja Putkin i jej właściciel powiadomień, rezerwacja paska 32 px, brak błędów QML/Hyprlanda; [odczyt](evidence/12-closeout-live.json), [log](evidence/12-closeout-live.log). Produkcyjny adapter potwierdził własną sesję i tożsamość Hypridle; [dowód](evidence/12-closeout-session-owner.json). |
| Night Light | **PASS — odbiór użytkownika**: „Tak, włączenie i wyłączenie działa”, w odpowiedzi na pytanie o ocieplenie/przywrócenie kolorów. Odczyt adaptera: aktywny, 4500 K, bez błędu; jednostka `active/running`, autostart `enabled`. |
| Wcześniejszy odbiór sprzętu i sesji | Zachowano potwierdzenia użytkownika: jasność/audio, Wi-Fi/BT, bateria, monitory, blokada oraz uśpienie/wybudzenie; [zapis zgłoszeń](evidence/12-user-acceptance.json). |

Zmieniono README, roadmapę i dokumentację statusu, odbioru, pulpitu,
środowiska oraz lokalnej instalacji. Dodano końcowe logi, odczyty i manifesty
do `docs/evidence/`; nie zmieniono kontraktów IPC, ustawień ani runtime.
[Zbiorczy wynik](evidence/12-closeout.json),
[manifest źródeł z dokumentacją i promptami](evidence/12-closeout-source-sha256.json),
[kontrola spójności dowodów i linków](evidence/12-closeout-review.log).
Brak metadanych Git; nie deklarujemy commita.

Od 21:05 UTC wykryto równoległe zmiany wyglądu w plikach QML i podglądzie,
obejmujące m.in. font, obramowania, tooltipy oraz nowe komponenty. Zachowano
je bez ingerencji. Zakończony odbiór dotyczy opublikowanej wersji;
późniejsze edycje nie przejmują jej wyniku PASS. Odebrany runtime zachowano
w [archiwum](evidence/12-closeout-runtime.tar.gz), a manifest źródeł utrwala
sumy kodu i testów sprzed tych zmian oraz końcowych dokumentów.
Użytkownik wyraźnie zatwierdził ten zakres: „Tak — zamknij etap 12
dla działającej wersji”.

Nie wykonano audytu PAM, wymuszania awarii fizycznych urządzeń, pomiaru VRAM
ani wielogodzinnej sesji. Nie potwierdzono niezależnie obu sposobów wejścia
w blokadę ani przyszłego logowania. Są to jawne granice dowodów;
punkt 5 etapu wymaga awarii na atrapach, a punkt 6 — 60 s idle i 20 cykli,
co zostało wykonane. Przenośny instalator i pozostały odbiór etapu 13
pozostają osobnym zakresem; tej realizacji o nie nie rozszerzono.

## Format wpisu po sesji

- Etap i data.
- Widoczny rezultat oraz zmienione pliki.
- Faktycznie spełnione zależności i zmiany kontraktów/IPC/ustawień.
- Uruchomione polecenia, środowisko i wyniki PASS/FAIL.
- Kryteria niewykonane, np. prawdziwy sprzęt, Wayland, hotplug albo sesja/lock.
- Link do zrzutów/pomiarów, jeśli dotyczą zmiany.
- Status: w toku / gotowy do odbioru środowiskowego / ukończony / pominięty opcjonalnie.

„Ukończony” oznacza spełnienie obowiązkowych kryteriów etapu. Testy poprzednika z audytu nie są testami nowego shella. Dla etapu 13 odnotować osobno przetestowany instalator i rzeczywistą aktywację na pulpicie.
