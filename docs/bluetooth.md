# Bluetooth — etap 08

## Osobny moduł — 2026-09-19

Bluetooth ma osobny panel zarządzania otwierany z ikony paska.
Quick Menu zawiera tylko kafelek on/off, bez rozwijanej listy, tekstu
postępu ani komunikatu sukcesu. Obsługa błędów korzysta z powiadomień.
Kontrakt adaptera pozostaje wspólny; szczegóły nawigacji w [panelach](panels.md).

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade; ograniczony ruch
wyłącza je natychmiast. Kontrakty adapterów i potwierdzania operacji pozostają.


Jeden `BluetoothService` w `shell.qml` otrzymuje `BluetoothBackend`.
`PanelHost` przekazuje go jawnie do Quick Settings. Natywne obiekty
`Quickshell.Bluetooth` są źródłem listy adapterów, sparowania, połączeń
i baterii. Widoki nie wywołują poleceń systemowych. Nie dodano ustawień,
produkcyjnego IPC, własnego demona, C++ ani agenta parowania.

## Obsługa

- Wiersz Bluetooth pokazuje stan i przełącznik radia. „Urządzenia” rozwija
  listę już sparowanych urządzeń wybranego adaptera. `paired`, a nie samo
  wykrycie urządzenia, decyduje o obecności na liście.
- Przy kilku adapterach lista wyboru podaje nazwę oraz `hciN`. Pierwszy
  wybór to najmniejsze ID w porządku leksykograficznym. Putkin zachowuje
  wybór przy zmianie radia i dodaniu kolejnego adaptera. Dopiero usunięcie
  wybranego adaptera wybiera pierwszy pozostały. Wybór jest stanem sesji.
- Enter łączy/rozłącza wskazane urządzenie. Stan oczekiwania jest osobny
  od potwierdzonego połączenia. Przy braku BlueZ/adaptera, wyłączonym radiu,
  blokadzie, pustej liście, odmowie, utracie urządzenia i przekroczeniu czasu
  UI zachowuje dostęp do informacji oraz menedżera parowania.
- Bateria peryferium jest opisana jako „Bateria urządzenia”, a oddzielny
  wiersz UPower jako „Bateria komputera”. Po zniknięciu `Battery1` procent
  urządzenia znika; nie zastępujemy go wartością 0%.
- h/l porusza się w rzędzie radia, j/k po adapterach i urządzeniach.
  Enter i Enter numeryczny aktywują; Tab/Shift+Tab, strzałki i Spacja
  zachowują standardowe wejście Qt. Escape zwija sekcję, następnie zamyka
  panel. Pole PSK w sąsiedniej sekcji zachowuje wpisywanie liter.
- ListModel aktualizuje się przez insert/remove/move, nie reset przy
  zmianie nazwy, połączenia czy baterii. Fokus na zachowanym urządzeniu
  pozostaje stabilny; po utracie aktywnego wiersza wraca na „Urządzenia”.
  Nazwy i tooltipy są zwykłym tekstem. Tooltip podaje pełną nazwę, adres,
  stan i opcjonalną baterię. Panel przewija się do aktywnej kontrolki.

## Żądania i zasoby

`setEnabled(bool)`, `activate(device)` i `selectAdapter(adapter)` są
jedynymi akcjami sprzętowymi modelu. Serwis szereguje operacje: kolejne
kliknięcie podczas oczekiwania nie wysyła dodatkowego wywołania. Zmiana
adaptera jest dostępna także podczas operacji; komunikat oczekiwania nadal
wskazuje jej pierwotny cel. Odpowiedź starej operacji nie wybiera adaptera,
nie kończy nowszej operacji i nie przypisuje błędu do nowego wyboru.

Potwierdzenie wymaga zarówno udanego wyniku wywołania, jak i zgodnego
stanu natywnego obiektu (`enabled`/`connected`). Brak potwierdzenia ma
limit 5 s dla radia i 30 s dla urządzenia; sam proces D-Bus ma limit
25 s i awaryjne zakończenie po 26 s. Identyfikator operacji, obiekt celu
oraz rewizja wyboru adaptera chronią przed spóźnionymi odpowiedziami.
Wywołania adresują unikalnego właściciela BlueZ, więc restart nie kieruje
starego żądania do nowej usługi pod tą samą nazwą.

Zamknięcie/zastąpienie panelu nie anuluje wcześniej zamówionego połączenia;
operacja należy do współdzielonej usługi. Utrata sprzętu/usługi, timeout
oraz zniszczenie serwisu kończą obserwowanie operacji i własny proces
pomocniczy. Zakończenie klienta D-Bus nie gwarantuje anulowania pracy
wysłanej już do BlueZ. Późniejszy potwierdzony stan sprzętu pozostaje
widoczny, bez pozornego sukcesu nowszego żądania.

