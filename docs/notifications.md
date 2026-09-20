# Powiadomienia i DND — etap 09

## Karty, rozwijanie i przewijanie — 2026-09-20

Zaznaczenie obejmuje kartę. Kliknięcie jej nagłówka lub treści oraz `Enter`
wywołuje akcję `default`, a przy jej braku pierwszą dostępną akcję.
Karta bez akcji (w tym archiwalna) pozostaje dostępna do czytania i usuwania;
jej aktywacja nie zamyka panelu. Osobne przyciski zachowują własne akcje.
Przycisk × ma grubszy symbol i domyślnie przezroczyste tło bez ramki;
fokus jest widoczny wyłącznie podczas obsługi klawiaturą.

Gdy tytuł lub treść są skrócone, w nagłówku pojawia się strzałka rozwijania.
`i` pokazuje wszystkie linie w granicach istniejącego limitu znaków;
`Escape` najpierw zwija wybraną kartę, a kolejne naciśnięcie zamyka panel.
`j/k` i strzałki góra/dół przechodzą między kartami niezależnie od rozwinięcia.
Powrót odsłania początek karty i zachowuje jej rozwinięcie. `l` oraz `Tab`
udostępniają przyciski rozwijania, zamknięcia i poszczególnych akcji.

W centrum karty mają wysokość zawartości i korzystają ze wspólnego
przewijania panelu, także kółkiem nad tekstem. Toasty zachowują ograniczoną
wysokość i przewijają długą treść wewnętrznie. Rozwinięcie nie uruchamia
akcji powiadomienia, a kliknięcie biernego toasta nie przejmuje klawiatury.

## Centrum i historia sesji — 2026-09-19

Dzwonek w pasku oraz dotychczasowy skrót otwierają centrum, także gdy lista
jest pusta. DND ma zsynchronizowane kontrolki w centrum i kafelek w Quick Menu.
Oddzielny przycisk „Powiadomienia” z Quick Menu usunięto 2026-09-20. Obok jest przycisk „Wyczyść”; każda karta ma
zamknięcie, a żywe powiadomienie zachowuje dostępne akcje protokołu.
Centrum jest pojedynczym panelem `notifications` istniejącego PanelHost,
z klawiaturą h/j/k/l, Enter, Tab, Escape i ramką wyłącznie dla klawiatury.

Historia mieści do 100 wpisów, od najnowszych, wyłącznie w pamięci procesu.
Zachowuje zwykłe powiadomienia po timeout, zamknięciu toasta i wyciszeniu
przez DND; nie odtwarza ich później jako toastów. `transient` również pozostają
w historii (korekta 2026-09-20, zgodnie z poleceniem użytkownika). Zastąpienie żywego ID aktualizuje ten sam wpis. Każdy rekord
ma niezależny klucz, ograniczony tekst i bezpieczną ikonę; nie przechowuje
obiektów akcji ani obrazów natywnego providera. Po zamknięciu protokołu
archiwalna karta nie wykonuje akcji. Clear/× w centrum usuwa wpis i zamyka
jego żywy obiekt, jeśli nadal istnieje. Restart/reload czyści całą historię.

Limity 3 widocznych i 12 oczekujących toastów nadal dotyczą żywych
obiektów protokołu. Historia jest osobnym, ograniczonym zbiorem kopii.
Nie ogłaszamy protokołowego persistence i nie zapisujemy treści na dysku.
Otwarte centrum zastępuje widok toastów na swoim monitorze; inne ekrany
zachowują ich normalne zachowanie. Błędy Putkina omijają DND.


Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade; ograniczony ruch
wyłącza je natychmiast. Kontrakty adapterów i potwierdzania operacji pozostają.


Jeden `NotificationBackend` tworzy jeden natywny `NotificationServer` po
sprawdzeniu nazwy `org.freedesktop.Notifications`. `NotificationService`
zarządza toastami, historią sesji i DND; `NotificationEntry` trzyma referencję do żywego
obiektu protokołu i timer. Widoki otrzymują zależności jawnie, bez poleceń
systemowych ani wykonywania treści nadawcy.

## Zachowanie

