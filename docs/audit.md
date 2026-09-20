# Audyt poprzedniego shella: Putpuccin → Putkin

**Data:** 2026-09-16. **Źródło:** `../putpuccin`, commit `50163351f8d34425c617802921762aa9a34c3cf2`, z dostępnymi lokalnymi dokumentami i artefaktami. Stan roboczy starego repo przed i po pracy: `?? mockup/`; audyt go nie zmienił.

## Wniosek

**Poprzedni kod nadaje się jako źródło wybranych rozwiązań. Nowy shell warto złożyć z mniejszego korzenia i nowych widoków.** Ma dobry podział odpowiedzialności, natywne integracje, odporne ustawienia i wartościowe testy. Jego złożoność w dużej mierze wynika z szerokiego zakresu produktu: rozwijanych wysp, rozbudowanych menu, własnego parowania, screenshotów, blokady i greetera.

Są też konkretne usterki, szczególnie w kontroli jakości, koordynacji paneli i kontrolkach paska. Nie uzasadniają odrzucenia całego projektu, ale wykluczają bezkrytyczne kopiowanie infrastruktury.

Rekomendacja dla Putkin:

1. Zachować jeden stan każdej domeny, natywne API, tokeny i zasady poprawnego zapisu ustawień.
2. Zbudować prosty pasek i niezależne panele według nowych obrazów.
3. Wprowadzić konfigurowalne akcenty wcześnie, w etapie 03.
4. Adaptować małe fragmenty usług wraz z odpowiednimi testami; własne pluginy C++ pozostawić poza podstawą.
5. Korzystać ze sprawdzonego zewnętrznego lockera; własna blokada i greeter są odrębnymi projektami.

## Zakres i metoda

Pracę podzielono na trzy niezależne przeglądy: architektura/core, integracje/testy oraz UI/referencje. Wyniki zostały połączone z oględzinami wszystkich czterech obrazów i weryfikacją wersjonowanej dokumentacji API.

Przeczytano kod reprezentatywnych ścieżek, `AGENTS.md`, `general_guidelines.md`, dokument rozwoju i odpowiednie plany. Historyczne wymagania poprzedniego produktu, np. szkło, fingerprint i browser bridge, nie zostały przyjęte jako wymagania Putkin.

Skala lokalnego źródła: **174 pliki QML, 23 382 fizyczne linie QML**; razem z JS, Pythonem, C/C++ i pomocnikami bez rozszerzeń w `scripts/`: **307 plików / 41 795 linii**. Liczby obejmują testy i fixture; nie są pomiarem kosztu działania ani samodzielnym dowodem nadmiernej złożoności.

Poniższe linki wskazują pliki w sąsiednim katalogu; liczby oznaczają linie audytowanego stanu. Gdy stare repo nie jest dostępne, opisy i ścieżki pozostają wystarczającym kontekstem do realizacji nowej roadmapy.

## 1. Rozwiązania, które warto zachować

| Rozwiązanie | Dowód | Ocena |
| --- | --- | --- |
| Cienki korzeń kompozycji, widoki per monitor | [shell.qml](../../putpuccin/shell.qml), linie 20–80 | Czytelny punkt składania aplikacji; `Variants` i jawna własność potrzebnych singletonów mają sens |
| Wspólne adaptery zamiast procesów dla każdej kontrolki | [AudioService.qml](../../putpuccin/services/AudioService.qml), 10–80; [PowerService.qml](../../putpuccin/services/PowerService.qml), 10–29 | Dobry punkt startowy audio/baterii; liczba widoków nie musi mnożyć obserwatorów |
| Walidacja i ostatni poprawny stan ustawień | [Settings.qml](../../putpuccin/core/Settings.qml), 196–249 i 364–392 | Atomowy zapis i odporność na zły plik; potwierdzone testem |
| Stabilność list przy przeładowaniu ustawień | [Settings.qml](../../putpuccin/core/Settings.qml), 299–305 | Równe listy nie są bez potrzeby zastępowane; 20 reloadów przeszło test |
| Kontrola skanowania | [NetworkService.qml](../../putpuccin/services/NetworkService.qml), 91–96 i 199–204; [BluetoothService.qml](../../putpuccin/services/BluetoothService.qml), 119–142 i 259–262 | Wi-Fi/BT wiążą pracę z potrzebą widoku i sprzątają zasoby |
| Ładowanie ciężkich powierzchni na żądanie | [NetworkWindow.qml](../../putpuccin/modules/network/NetworkWindow.qml), 10–12; [DetachedLauncher.qml](../../putpuccin/components/DetachedLauncher.qml), 70–79 | Obecność obiektu w `shell.qml` nie oznacza, że cały jego interfejs stale pracuje |
| Nawigacja menu i testy fokusu | [KeyboardNavigation.qml](../../putpuccin/components/KeyboardNavigation.qml), 23–47, 72–78, 108–120; [test_menu_keyboard_wayland.py](../../putpuccin/tests/test_menu_keyboard_wayland.py), 150–179 i 219–264 | Są dobre rozwiązania czterech menu; nie należy na podstawie braków paska uznać całego shella za niedostępny |
| Staging, kopia i rollback instalacji | [scripts/install](../../putpuccin/scripts/install), 98–147, 168–205 i 224–245 | Podejście do wymiany kompletnego runtime jest wartościowe; 19 testów instalatora przeszło |

