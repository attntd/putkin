# Sieć i Wi-Fi — etap 07

## Osobny moduł — 2026-09-19

Wi-Fi ma osobny panel zarządzania otwierany z ikony paska.
Quick Menu zawiera tylko kafelek on/off, bez rozwijanej listy, tekstu
postępu ani komunikatu sukcesu. Obsługa błędów korzysta z powiadomień.
Kontrakt adaptera pozostaje wspólny; szczegóły nawigacji w [panelach](panels.md).

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade; ograniczony ruch
wyłącza je natychmiast. Kontrakty adapterów i potwierdzania operacji pozostają.


Jeden `NetworkService` jest wstrzykiwany do paska i Quick Settings.
`NetworkBackend` przekazuje natywne obiekty urządzeń i sieci
`Quickshell.Networking`; nie ma własnego pluginu C++, demona ani nmcli.
Widoki wykonują wyłącznie jawne akcje modelu. Ustawienia oraz produkcyjne
IPC pozostają bez zmian; hasła nie mają interfejsu IPC.

## Interfejs i granice

- Status obejmuje Ethernet, aktywne Wi-Fi, brak NetworkManagera/adaptera,
  radio i blokadę sprzętową. Oba połączenia mogą być widoczne równocześnie.
  Pasek pokazuje LAN/Wi-Fi/brak; tooltip i panel podają pełny stan.
- Dostęp do internetu pochodzi z osobnego `Networking.connectivity`:
  pełny, ograniczony, portal, brak albo nieznany. Wyłączone/nieskonfigurowane
  sprawdzanie oznacza stan nieznany. Putkin nie włącza kontroli łączności
  samodzielnie; przycisk po zalogowaniu do portalu żąda ponownego sprawdzenia.
- `setWifiEnabled(bool)` zmienia wyłącznie radio Wi-Fi. Wypełnienie przycisku
  odpowiada potwierdzonej wartości; stan oczekiwania jest osobny. Odmowa,
  brak potwierdzenia i rfkill mają komunikat. Żądanie wyłączenia od razu
  zwalnia skanowanie. Po odmowie lista może wznowić je dla nadal włączonego radia.
- Rozwinięcie pokazuje sieci każdego adaptera, procent sygnału, zabezpieczenie,
  zapisany profil i stan operacji. Nazwy i tooltipy używają `Text.PlainText`; znaki nowej linii/tabulatora
  w etykietach zastępujemy spacją, bez zmiany tożsamości sieci.
  Natywny ObjectModel zachowuje obiekty przy zmianie siły sygnału.
- Enter łączy lub rozłącza wybraną sieć. Najpierw zawsze `connect()`;
  dopiero `NoSecrets` dla WPA/WPA2 Personal albo SAE otwiera formularz PSK.
  Zapisane otwarte profile oznaczone przez 0.3.1 jako `Unknown` również
  można uruchomić. Nieznane niezapisane zabezpieczenia, WEP, OWE i enterprise
  wymagają edytora. Rozłączenie dotyczy wybranego urządzenia.
- Przycisk „VPN i profile · otwórz edytor” uruchamia opcjonalny
  `nm-connection-editor` z PATH. Brak programu pokazuje komunikat.
  Putkin nie edytuje profili/VPN/802.1X, nie uruchamia terminalowego nmtui
  i nie ma własnego agenta uwierzytelnienia enterprise.

Na pasku h/l przechodzi przez sieć między trayem a audio. W panelu h/l
działa w rzędzie radia, j/k na liście; Enter/Enter numeryczny aktywuje.
Tab, Shift+Tab i strzałki pozostają dostępne. Litery hjkl trafiają do pola
hasła. Escape najpierw anuluje operację/formularz, następnie zwija listę,
a potem zamyka panel. Mały ekran przewija zawartość do aktywnej kontrolki;
poniżej 480 px osobny wskaźnik sieci ustępuje wejściu do Quick Settings.

## Własność skanowania i operacji

`NetworkScanLease` należy do sekcji listy, jest aktywny tylko przy
rozwiniętej, widocznej i dostępnej sekcji. Licznik właścicieli w jednym
serwisie pozwala zwolnić tylko swoje żądanie. Serwis przełącza
`WifiDevice.scannerEnabled` wyłącznie tam, gdzie sam go wcześniej włączył;
zastanego aktywnego skanera nie wyłącza. Pozostali konsumenci Putkin
powinni korzystać z tego samego serwisu, a nie pisać flagi bezpośrednio.

Zamknięcie panelu zwalnia lease natychmiast przy wyłączeniu wejścia, przed
fade i destrukcją. To samo dotyczy Escape, zastąpienia strony, hotplug,
wyłączenia radia, rfkill, usunięcia adaptera, reloadu i destrukcji widoku.
Pasek nigdy nie żąda skanowania. Native scanner ogranicza częstość żądań;
Putkin nie dodaje timera skanowania ani odpytywania w spoczynku.