| Zdarzenie / parametr | Reguła Putkin |
| --- | --- |
| Nowe powiadomienie | Jeden monitor: skupiony przy nadejściu, następnie pierwszy ekran z miejscem. |
| Zastąpienie żywego ID | Ten sam obiekt i monitor, aktualne teksty/akcje i nowy termin. Identyczne zastąpienie również odnawia timeout. |
| Zastąpienie nieznanego/zamkniętego ID | Natywny serwer tworzy nowy identyfikator. |
| Timeout −1 / inne wartości ujemne | 6000 ms od nadejścia lub zastąpienia. |
| Timeout dodatni | Milisekundy klienta, także podczas oczekiwania w kolejce. |
| Timeout 0 | Bez automatycznego wygasania. Nadal obowiązują DND, limity, brak ekranu i reload. |
| Krytyczne (`urgency=2`) | Ominie DND, ma pierwszeństwo przy przydziale miejsc i nie wygasa automatycznie, także przy dodatnim timeout. Tekst „Pilne” i kolor błędu. |
| DND | Włączenie wygasza zwykłe widoczne i oczekujące obiekty; nowe zwykłe od razu wygasają. Treści, także transient, pozostają w centrum. Wyłączenie nie odtwarza toastów. |
| Akcja | Natywne `ActionInvoked` z identyfikatorem. Bez `resident` następuje zamknięcie; `resident=true` zachowuje obiekt. |
| `resident` z dodatnim timeout | Zachowanie po akcji nie wyłącza timera. |
| `transient` | Toast wygasa normalnie; ograniczona kopia tekstu pozostaje w historii sesji. |
| Zamknięcie użytkownika / akcja bez resident | `NotificationClosed`, reason **2** (dismissed). |
| Timeout, DND, przepełnienie, brak ekranów, reload | Reason **1** (expired). |
| Klient `CloseNotification` | Reason **3** (close requested). Nieznane ID jest bezpiecznym no-op. |
| Utrata monitora | Przekierowanie na aktualnie skupiony dostępny ekran, następnie pierwszy. Bez nowego ID i odnowienia czasu. Brak wszystkich ekranów wygasza obiekty. |
| Zmiana rozmiaru | Ponowny przydział miejsc; przewijanie zawartości i akcji wewnątrz ograniczonego prostokąta. |
| Soft/hard reload | `keepOnReload=false`: stare obiekty wygasają, widoki i obserwator są zwalniane. DND wraca do **wyłączonego**; treści nie są odtwarzane. |

Klient może rozłączyć i ponownie nawiązać połączenie D-Bus. Zachowane ID
pozostaje użyteczne do zastąpienia lub zamknięcia. Putkin wywołuje tylko
akcję istniejącą w natywnym obiekcie; nie uruchamia aplikacji na podstawie
nazwy, body, desktop-entry lub URI.

## Limity i wygląd

Maksymalnie **3 widoczne i 12 oczekujących** obiektów w całym procesie.
Mniejszy ekran obniża liczbę widocznych: slot wymaga szerokości 160 px
oraz 132 px wysokości pod paskiem, z odstępami. Przy 320×220 jest jeden slot
i najwyżej 13 obiektów łącznie. Krytyczne otrzymują miejsca przed zwykłymi;
w obrębie danej pilności obowiązuje FIFO. Przy przepełnieniu wygasa
najstarszy oczekujący zwykły, następnie najstarszy oczekujący krytyczny.
Nowy zwykły nie wypiera kolejki złożonej wyłącznie z krytycznych.
Widoczny obiekt z timeout 0 nie jest ofiarą zwykłego zalewu, ale krytyczne
mogą przesunąć go do kolejki. Usunięcie zwalnia slot.

Toast ma nieprzezroczyste tło, kwadratowe rogi, wspólne tokeny i cienką
ramkę akcentu. Szerokość do 360 px, wysokość do 280 px i do przydzielonego
fragmentu ekranu. Nagłówek z ikoną, aplikacją, czasem HH:mm i zamknięciem
pozostaje widoczny podczas przewijania. Czas pochodzi z nadejścia/aktualizacji;
nie uruchamia zegara sekundowego.

UI ogranicza aplikację do 128 znaków, tytuł do 512 i trzech linii, treść do
4096 i sześciu linii w widoku zwiniętym; tekst kończy się wielokropkiem.
Rozwinięcie usuwa ograniczenie liczby linii. Teksty nadawcy, także
etykiety akcji i tooltipy, są `PlainText`. Nie ma HTML, klikanych linków,
inline replies, dźwięku ani ikon akcji. Najwyżej osiem pierwszych akcji;
identyfikator do 256 znaków i etykieta do 128. `inline-reply` jest pomijane.
Nawigacja dochodzi do ostatniej wyświetlonej akcji przez scroll.