Ustawienia mają jednak wiele kopii wartości domyślnych: właściwości, `defaultConfig()`, `resetToDefaults()`, schemat i przykład. W nowym małym modelu należy ograniczyć tę duplikację, zachowując sprawdzone zachowania awaryjne.

## 2. Konkretne usterki i braki

### A1. Kontrola składni QML może dać fałszywy sukces

**Istotne dla jakości; potwierdzone wykonaniem.**

[scripts/test-static](../../putpuccin/scripts/test-static), linie 23–26, używa `find … -exec qmlformat {} \;`. Porażka pojedynczego formattera nie staje się błędem całego `find`; `set -e` tego nie naprawia. [Instalator](../../putpuccin/scripts/install), linia 296, korzysta z tej bramki.

W izolowanej kopii dodano `AUDIT_INVALID.qml` z niepoprawną składnią. Bezpośrednie `qmlformat` zwróciło **1**, natomiast `scripts/test-static` zwrócił **0** i wypisał `Static checks passed.`. Próbka została usunięta z kopii; stare repo nie było edytowane.

**Skutek:** wadliwa składnia może przejść kontrolę przed instalacją. To nie dowód, że obecne pliki QML są błędne. **Putkin:** jawne agregowanie błędów oraz test samej bramki już w etapie 00; osobno kontrola importów i zachowania.

### A2. Większość kontraktów i planów nie trafia do klonu repo

**Wada utrzymaniowa; potwierdzona konfiguracją i listą śledzonych plików.**

[.gitignore](../../putpuccin/.gitignore), 14–19, ignoruje `plan/*` i `docs/*` z dwoma wyjątkami klawiatury; linie 35–40 wyłączają też `AGENTS.md`, `general_guidelines.md` i sam `.gitignore`. To sprzeczne z lokalnym wymogiem wersjonowania dokumentacji w [AGENTS.md](../../putpuccin/AGENTS.md), linia 11.

Sprawdzono `git ls-files`: dokumenty rozwoju, ustawień, wydajności i większość planów nie są śledzone. **Istnieją lokalnie**, więc nie należy nazywać ich brakującymi na tej maszynie. `plan/settings.md` jest plikiem pustym.

**Skutek:** nowa sesja lub świeży klon nie otrzymuje zasad potrzebnych do utrzymania kodu. **Putkin:** dokumentacja, roadmapa i prompty należą do źródeł projektu; nie ignorować ich jako materiałów lokalnych.

### A3. IPC może „otworzyć” powierzchnię, która nie ma hosta

**Niespójność potwierdzona w kodzie; objaw UI nie był odtwarzany na żywym Waylandzie.**

[SurfaceManager.qml](../../putpuccin/core/SurfaceManager.qml), 158–186, akceptuje znany identyfikator i zapisuje stan otwarcia bez sprawdzenia hosta. Domyślna lista modułów w [Settings.qml](../../putpuccin/core/Settings.qml), 59–61, nie zawiera osobnych `audio` i `brightness`. [BarIsland.qml](../../putpuccin/modules/statusbar/BarIsland.qml), 56–72, szuka hosta wyłącznie w istniejących delegatach i przy braku usuwa komponent rozwinięcia.