**Nie ma discovery.** Putkin nie wywołuje StartDiscovery/StopDiscovery,
nie zmienia discoverable/pairable, nie paruje i nie usuwa kluczy. Otwarcie,
zamknięcie, błąd i reload listy nie zmieniają skanowania innego klienta.
Jedyny stały proces pomocniczy to pasywny obserwator właściciela `gdbus`.
Brak pollingu. `busctl` działa tylko podczas jawnego żądania.

## Przejście do parowania

„Sparuj nowe urządzenie…” sprawdza `blueman-manager` w PATH (limit 1,5 s)
i uruchamia go jako osobny program. Po zleceniu uruchomienia panel zamyka
się bez przywracania fokusu paska. Blueman odpowiada za skanowanie, wybór
adaptera, PIN/passkey i potwierdzenie parowania. Putkin nie przekazuje do
niego urządzenia ani kodów; użytkownik dokonuje wyboru w jego oknie.
Nowo sparowane urządzenie pojawia się przez sygnały BlueZ.

Brak programu pokazuje komunikat o opcjonalnym pakiecie Blueman i pozostawia
panel otwarty. Nie instalujemy go automatycznie. `execDetached` w 0.3.1
nie zwraca potwierdzenia gotowości obcego okna; przejście oznacza zlecenie
uruchomienia znalezionego programu. Nie jest potwierdzeniem sparowania.
Testy uruchamiają wyłącznie kontrolowaną atrapę executable, także gdy
prawdziwy menedżer jest zainstalowany na hoście.

## Sprawdzone API i ograniczenia

Lokalnie: Quickshell **0.3.1-1**, Qt **6.11.2**, BlueZ/bluez-utils **5.87-2**,
glib2 **2.88.3-1**, systemd **261.3-1**, python-dbus **1.4.0-2**
i python-gobject **3.56.3-1**. Sprawdzono wersje, lokalne qmltypes oraz
źródła tagu Quickshell v0.3.1 dostępne podczas implementacji.

- [Bluetooth 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/Bluetooth/),
  [BluetoothAdapter](https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothAdapter/),
  [BluetoothDevice](https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothDevice/).
- [Adapter1 BlueZ 5.87](https://github.com/bluez/bluez/blob/5.87/doc/org.bluez.Adapter.rst),
  [Device1 BlueZ 5.87](https://github.com/bluez/bluez/blob/5.87/doc/org.bluez.Device.rst).
- Źródła v0.3.1: [Bluez](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/bluetooth/bluez.cpp),
  [adapter](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/bluetooth/adapter.cpp),
  [urządzenie](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/bluetooth/device.cpp),
  [ObjectManager](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/dbus/objectmanager.cpp).
- [Process](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/),
  [execDetached](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/#func.execDetached),
  [ListModel Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtqml-models-listmodel.html),
  [Repeater Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-repeater.html).

Setter radia 0.3.1 jest optymistyczny i nie przywraca wartości po odmowie.
Connect/Disconnect nie udostępniają wyniku wywołania jako sygnału QML,
a `disconnect()` nie anuluje połączenia jeszcze niepotwierdzonego.
Dlatego wąskie wywołania Powered/Connect/Disconnect wykonuje `busctl`:
bez parsowania tekstowych list, bez nazw urządzeń w poleceniu powłoki,
bez dodawania alternatywnego modelu sprzętu. Natywny model nadal dostarcza
potwierdzone właściwości. Metadane Bluetooth mają niekwalifikowany typ
`UntypedObjectModel`; jawna właściwość `var` na granicy singletonu omija
błąd tych metadanych, zachowując bramkę importów i integrację natywną.

Singleton Bluez/ObjectManager tej wersji nie odbudowuje modelu po utracie
właściciela ani późnym starcie usługi. Putkin ukrywa wtedy stare dane,
blokuje żądania i prosi o **restart procesu Putkin**. Nie restartuje BlueZ
ani nie przeładowuje całego shella automatycznie. `PersistentProperties`
zachowuje historię właściciela podczas miękkiego reloadu. Twardy reload
z istniejącym natywnym modelem również wymaga restartu procesu, ponieważ
usuwa historię QML, zachowując singleton C++.

Wyniki, zrzuty, pomiary oraz niewykonany odbiór sprzętu/Waylanda:
[status](status.md) i [dowody etapu 08](evidence/08-bluetooth.md).