Ikony aplikacji używają dostępnej nazwy motywu albo lokalnego dzwonka Putkin.
Ścieżki/URI w `app_icon` mają dzwonek zastępczy. Osobny obraz powiadomienia
obsługuje natywny provider oraz lokalne `file:///`; body nie inicjuje HTTP.
Obraz zachowuje proporcje, wysokość 100 px i `sourceSize` do 360×100, bez
cache. Plikowe obrazy mogą ładować się asynchronicznie; natywny `qsimage`
korzystający z pamięci `Notification` jest pobierany synchronicznie.

Limity tekstu i `sourceSize` ograniczają prezentację. **Nie są limitem
wielkości wiadomości D-Bus ani surowego obrazu w natywnym serwerze**:
Quickshell 0.3.1 dekoduje je przed sygnałem QML. Liczba żywych powiadomień
jest ograniczona, lecz dowolnie duże pojedyncze payloady nadal mogą wymagać
znacznej pamięci. Nie deklarujemy ochrony procesu przed złośliwym klientem
lokalnym. Sprawdzono RGBA 2048×1024 (8 MiB), także jego zastąpienie.

## Fokus i okna

`NotificationWindows` tworzy przez `Variants` lekki host per ekran;
`LazyLoader` ładuje okno tylko z widocznymi toastami. Jeden obiekt nie jest
wyświetlany na kilku monitorach. Maska obejmuje prostokąt stosu, bez
obszaru paska i prawego marginesu. Zwykłe nadejście, kliknięcie zamknięcia
i akcji nie włącza klawiatury (`WlrKeyboardFocus.None`, kontrolki `NoFocus`).
Nie ma animacji zamykania wymagającej przechowywania martwego obiektu:
`closed` usuwa referencję i widok przed destrukcją natywnego powiadomienia.

Jawne wejście do centrum: dzwonek paska oraz IPC `notifications focus`. DND jest pierwszą kontrolką, następnie
„Wyczyść” i karty. h/j/k/l, Enter, Tab/Shift+Tab i Escape nie przechwytują
liter w polach innych widoków. Wewnętrzny NotificationFocus.enter nadal
obsługuje bezpośrednią nawigację toastów i jej testy. Usunięcie wybranej
karty lub akcji przywraca poprawny fokus z zachowaniem mysz/klawiatura.

Escape przy zwiniętej karcie, kliknięcie poza grabem, otwarcie panelu, wejście na pasek lub utrata
monitorowanych toastów zwalnia klawiaturę. Przed wywołaniem akcji kontroler
kończy nawigację, pozwalając klientowi skupić własne okno. Gdy panel zasłania
prawy górny róg tego samego monitora, okno toastów jest zwolnione; czas nadal
biegnie. Inne ekrany wyświetlają swoje toasty normalnie. To tymczasowe
ustąpienie panelowi; historia pozostaje dostępna w centrum.

Faktyczny powrót wejścia do osobnej aplikacji, bierne toasty, jawne wejście
przez IPC oraz wyjście przez Escape i kliknięcie poza grabem sprawdzono
w prywatnym Hyprlandzie 0.56.2; [odbiór etapu 12](validation.md).
QtTest osobno sprawdza kontrolki i akcje. Klienci powiadomień i treść
w odbiorze UI są syntetyczni; nie przełączano serwera powiadomień hosta.

## API, zależności i własność nazwy

Sprawdzono Quickshell **0.3.1-1**, Qt **6.11.2**, lokalne qmltypes,
systemd/busctl **261.3-1**, dbus **1.16.2-1**, python-dbus **1.4.0-2**
i python-gobject **3.56.3-1**. Pakietów nie instalowano. Te dwa pakiety
Python są od etapu 09 również zależnością **produkcyjną**, nie tylko testową.

Preflight przez typowane wywołania `busctl --user`: `NameHasOwner`,
`GetConnectionUnixProcessID`. Obcy właściciel blokuje utworzenie serwera
i zgłasza błąd przez powiadomienie Putkina. Brak właściciela lub własny PID po
reloadzie pozwala uruchomić obserwatora, a po jego gotowości — serwer.
Osobny odczyt PID i unikalnej nazwy potwierdza rejestrację. Start ma limit
5 s, odczyty D-Bus po 2 s. Błąd magistrali lub obserwatora wymaga restartu
procesu; stare powiadomienia wygasają, nowe nie zostają zatrzymane.