**Scenariusz:** udokumentowane `surfaces open audio` ustawia aktywną powierzchnię, lecz domyślny pasek nie ma jej osobnego panelu. Stan wpływa także na tryb klawiatury statusbara.

**Putkin:** kilka jawnie istniejących powierzchni i odrzucanie niedostępnej akcji. Hostowanie paneli nie powinno zależeć od tego, czy dana kontrolka jest w konfigurowalnej liście paska.

### A4. Przycisk paska ma martwe właściwości i braki dostępu z klawiatury

**Potwierdzone przeglądem komponentów; nie ocena całej dostępności aplikacji.**

[BarButton.qml](../../putpuccin/components/BarButton.qml), 10–11, deklaruje `tooltip` i `active`, ale nie renderuje tych wartości. Przykładowo [NetworkModule.qml](../../putpuccin/modules/statusbar/NetworkModule.qml), 31, przekazuje nazwę sieci, a [QuickSettingsModule.qml](../../putpuccin/modules/statusbar/QuickSettingsModule.qml), 27, stan otwarcia — bez oczekiwanego efektu w bazowej kontrolce.

Ten sam przycisk jest `Item` z `MouseArea` (5, 68–81), bez własnej obsługi klawiatury i nazw dostępności. Podobny wzorzec występuje w [WorkspacesModule.qml](../../putpuccin/modules/statusbar/WorkspacesModule.qml), 27–61, i elementach [TrayModule.qml](../../putpuccin/modules/statusbar/TrayModule.qml), 75–108.

**Putkin:** standardowe kontrolki Qt z nową skórką, widoczny fokus, działający tooltip/active, nazwy ikon i świadome wejście klawiaturą na pasek. Zachować dobre rozwiązania klawiatury istniejących menu.

### A5. Test cyklu życia powierzchni nie dostarcza aktualnej zależności

**Wada testu potwierdzona wykonaniem.**

[test_surface_lifecycle.py](../../putpuccin/tests/test_surface_lifecycle.py), 23–24, tworzy atrapy `NotificationService` i `ScreenshotService`. Aktualny [SurfaceManager.qml](../../putpuccin/core/SurfaceManager.qml), m.in. 240–241, korzysta również z `AuthenticationService.interactive`.

Test zakończył się wtórnym `JSONDecodeError`; wcześniejszy log zawierał `ReferenceError: AuthenticationService is not defined`. Nie dowodzi to awarii produkcyjnego uwierzytelniania.

**Putkin:** jawne wstrzykiwanie małych adapterów, mniej przepisywania importów w fixture i czytelne raportowanie błędu startu QML przed próbą parsowania wyniku.

### A6. Zawartość panelu znika przed końcem animacji zamknięcia

**Niewielka niespójność cyklu życia, wynikająca z kodu; bez wizualnego odtworzenia.**

[BarIsland.qml](../../putpuccin/modules/statusbar/BarIsland.qml), 165–185, wiąże `Loader.active` bezpośrednio z `expanded`, równocześnie animując opacity. `syncExpansion()` w 65–72 także usuwa komponent natychmiast, choć ramka nadal może zwijać wysokość.