Serwis ma jedną bieżącą operację, obiekt docelowej sieci, numer operacji
i deadline 30 s. Przełączenie celu odłącza sygnały starego obiektu.
`providePsk(network, serial, value)` odrzuca nieaktualny formularz.
Anulowanie/timeout żąda natywnego `NetworkDevice.disconnect()` i usuwa
lokalny stan. Quickshell nie udostępnia identyfikatora ani anulowania
samego oczekującego wywołania D-Bus; jego odpowiedź nie może zatwierdzić
nowszej operacji Putkin. Stan rzeczywistego połączenia pozostaje własnością NM.

Hasło istnieje w maskowanym polu i argumentach bieżącego wywołania
`connectWithPsk(string)`. Pole czyści się przed wysłaniem oraz przy anulowaniu,
zmianie celu, utracie adaptera i zamknięciu. Model nie zapisuje hasła;
nie trafia ono do argv, logów Putkin, settings.json ani trwałych właściwości.
Qt/QML nie gwarantuje wyzerowania kopii pamięci; backend NetworkManager
może zachować PSK we własnym profilu, zgodnie z kontraktem natywnego API.

## Zweryfikowane API i ograniczenia 0.3.1

Sprawdzono lokalne Quickshell **0.3.1-1**, Qt **6.11.2**, NetworkManager
**1.58.1-1**, metadane `/usr/lib/qt6/qml/Quickshell/Networking/`, źródła
tagu v0.3.1 oraz oficjalne XML D-Bus z zainstalowanego pakietu NM
w `/usr/share/dbus-1/interfaces/`. Dokumentacja:

- [Networking 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/),
  [Network](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Network/),
  [WifiNetwork](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/WifiNetwork/),
  [WifiDevice](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/WifiDevice/).
- [Implementacja backendu 0.3.1](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/network/nm/backend.cpp),
  [skanowanie i grupowanie SSID](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/network/nm/wireless.cpp),
  [połączenia i PSK](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/network/nm/network.cpp),
  [interpretacja zabezpieczeń profili](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/network/nm/utils.cpp).
- [PersistentProperties 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/PersistentProperties/),
  [TextInput Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-textinput.html).

Zidentyfikowane ograniczenia mają konkretne konsekwencje:

1. Natywne ustawienie `wifiEnabled` jest optymistyczne, a ponowienie po
   odmowie może zostać pominięte przez pamięć podręczną. Dlatego **tylko
   boolean radia** zapisujemy typowanym `busctl set-property`, a następnie
   odczytujemy `GetAll` w JSON. Sam exit 0 nie potwierdza stanu. Nie używamy
   busctl do haseł ani łączenia. Jeden proces odczytu, jeden zapisu,
   deadline busctl 2 s + SIGKILL po 2,5 s; model czeka najwyżej 4 s.
2. Native singleton nie śledzi właściciela NM i nie inicjalizuje się ponownie.
   Jeden `gdbus monitor` obserwuje właściciela i właściwości głównego obiektu;
   utrata unieważnia dane. Powrót usługi/jej późny start wymaga **restartu
   procesu Putkin**, o czym mówi UI. `PersistentProperties` zachowuje tylko
   identyfikator właściciela i unieważnienie przy miękkim reloadzie. Twardy
   reload usuwa historię QML, zachowując natywny singleton; również wymaga
   restartu procesu i dostaje ten sam komunikat. Brak okresowego
   pollingu; odczyt następuje po zdarzeniu lub własnym zapisie.
3. Natywny model grupuje AP o tym samym SSID **na urządzeniu**, bez klucza
   zabezpieczeń/BSSID; Putkin zachowuje tę tożsamość. Nie obsługuje ręcznego
   wyboru BSSID ani nowych ukrytych SSID. Te przypadki należą do edytora.
   Zwykłe zapisane otwarte profile mogą mieć security `Unknown`.
4. Nie wszystkie błędy D-Bus stają się `connectionFailed`; brak potwierdzenia
   kończy się czytelnym timeoutem. API skanera nie publikuje wyniku RequestScan.
   Przycisk internetu pozostawia wynik ostatniego sprawdzenia NM.
5. `execDetached` nie zwraca wyniku życia aplikacji. Sprawdzamy obecność
   executable przed uruchomieniem edytora; nie deklarujemy, że jego okno
   zostało zmapowane. Proces wyszukiwania programu ma limit 1,5 s.

Wymagane gdbus/busctl pochodzą z glib2/systemd, używanych już w etapie 06.
Nie instalowano pakietów. Testy i ograniczenia środowiskowe:
[testing.md](testing.md), [status](status.md), [dowody](evidence/07-network.md).