Natywny serwer ogłasza dokładnie `body`, `actions`, `icon-static`.
Nie ogłasza persistence, markup, hyperlink, body-images, action-icons
ani inline-reply. Informacja o serwerze pochodzi z Quickshell i podaje
protokół **1.2**. [NotificationServer 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationServer/),
[protokół 1.2](https://specifications.freedesktop.org/notification/1.2/protocol.html).

Źródła tagu 0.3.1 i test wykazały, że `expireTimeout` zawiera **milisekundy**,
choć opis typu mówi o sekundach. Zastąpienie nie emituje ponownie
`notification`, a `NotificationAction::setText` pomija zmienioną etykietę.
[Notification](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/Notification/),
[implementacja właściwości i akcji](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/notifications/notification.cpp),
[implementacja serwera](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/services/notifications/server.cpp).

`services/notification-watch.py` uzupełnia te dwie luki jednym pasywnym
połączeniem `BecomeMonitor`. Obserwuje tylko `Notify` i zmianę właściciela
nazwy, nie rejestruje serwera i nie wywołuje akcji. Do QML przekazuje ID,
cel, timeout i ograniczone etykiety zastąpienia. Obrazy dekoduje jako
`ByteArray`, nie listę milionów liczb; nie wysyła body, tytułów, aplikacji
ani obrazów przez stdout. Diagnostyka jest stała, bez danych nadawcy.
Brak pollingu i zapisu plików. Sprawdzono lokalne docstringi API 1.4.0;
publiczna [dokumentacja dbus-python](https://dbus.freedesktop.org/doc/dbus-python/dbus.lowlevel.html)
jest oznaczona 1.3.2 i opisuje te same metody.
[BecomeMonitor](https://dbus.freedesktop.org/doc/dbus-specification.html#bus-messages-become-monitor),
[ograniczenie obrazów Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-image.html).

Preflight nie jest atomowy z natywnym `RequestName`. Quickshell nie zastępuje
obcego właściciela, lecz jego singleton próbuje rejestracji po zwolnieniu
nazwy. Dlatego nie uruchamiaj konkurujących autostartów naraz. Usunięcie
komponentu QML **nie kończy natywnego serwera**; do zwolnienia nazwy podczas
migracji trzeba zakończyć proces Putkin. Test wykazał, że przy nazwie zajętej
już podczas preflight komponent nie powstaje i nie przejmuje nazwy nawet
po późniejszym odejściu właściciela.

## Późniejsze przełączenie i rollback

To instrukcja do etapu instalacji, **nie wykonana aktywacja**. Nie zatrzymano
mako, dunst, SwayNC ani starego shella; nie zmieniono autostartu hosta.

1. Zapisz bieżący autostart i ustal właściciela oraz PID:

   ```sh
   busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications
   busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.Notifications
   ```

2. Przy planowanym przełączeniu wyłącz dokładnie ustalony autostart/aktywację
   poprzedniego serwera i zakończ go jego normalną metodą. Jeśli należy do
   starego shella, zakończ tamten proces zgodnie z planem migracji. Zachowaj
   sposób jego przywrócenia. Nie zabijaj procesów po szerokim wzorcu nazwy.
3. Przed startem jednej instancji docelowego Putkin sprawdź
   `NameHasOwner s org.freedesktop.Notifications`: musi zwrócić `false`.
   Gdy inny serwer uruchamia się ponownie, najpierw popraw jego autostart.
4. Po starcie sprawdź zgodność PID właściciela z tą instancją Putkin,
   capabilities, powiadomienie testowe, DND, akcje i fokus na docelowym
   Waylandzie. Sam start procesu nie jest odbiorem fokusu.
5. **Rollback:** zakończ proces Putkin, potwierdź zwolnienie nazwy, przywróć
   autostart/aktywację i jedną instancję poprzedniego serwera. Sprawdź jego
   PID i nowe powiadomienie. Treści z procesu Putkin nie można odtworzyć,
   ponieważ historia żyje wyłącznie w pamięci procesu. Nie uruchamiaj obu serwerów równocześnie.

Weryfikacja: [testy](testing.md#15-powiadomienia--etap-09),
[IPC](ipc.md#powiadomienia), [status](status.md), [dowody](evidence/09-notifications.md).