Wyłączenie `Loader.active` zwalnia obiekt, więc fade jego zawartości nie może dokończyć się na tym obiekcie. [Dokumentacja Qt Loader](https://doc.qt.io/qt-6/qml-qtquick-loader.html#active-prop).

**Putkin:** natychmiastowe zamknięcie albo jawny krótki stan zamykania, po którym zwalnia się widok. Interakcja i skanowanie kończą się od razu. To nie ustalenie o wycieku pamięci.

### A7. Starszy test lockera ma kruchą ochronę izolacji PAM

**Istotny brak zabezpieczenia testu; potwierdzony statycznie, bez wykonywania PAM.**

[test_lockscreen_wayland.py](../../putpuccin/tests/test_lockscreen_wayland.py), 69–79, podmienia tekst `config: "system-auth"` na prywatną konfigurację, lecz nie sprawdza powodzenia zamiany. Nie kontroluje też licznika hostowego faillock wymaganego przez lokalne zasady testowania.

Obecny tekst [LockService.qml](../../putpuccin/services/LockService.qml), 111–114, **pasuje do zamiany**. Zagrożeniem jest przyszły refaktor, po którym zamiana przestanie działać, a test nadal wystartuje. Nie stwierdzono aktualnego użycia hostowego PAM przez ten test.

Nowszy [lock_fallback_pam.py](../../putpuccin/tests/lock_fallback_pam.py), 87–132, pokazuje lepsze podejście: sprawdzenie izolacji przed startem i odmowa uruchomienia bez niej. Prywatny Wayland/D-Bus sam nie izoluje PAM.

**Putkin:** testować adapter zewnętrznej blokady na atrapach. Własny locker i testy PAM pozostają poza zakresem pierwszej wersji.

## 3. Kompromisy, które nie są automatycznie błędami

### Modułowość jest użyteczna, ale niepełna

Rejestr modułów jest powtórzony w [Settings.qml](../../putpuccin/core/Settings.qml), 64–72; [BarModuleHost.qml](../../putpuccin/modules/statusbar/BarModuleHost.qml), 12–28; [ModuleActions.qml](../../putpuccin/services/ModuleActions.qml), 9–24; i [SurfaceManager.qml](../../putpuccin/core/SurfaceManager.qml), 12–15. Koordynator zna także screenshot, uwierzytelnianie i przełącznik pulpitów.

To rozwiązanie daje przestawialny pasek, ale dodaje kilka miejsc synchronizacji i szczególne przypadki. Usunięcie kontrolki nie wyłącza automatycznie całej domeny. Dla stałej kompozycji Putkin wystarczy jawne złożenie kilku widoków i mały koordynator.

### Własne biblioteki wynikają z szerokiego zakresu

[NetworkService.qml](../../putpuccin/services/NetworkService.qml), 8 i 180–189, importuje `NetworkManagerNative`; [BluetoothService.qml](../../putpuccin/services/BluetoothService.qml), 7 i 195–205, `BluetoothNative`. Podstawowy graf importów wymaga więc bibliotek nawet wtedy, gdy zaawansowany panel nie jest otwarty.

[build-native](../../putpuccin/scripts/build-native), 8–16, i [instalator](../../putpuccin/scripts/install), 20–34, obejmują cztery biblioteki pulpitu i obserwator blokady. Instalator na Arch może uzupełnić pakiety przez `sudo pacman -Syu --needed` (54–70), co dokumentacja rozwoju opisuje wprost. Nie traktujemy tego jako ukrytej operacji; po prostu nie jest to właściwa podstawa minimalnej instalacji Putkin. Audyt nie instalował pakietów.

Nowy Quickshell może korzystać z dostępnych modułów bazowych. W zweryfikowanym API 0.3.1 zwykłe Wi-Fi PSK obsługuje już [WifiNetwork](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/WifiNetwork/). Rozbudowanego edytora C++ nie potrzeba do samego połączenia z domową siecią.

### Historia i dodatkowe narzędzia są decyzjami produktu

[NotificationService.qml](../../putpuccin/services/NotificationService.qml), 59–75, i [NotificationHistory.qml](../../putpuccin/services/NotificationHistory.qml), 7–8, zapisują historię w XDG_STATE_HOME, domyślnie 7 dni / 500 wpisów z ustawień. Było to opisane w starym planie; nie jest nowo wykrytym wyciekiem. Putkin nie przejmuje tej polityki automatycznie.

W schowku warto zachować ograniczenia sesyjne i obsługę danych oznaczonych jako wrażliwe. Natywny screenshot exporter, edytor VPN, agent BT, browser bridge i greeter rozwiązują realne problemy, lecz każdy wnosi osobny koszt utrzymania.

## 4. Zgodność z nowymi obrazami

| Obszar | Stan starego kodu | Decyzja Putkin |
| --- | --- | --- |
| Układ paska | Trzy szklane wyspy; [StatusBar.qml](../../putpuccin/modules/statusbar/StatusBar.qml), 139–183 | Jedna pełna belka, workspace po lewej, status po prawej, pusty środek |
| Geometria | [Metrics.qml](../../putpuccin/core/Metrics.qml), 16–21 i 54: wysokość 40, marginesy 8/12, promienie 14/16 | Nowe metryki: 32 px startowo, margines 0, rogi 0; odbiór w renderze |
| Kontrolki | Lokalne promienie m.in. ActionButton 83, SearchField 20, StatusSlider 18/35 | Jednolita geometria prymitywów; zmiana Metrics nie wystarczy do starego UI |
| Kolor akcentu | [Theme.qml](../../putpuccin/core/Theme.qml), 36: stałe Mauve; brak opcji w Settings/schema | Reaktywne tokeny i gotowy edytor kolorów w etapie 03 |
| Workspace | Kropki/pigułka, dawny zakres wyboru 1–10 | Numerowane 1–5 z obsługą dodatkowych aktywnych/zajętych przestrzeni |
| Quick Settings | Siatka wielu funkcji, dwa tory audio, Caffeinate/screenshot | Prosta pionowa lista i ograniczony zestaw funkcji |

Stary wygląd wynikał z jego własnej specyfikacji. Szkło i zaokrąglenia nie są błędem programistycznym. Zmienił się cel projektu.

**Nieweryfikowane ryzyko geometrii:** [BarIsland.qml](../../putpuccin/modules/statusbar/BarIsland.qml), 14 i 34–43, domyślnie dopuszcza szerokość 10000; tylko środkowa wyspa otrzymuje rzeczywisty limit w [StatusBar.qml](../../putpuccin/modules/statusbar/StatusBar.qml), 162. Wysokość rozwinięcia również nie ma wspólnego limitu ekranu. Mały ekran, duża skala i długi tekst wymagają testu. Nie przedstawiamy tego jako zaobserwowanego problemu na screenshotach.

Rysunek architektury sugeruje oddzielenie UI od usług. Singletony QML w jednym procesie nie dają izolacji awarii. Wystarczy rozdzielić odpowiedzialności i użyć istniejących daemonów systemowych; nie tworzyć mikroserwisu dla każdego kwadratu na obrazku.

## 5. Co przenieść, co napisać ponownie, co odłożyć

| Obszar poprzednika | Decyzja | Zakres ponownego użycia |
| --- | --- | --- |
| Cienki root i widoki per monitor | Zachować wzorzec | Nowy shell.qml zawiera wyłącznie funkcje Putkin |
| Theme/Metrics/Motion | Adaptować | Paleta i semantyka, nowa geometria, dynamiczne akcenty |
| Settings i jego testy | Adaptować selektywnie | Last-known-good, atomic write, stabilny reload; mały nowy schemat |
| AudioService / PowerService | Adaptować kod | Minimalne audio i bateria, jawne adaptery do testów |
| NetworkService / BluetoothService | Wybrać małe fragmenty | Natywne modele i lifecycle; usunąć obowiązkowe zależności zaawansowanych pluginów |
| BarIsland / BarModuleHost | Napisać nowy widok | Stały pasek i zakotwiczone panele, bez rejestru rozszerzanych wysp |
| SurfaceManager | Napisać mały koordynator | Reguły wyłączności, monitor, hotplug i fokus; bez logiki screenshot/PAM |
| Przyciski / pola / suwaki | Adaptować zachowanie Qt | Nowa skórka, nazwy, tooltipy i klawiatura |
| PopupLoader / KeyboardNavigation | Adaptować wzorce | Poprawny fokus i zakończenie lifecycle; testy na nowej kompozycji |
| OSD | Adaptować | Jedno źródło poziomu, krótki timeout, brak fokusu |
| Powiadomienia | Adaptować protokół, uprościć UI | Toasty/DND/akcje; bez trwałej historii i inline replies |
| Instalator | Zachować podejście, uprościć kod | Staging, backup, rollback; naprawiona bramka, brak automatycznego zarządzania pakietami |
| Launcher / media / clipboard / screenshot | Odłożyć | Osobne rozszerzenia po pierwszym wydaniu |
| VPN editor / pełny agent BT | Odłożyć | Opcjonalne dodatki, niezależne od startu paska |
| Własny lock / PAM / greeter | Poza pierwszą wersją | Początkowo zewnętrzny Hyprlock i adapter akcji sesji |

„Zachować” nie oznacza kopiowania katalogu bez zmian. Każdy fragment powinien przejść dostosowanie namespace, zakresu, zależności i testu jego kontraktu.

## 6. Faktycznie wykonane sprawdzenia

| Sprawdzenie | Wynik | Co potwierdza / czego nie potwierdza |
| --- | --- | --- |
| `quickshell --version` | 0.3.1, Arch Linux | Wersja lokalnego executable |
| `qmake6 -query QT_VERSION` | 6.11.2 | Wersja lokalnego Qt |
| `pacman -Q` dla Hyprland/Hyprlock | 0.56.2-3 / 0.9.6-3 | Pakiety zainstalowane, nie wersja działającej sesji |
| `hyprctl version` | Brak połączenia ze socketem | Nie ustalono stanu aktywnego kompozytora |
| `test_settings_validation.py` | **PASS** | Rzeczywisty FileView, walidacja i zapis w prywatnym katalogu |
| `test_settings_stability.py` | **PASS** | 20 reloadów bez niszczenia delegatów; przebudowa po reorderze |
| `test_surface_lifecycle.py` | **FAIL** | Nieaktualna atrapa AuthenticationService; ustalenie A5 |
| `test_install.py` | **19/19 PASS** | Pakowanie, istniejące biblioteki offscreen, backup, rollback i sprzątanie |
| `test-static` i błędna próbka QML | **Fałszywy PASS skryptu** | Parser 1 / skrypt 0; ustalenie A1 |
| `test_service_lifecycle.py` | **Brak wyniku zachowania** | Fixture się załadowała, lecz nie powstał socket IPC; ograniczenie sandboxa i/lub długości ścieżki AF_UNIX |
| `test_bluetooth_agent.py` | **Kompilacja OK, test D-Bus niewykonany** | `dbus-daemon` nie mógł utworzyć socketa w sandboxie; nie dowód regresji Bluetooth |

Testy instalatora i integracji używały kopii w `/tmp` z prywatnymi katalogami XDG i odciętym dostępem do hostowych adresów magistral. Wybrane testy core tworzyły własne fixture i katalogi; do prywatnych socketów wymagana była zaakceptowana eskalacja środowiska. Testy instalatora korzystały z dostępnych wcześniej lokalnych bibliotek — **nie poświadczają pełnego buildu wszystkich pluginów z czystego klonu**.

Nie uruchamiano pełnego shella na pulpicie, nie wykonywano operacji sprzętowych, testów PAM/greetera, realnego lock/suspend ani pomiarów CPU/RSS. Nie wykonano pełnego audytu bezpieczeństwa wszystkich natywnych modułów. Ocena kosztu wysp dotyczy konstrukcji, nie zmierzonej wydajności.

Nowy katalog Putkin udostępniał pusty/niedostępny jako repo Git katalog `.git`; `git status` nie rozpoznawał repozytorium. Dokumenty zapisano w workspace; nie deklarujemy utworzenia commitów. Poprzednie repo można było odczytać przez Git.

## 7. Jak audyt zmienia plan

- **00:** działająca kontrola błędów QML i wersjonowalna dokumentacja zamiast fałszywej zielonej bramki.
- **01–02:** nowy prosty pasek, jawne hostowanie paneli, klawiatura i limity obu osi.
- **03:** mały odporny Settings oraz rzeczywista edycja akcentów.
- **04–08:** adaptacja natywnych usług w ograniczonym zakresie, bez obowiązkowych własnych bibliotek.
- **09:** oddzielny odbiór roli serwera powiadomień; brak automatycznej migracji historii.
- **10:** zewnętrzna blokada, potwierdzona kolejność przed sleep, testy na atrapach.
- **12–13:** osobny odbiór renderowania/usług i prostszy, sprawdzony instalator z rollbackiem.

Pełne zadania i kryteria zawierają [roadmapa](../ROADMAP.md) i [prompty etapów](prompts/00-foundation.md). Granice architektury opisano w [architecture.md](architecture.md), a wierność obrazom w [design.md](design.md).
