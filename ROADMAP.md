# Roadmapa Putkin

## Wybrany zakres — okna uwierzytelniania, 2026-09-20

**Korekta wdrożona: `20260920-210039-bf2eb74b4b79`.**
[Odbiór odliczania](docs/status.md#odliczanie-odcisku-w-polkit--2026-09-20).
Pasek odliczania od lewej i glif po prawej, następnie
pole hasła w tym samym miejscu z widocznym fokusem. Gotowość hasła nadal
pochodzi z Polkit; bez zmiany systemowej polityki uwierzytelniania.

**Wdrożone: `20260920-204030-237db1e11390`.**
[Wyniki i granice testów](docs/status.md#natywne-okna-uwierzytelniania--2026-09-20).

Polkit, SSH/sudo askpass i Pinentry mają wspólny widok Putkina,
zatwierdzone teksty oraz istniejący fade. Odcisk ma wyłącznie glif;
niedopasowanie jest czerwone, sukces zielony, tekst dotyczy błędu czytnika.
[Kontrakt](docs/authentication.md). Bez zmiany systemowej polityki PAM.

## Planowana integracja Signala — 2026-09-20

Przygotowano [osobną roadmapę Signala](docs/signal/ROADMAP.md) i 13
samowystarczalnych promptów S00–S12 do kolejnych sesji Codex Max.
Zakres: komunikator przez signal-cli, synchronizacja od sparowania,
Mocha ze wspólnymi akcentami, życie usługi związane z shellem oraz
powiadomienia z otwarciem rozmowy i quick reply. **S00 — audyt i kontrakty
ukończony 2026-09-20**: wybrano signal-cli 0.14.8 JVM i transport stdio,
sprawdzono rzeczywiste API bez konta oraz syntetyczny transport testowy.
**S01 ukończony:** adapter QML, nadzorowany bridge/CLI, wyłączność,
ograniczony transport i testy cleanup/reloadu. **S02 ukończony:** SQLite,
historia incoming/sent sync, deduplikacja, szkice i trwały wspólny outbox.
Odbiór czeka na otwarcie bazy i potwierdzoną tożsamość. **S03 ukończony:**
sekcja Signal w ustawieniach, QR tylko w pamięci, anulowanie/wygaśnięcie,
kontrola powiązania, lokalny stop/resume i oddzielne kasowanie historii.
**S04 ukończony:** natywne okno wiadomości, tekst, szkice i nowa rozmowa;
wspólny UI oddzielony od Signala, routing przez usługę/konto/rozmowę.
**S05 ukończony lokalnie:** powiadomienia z routingiem i quick reply,
trwały osobny szkic, DND/wyciszenie/blokada i odzyskanie unknown.
**S06 ukończony lokalnie:** receipts per odbiorca, własne read sync,
odczyt widocznego aktywnego okna, wspólny unread/toasty i SQLite v3.
**S07 ukończony lokalnie:** pliki w kompozycji, kontrolowany magazyn,
miniatury/podgląd i Qt audio/wideo, SQLite v4 oraz przypięta poprawka CLI
ograniczająca pobieranie. **S08 ukończony lokalnie:** reakcje, edycje
z mapą wersji, cytaty, wzmianki UTF-16 i pisanie, SQLite v5.
Pisanie ma lokalny przełącznik, domyślnie wyłączony. **S09 ukończony lokalnie:**
usuwanie lokalne/remoteDelete, trwałe terminy znikania i czyszczenie kopii.
SQLite v6, CLI putkin-retention-2. **S10 ukończony lokalnie:** kontakty,
profile, tworzenie i administracja grup, zaproszenia, rekoncyliacja unknown,
akceptacja próśb, block i lokalne mute/hidden. SQLite v7; ten sam pin CLI.
**S11 ukończony lokalnie:** macierz odbioru, fault injection, prywatny
Wayland, 10 000 wiadomości, 60 s pomiarów i 20 cykli okna; pełna regresja PASS.
**S12 wdrożony:** `20260921-091350-39f9ddda75b4`, przypięte CLI/JRE,
zgodność migracji i rollback bez cofania danych, pełna regresja i lifecycle
pulpitu PASS. Zachowano nowsze funkcje main. Telefon sparowany; poprawka parsera
pisania wdrożona. Tekst w obie strony, reakcje i załączniki potwierdzone;
edycja i oba działania powiadomienia również działają. Potwierdzone są też
status odczytu, usuwanie i rozmowy grupowe. Podstawowy odbiór live PASS;
rozszerzona macierz pozostaje otwarta.
S09 uzupełnił eksport czasu startu w sent sync i faktycznego timera wysyłki.
[Status i dowody](docs/signal/STATUS.md).

## Wybrana korekta — stabilny fade, 2026-09-20

**Wdrożone z launcherem i poprawką screenshota: `20260920-155210-f60d99e92e0f`.**
[Odbiór](docs/status.md#wspólna-instalacja-launchera-fade-i-screenshota--2026-09-20).

Usunięcie opcji „Ogranicz ruch”, jednolity fade 200 ms i stabilny układ
oraz gradient od pierwszej widocznej klatki. Zakres obejmuje wspólne
przejścia i ustawienia; logika schowka jest rozwijana osobno.
[Kontrakt](docs/design.md#stabilny-fade--2026-09-20).

## Wybrana korekta launchera — 2026-09-20

**Wdrożone: `20260920-155210-f60d99e92e0f`.**

Bez nagłówka powtarzającego wybraną kategorię. Schowek ma zwarte wiersze
z samą treścią oraz kwadratowy podgląd tekstu lub obrazu po prawej,
wyrównany do góry launchera. Zachowujemy szerokość listy i wspólne wejście,
fokus oraz gradient. [Kontrakt](docs/launcher.md). Bez kolejnych etapów.

## Wybrany zakres — screenshot, 2026-09-20

**Pierwsze wdrożenie: `20260920-144910-c522126acd2f`.**
[Wyniki testów i aktywacji](docs/status.md#screenshot--2026-09-20).

Print Screen i `:screenshot` otwierają lekki wybór zakresu. Enter zatwierdza
zaznaczenie lub cały bieżący monitor; W przechwytuje okno aktywne przed
uruchomieniem (również przed launcherem). PNG powstaje dopiero po
zatwierdzeniu; Escape/Q anuluje wybór bez przechwycenia. Pływający podgląd pozwala zapisać obraz przez Enter/F albo
zamknąć przez Escape/Q, zachowując automatyczną kopię w schowku.
[Kontrakt](docs/screenshot.md). Bez rozszerzania instalatora.

Korekta z tego samego dnia usuwa błąd odnawiania reguły nakładki po
przeładowaniu. Sześć reloadów i regresja natywna PASS; wdrożona razem
z fade i launcherem w `20260920-155210-f60d99e92e0f`.
[Wyniki](docs/status.md#screenshot-po-przeładowaniu--2026-09-20).

## Wybrana migracja sesji — 2026-09-20

Na wyraźne polecenie użytkownika zastępujemy Hyprlock i Hypridle w **jednym
procesie Quickshell**. Zakres etapu 10 obejmuje teraz natywne WlSessionLock,
PAM hasła i odcisku, IdleMonitor, integrację logind i inhibitorów oraz
istniejące Caffeinate. Zachowujemy progi 180/300/360/900 s. Dotychczasowe
opisy zewnętrznej blokady poniżej są historią poprzedniej implementacji.
Nie dodajemy drugiej instancji shella ani nie rozszerzamy instalatora.
**Wdrożone: `20260920-native-session-9a3db25af706`**. Testy i aktywacja PASS;
hasło, czytnik i fizyczny sen nowej blokady pozostają do odbioru na sprzęcie.
[Stan i powrót](docs/install.md#natywna-blokada-i-bezczynność--2026-09-20).

## Kierunek

Zbudować mały shell Quickshell dla Hyprlanda według obrazów z katalogu głównego. Z poprzednika wykorzystać sprawdzone wzorce adapterów, konfiguracji i testów; pasek, panele i korzeń kompozycji przygotować do nowego zakresu. Uzasadnienie i konkretne usterki zawiera [audyt](docs/audit.md).

**Wymagania użytkownika uwzględnione w planie:** minimalistyczny wygląd z referencji, początkowa paleta Mocha, edytowalne akcenty w ustawieniach, ocena poprzedniego kodu i uporządkowane prompty samowystarczalne w kontekście repo.

### Jak korzystać

1. Wybierz następny etap i skopiuj **cały plik promptu** do nowej sesji agenta pracującego w tym repozytorium.
2. Prompt zawiera kontekst, zależności, materiały, zadania, warunki odbioru i wymagany wynik. Może odsyłać do dokumentów tego repo; nie wymaga poprzedniej rozmowy ani starego repo dostępnego na dysku.
3. Każdy etap kończy się działającym wycinkiem i wpisem w [statusie](docs/status.md). Gdy brakuje testu środowiskowego, status ma to wyraźnie zaznaczać.
4. Następny etap opiera się na faktycznych interfejsach zapisanych w kodzie i dokumentacji. Nazwy z planu są propozycją, nie pretekstem do tworzenia równoległej implementacji.

## Etapy i gotowe prompty

| Etap | Prompt | Rezultat |
| --- | --- | --- |
| 00 | [Fundament i bezpieczne środowisko pracy](docs/prompts/00-foundation.md) | Uruchamialny, mały szkielet Quickshell z tokenami wyglądu i powtarzalnym podglądem na atrapach. |
| 01 | [Pasek, workspace i zegar](docs/prompts/01-bar-workspaces.md) | Pierwszy użyteczny pasek zgodny z kompozycją referencji. |
| 02 | [Quick Settings, okna i fokus](docs/prompts/02-panels-focus.md) | Stabilne otwieranie jednego kompaktowego panelu oraz podstawa pod ustawienia. |
| 03 | [Ustawienia wyglądu i edycja akcentów](docs/prompts/03-appearance-settings.md) | Użytkownik zmienia kolory w interfejsie, widzi je od razu i zachowuje po restarcie. |
| 04 | [Audio i OSD głośności](docs/prompts/04-audio-osd.md) | Regulacja wyjścia audio z paska, panelu i skrótów korzysta z tego samego stanu. |
| 05 | [Jasność i wspólny OSD](docs/prompts/05-brightness.md) | Sterowanie jasnością podświetlenia laptopa prostym, przewidywalnym adapterem. |
| 06 | [Bateria i tray](docs/prompts/06-battery-tray.md) | Uzupełniony prawy status paska bez dodatkowych ciężkich usług. |
| 07 | [Sieć i zwykłe Wi-Fi](docs/prompts/07-network.md) | Status połączenia oraz podstawowa obsługa Wi-Fi bez własnego edytora sieci i pluginu C++. |
| 08 | [Podstawowy Bluetooth](docs/prompts/08-bluetooth.md) | Włączanie Bluetooth oraz wygodne połączenia z już sparowanymi urządzeniami. |
| 09 | [Powiadomienia i DND](docs/prompts/09-notifications.md) | Proste toasty zgodne z referencją i jeden prawidłowy serwer powiadomień. |
| 10 | [Menu sesji, blokada i bezczynność](docs/prompts/10-session-lock.md) | Menu Power, natywna blokada i bezczynność w jednej instancji Quickshell. |
| 11 | [Opcjonalne dopasowanie pulpitu i Night Light](docs/prompts/11-desktop-extras.md) | Dopasowanie elementów z referencji, którymi zarządzają programy poza Quickshellem. |
| 12 | [Odbiór funkcjonalny, wygląd i wydajność](docs/prompts/12-validation.md) | Zweryfikowany kandydat pierwszego wydania, z poprawionymi wykrytymi usterkami. |
| 13 | [Instalacja, przełączenie i rollback](docs/prompts/13-installation.md) | Przenośny, sprawdzony sposób instalacji i przełączenia z poprzedniego shella. |

## Kamienie milowe

| Kamień milowy | Etapy | Co można ocenić |
| --- | --- | --- |
| A — wygląd i personalizacja | 00–03 | Uruchamialny pasek, poprawne panele, własne kolory zapisane z UI |
| B — codzienne sterowanie | 04–08 | Audio, jasność/OSD, bateria/tray, sieć i podstawowy Bluetooth |
| C — funkcjonalna pierwsza wersja | 09–10 | Powiadomienia/DND, power menu i zewnętrzna blokada |
| D — kandydat wydania | 12 | Potwierdzona jakość UI, testy i pomiary; naprawione znalezione regresje |
| E — instalacja i przełączenie | 13 | Przetestowana instalacja/rollback, następnie osobno odnotowana aktywacja |

Etap **11 jest opcjonalny** i dopasowuje pozostałą część pulpitu do obrazów. Minimalne wydanie obejmuje 00–10, 12 i 13. Aktywacja w etapie 13 pozostaje ostatnią operacją po przygotowaniu i testach. Po uwagach użytkownika wykonano i zweryfikowano korektę wyglądu; po rozszerzeniach launchera, baterii, komend workspace, osobnego panelu audio oraz okna Ustawienia z sekcją Klawiatura po korekcie Quick Menu i dodaniu centrum powiadomień po korekcie kafelków, retencji transient i dodaniu Caffeinate po poprawie ikon modułów, ramki launchera i wspólnego gradientu grup oraz doprecyzowaniu przekątnej, fokusu pełnych wierszy i synchronizacji ramek Hyprlanda po naprawie powrotu fokusu w opcjach Caffeinate po dodaniu ikon aplikacji Papirus-Dark, ich jasnego wariantu i glifu odcisku w blokadzie oraz zastąpieniu ikon Quickshell zestawem Material Symbols po zmniejszeniu ikon topbara i ujednoliceniu ich koloru z zegarem po wycentrowaniu treści nad separatorem oraz przywróceniu oryginalnego Material Charging … 2 w szerszym polu z dopasowaną wysokością korpusu po zmianie ikon Signala na Chat bubble / Chat po migracji sesji obecnie działa `20260920-native-session-9a3db25af706`. Wcześniejszy odbiór sprzętu pozostaje zapisany osobno; kolory i reset glifu sprawdzono w izolowanym Hyprlocku z atrapami PAM i fprintd. Aktualizacja 2026-09-20: instalator użytkownika i domyślne `qs` przez UWSM są wdrożone, z limitem pięciu buildów; szczegóły poniżej i w aktualnym statusie. [Dowody i status](docs/status.md).

Bieżąca korekta zlecona 2026-09-20 ujednolica ikony Quickshell w Material
Symbols Outlined: jeden kolor, wspólny rozmiar i padding wewnątrz sekcji,
rodziny Battery Android, Notifications oraz Network WiFi. Doprecyzowanie
paska centruje treść nad separatorem. Ładowanie używa oryginalnych
Charging … 2, z wysokością korpusu dopasowaną do Battery Android i szerszym
polem na piorunek po prawej. Zastępuje to wariant z wewnętrznym piorunkiem.
Korekta Signala wybiera `chat_bubble` w launcherze oraz bez nieprzeczytanych
w trayu; nowe wiadomości przełączają tray na `chat`, bez zmiany koloru,
rozmiaru i paddingu. Zakres pakietu ikon nie obejmuje równoległej migracji
blokady i bezczynności opisanej na początku roadmapy.
Glif odcisku i uwierzytelnianie przenosi wybrana migracja natywnej blokady.
Nie rozszerza kolejnych etapów ani zakresu instalatora. [Kontrakt wyglądu](docs/design.md).

## Zależności i możliwość równoległej pracy

Zalecana kolejność jest liniowa, aby po każdej sesji istniała spójna aplikacja. Faktyczne zależności:

- 00 → 01 → 02 → 03.
- 04 wymaga 03; 05 wymaga 04, ponieważ współdzieli OSD.
- 06 i 07 mogą powstawać po 03; 08 korzysta z wzorców list z 07.
- 09 wymaga podstaw 00–03. W sekwencji jest później, bo przejęcie roli serwera powiadomień ma osobny odbiór.
- 10 wymaga 00–05 i prawidłowo rozpoznanego backendu sesji; podłącza też odświeżenie jasności po wznowieniu. Brak rzeczywistej walidacji lock/suspend pozostaje jawnym otwartym kryterium.
- Opcjonalny 11 wymaga 03 i 10. 12 zbiera całe zrealizowane 00–10; 13 zależy od ukończenia obowiązkowego odbioru 12.

Przy ponownym podziale pracy na subagentów dobre niezależne zadania po 03 to adapter audio, bateria/tray oraz adapter sieci. Jeden właściciel integruje `shell.qml`, Quick Settings, Theme, Settings i koordynator; równoległe edycje tych samych kontraktów wymagają wcześniejszego uzgodnienia. Przegląd i testy można delegować niezależnie od implementacji. Nie należy równocześnie uruchamiać kilku shelli na hostowym D-Bus.

## Decyzje przyjęte, aby utrzymać mały zakres

- Pierwsza platforma: **Hyprland na Linuksie**, zgodnie z obrazami i poprzednikiem. Wsparcie innych compositorów to późniejsza decyzja.
- Jeden proces Quickshell i adaptery do istniejących usług. Własne C++ oraz nowe daemony dopiero przy konkretnej luce API.
- Pasek ma stałą prostą kompozycję; brak edytora dowolnej kolejności modułów.
- Dwa akcenty z presetami i własnym HEX, domyślnie Mauve/Blue. Zmiana jest reaktywna w Putkin; zewnętrzne aplikacje mają swoje konfiguracje.
- Zwykłe Wi-Fi, w tym PSK, mieści się w podstawie. VPN/enterprise/pełny edytor profili — poza nią.
- Bluetooth zarządza radiem i sparowanymi urządzeniami. Pełny agent parowania wewnątrz shella pozostaje dodatkiem.
- Blokada i bezczynność w Quickshell: WlSessionLock, PamContext i IdleMonitor.
- Powiadomienia w pierwszej wersji nie zapisują historii na dysku.
- Tapeta wymaga osobnego czystego pliku; obrazy referencyjne zawierają narysowane elementy UI.

To rekomendowane założenia produktu, nie nieodwracalne ograniczenia. Zmianę zakresu odnotować w [design.md](docs/design.md) i zależnym prompcie przed implementacją.

## Backlog po pierwszej wersji

Wybrana korekta 2026-09-20: ujednolicenie wszystkich ikon Quickshell w Google
Material Symbols Outlined, sekcyjne rozmiary i padding, stany Battery Android,
Notifications / Unread / Off oraz Network WiFi. Lokalne SVG
zastępują Papirus i Canvas. Kolejna korekta dopasowuje topbar: pole ikony
20 px, padding poziomy 6 px / pionowy 5 px, centrowanie nad dolnym
separatorem i stały kolor daty/czasu niezależnie od stanu. Zegar centruje
obrys znaków, a ładowanie używa oryginalnego Material Charging … 2 w szerszym
polu, zachowując wysokość korpusu baterii i padding sekcji.
Bez rozszerzania instalatora ani kolejnych etapów.
[Wyniki](docs/status.md).

Wybrany zakres 2026-09-19: wspólny fokus dźwięku i klawisz `i`, krótkie
nazwy wyjść, kafelki Wi-Fi/BT z osobnymi modułami zarządzania oraz centrum
powiadomień z DND i historią wyłącznie w pamięci sesji. Bez trwałego
zapisu historii i bez rozszerzania parowania czy edytora sieci.

Wybrany zakres 2026-09-17: launcher z nagłówkiem „Ostatnie” i chipem
„Komenda” oraz osobne okno „Ustawienia” z sekcjami Wygląd i Klawiatura.
Klawiatura przypisuje skróty i komendy `:` do gotowych działań Hyprlanda
i shella; bez edytora własnych dispatcherów i bez podpowiedzi.

Wybrana korekta 2026-09-17: bez tekstu pomocniczego niepełnych komend,
Super+V do schowka, Super+: do komend i osobny panel audio z mikrofonem
oraz wyborem wejść/wyjść. Zakres nie rozpoczyna kolejnych etapów roadmapy.

Wybrane rozszerzenie launchera: komendy `:wN` i `:mwN` (cyfry 0–9),
z potwierdzeniem przez Enter i zachowaniem okna sprzed otwarcia panelu.

Kolejny wybrany zakres (2026-09-17): osobny panel baterii i trybów pracy,
adaptowany z `BatteryPopup.qml` oraz `PowerService.qml` poprzednika.
Procent, pasek, czas i trzy profile; bez rozbudowy zarządzania sprzętem.

Wybrany przez użytkownika 2026-09-17 osobny zakres: **launcher aplikacji,
plików i schowka pod Super+Spacja**, z filtrami i historią poprzednika.
[Kontrakt](docs/launcher.md). Nie rozpoczyna instalatora etapu 13 ani
pozostałych rozszerzeń backlogu.

| Rozszerzenie | Punkt startowy w poprzedniku | Warunek dodania |
| --- | --- | --- |
| Prosty launcher aplikacji | LauncherQuery / LauncherPopup | Osobny cel; bez terminalowego kontekstu, historii wszystkich plików i bridge na start |
| Media MPRIS | MediaService i MediaPopup | Faktyczne zapotrzebowanie; nie zajmować domyślnie pustego środka paska |
| Centrum powiadomień | NotificationService / NotificationHistory | Historia sesji wybrana 2026-09-19; trwały zapis poza zakresem |
| Pełne parowanie BT / edytor sieci | BluetoothNative / NetworkManagerNative | Osobny etap, zależności opcjonalne i testy protokołu |
| Schowek i screenshot | ClipboardService / ScreenshotService | Oddzielny produktowy zakres i zasady prywatności/retencji |
| Własny locker lub greeter | LockService / GreeterNative | Oddzielny projekt bezpieczeństwa i pełna walidacja; nie zależność paska |

Backlog nie jest zobowiązaniem do odtworzenia poprzedniego DE. Gotowe prompty tej roadmapy obejmują pierwszą wersję z referencji; prompt rozszerzenia powinien powstać dopiero po wyborze jego zakresu.

## Wspólny warunek ukończenia

Wybrana instalacja 2026-09-20: domyślne `qs` przez UWSM, stała ścieżka
konfiguracji, pięć buildów i `scripts/install` z dry-run, stagingiem,
prywatnym celem oraz rollbackiem. **Wdrożone**; aktywna wersja i dowody:
[status](docs/status.md#domyślne-qs-uwsm-i-pięć-buildów--2026-09-20).
Zastępuje wcześniejszą informację o braku instalatora. Pierwsze podłączenie
do dowolnej innej konfiguracji Hyprlanda pozostaje jawne według instrukcji;
nie rozszerza tej pracy o migrację innych środowisk.

Działający wycinek, obsłużony brak usługi i błąd, klawiatura i właściwy monitor, tokeny wyglądu, zwolnienie zbędnych zasobów, adekwatne testy z rzeczywistym wynikiem oraz aktualny status. Sam zielony formatter, samo screenshotowanie atrap i samo napisanie dokumentacji nie oznaczają ukończenia funkcji.

W tym środowisku na etapie audytu nie było dostępnego połączenia z aktywnym Hyprlandem; nie wykonano wtedy testów całego pulpitu. Późniejszy [odbiór etapu 12](docs/validation.md) potwierdził natywny Wayland, a użytkownik potwierdził działanie sprzętu i sesji.
