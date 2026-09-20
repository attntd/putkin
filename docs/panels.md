# Panele i fokus — etap 02

## Moduły sieci i centrum — 2026-09-19

Koordynator udostępnia także `network`, `bluetooth` i `notifications`.
Ikony Wi-Fi i Bluetooth w pasku otwierają własne moduły zarządzania;
Quick Menu zawiera wyłącznie dwa kafelki on/off. Escape zamyka moduł,
a w formularzu Wi-Fi najpierw anuluje oczekujące połączenie.
Centrum jest dostępne z dzwonka w pasku i skrótu powiadomień.
Pozostaje dostępne także bez wpisów.
Wszystkie trzy panele dzielą monitor, wyłączność, grab, scroll i politykę
mysz/klawiatura z PanelHost. DND ma przełączniki w centrum i Quick Menu.

Cała powierzchnia panelu wyznacza wspólny gradient akcentów od lewego
górnego do prawego dolnego rogu, również dla kontrolek i kart wewnątrz.
Fokus pola tekstowego koloruje wyłącznie jego istniejącą ramkę.

Przy znikaniu biernego toastu/OSD Hyprland 0.56.2 potrafi oddać fokus
aplikacji mimo wciąż otwartego panelu. Odnowienie `HyprlandFocusGrab`
rozdziela usunięcie i utworzenie uchwytu jednorazowym timerem 16 ms;
dwa `Qt.callLater` potrafią wysłać obie operacje w tej samej partii.
Timer działa wyłącznie po utracie fokusu interaktywnego panelu, bez
odpytywania w spoczynku. Kliknięcie poza panelem nadal go zamyka.
Sprawdzono lokalne Quickshell 0.3.1, Qt 6.11.2 oraz oficjalne API:
[HyprlandFocusGrab](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandFocusGrab/),
[Timer](https://doc.qt.io/qt-6.11/qml-qtqml-timer.html).

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade 200 ms;
opcja ograniczania ruchu została usunięta. Kontrakty adapterów pozostają.


Quickshell 0.3.1, Qt 6.11.2. Powierzchnia `quickSettings` pokazuje opis
aktualnego motywu, od etapu 04 audio, od 05 jasność i od 06 baterię, a `settings` od etapu 03 udostępnia
[edytor wyglądu i zapis](settings.md). Nie ma atrap urządzeń ani przycisków
przyszłych usług.

## Własność i akcje

Rozszerzenie 2026-09-17: `audio` jest osobnym panelem tego koordynatora,
otwieranym z ikony głośnika i IPC `ui openAudio/toggleAudio`. Pokazuje
oba suwaki i obie listy urządzeń bez zwijania. Escape zamyka go od razu;
brak urządzeń nie odbiera możliwości zamknięcia. Pozostałe reguły monitora,
wyłączności, zniszczenia, graba i powrotu fokusu pozostają wspólne.
Launcher ma osobne wejścia IPC do schowka i komend, korzystające z tej
samej sesji `launcher`. [Audio](audio.md), [launcher](launcher.md).

`PanelCoordinator` otrzymuje jawnie `screens`, `monitorService`, `barFocus`
oraz od etapu 03 `settings`.
Przechowuje jedną sesję: identyfikator, konkretny obiekt ekranu, element
wywołujący i informację, czy wrócić do nawigacji paska. Rozwinięcie opisu
motywu należy do `QuickSettingsView`; koordynator go nie przechowuje.

| Akcja QML | Wynik i zachowanie |
| --- | --- |
| `open(id, screen, invoker, reason?)` | `bool`; otwiera lub zastępuje panel. `null` jako ekran wybiera skupiony monitor Hyprlanda, następnie pierwszy dostępny ekran Qt. Opcjonalny powód fokusu służy przejściom wewnątrz paneli; domyślnie pochodzi z kontrolki wywołującej, a przy IPC z klawiatury. |
| `toggle(id, screen, invoker)` | `bool`; zamyka tę samą powierzchnię na tym samym ekranie albo wywołuje `open`. |
| `openTray(item, screen, invoker, reason?)` | Otwiera natywne menu wskazanego klienta SNI, jeśli je udostępnia, z zachowaniem powodu fokusu. `trayOverflow` otwiera się przez zwykłe `open`/`toggle`. |
| `close(restoreFocus)` | Zamyka sesję; argument określa powrót do paska. |

Nieznane ID daje `lastError = "unknown-surface"`, brak ekranu
`screen-unavailable`, a ekran bez miejsca poniżej paska `screen-too-small`.
Nieudane otwarcie nie zmienia istniejącej sesji. IPC udostępnia tylko
nazwane, dozwolone akcje — [sygnatury](ipc.md).

## Okno i czas życia

Jeden `PanelHost` otrzymuje koordynator i loader. Produkcja przekazuje
`Quickshell.LazyLoader` z `InteractivePanelWindow`; używa `activeAsync`.
Odczyt `item` następuje wyłącznie po `active`, dzięki czemu nie wymusza
synchronicznego kończenia ładowania. [API LazyLoader 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/LazyLoader/).

Okno jest `PanelWindow`, warstwa `Overlay`, bez rezerwowania obszaru.
Panel ma 360 px lub szerokość monitora minus 16 px; wysokość jest ograniczona
do wysokości monitora minus pasek 32 px i dwa odstępy po 8 px. Przy prawym
brzegu zostaje 8 px, panel zaczyna się 8 px poniżej paska. `ScrollView`
przewija dłuższy opis, a zmiany rozmiaru i fokusu odsłaniają wybraną kontrolkę
wraz z obrysem. Powierzchnia panelu jest nieprzezroczysta.

Okno ma przezroczysty obszar nad panelem i po prawej. Maska wejścia obejmuje
wyłącznie panel. To również omija nierozwiązywalny przez lokalny qmllint
typ wartości `Margins` w metadanych Quickshell 0.3.1; nie wyłączamy przez to
diagnostyki importów. Lokalny wyjątek `uncreatable-type` przy fabryce
`PanelWindow` jest taki sam jak w pasku etapu 01.
[PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
[maska QsWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/).

Zamknięcie od razu ustawia `interactive = false`: kontrolki są wyłączone,
maska wejścia staje się pusta, fokus layer-shell zmienia się na `None`,
a grab jest zwalniany. Po fade 200 ms loader niszczy okno.
Opcja ograniczenia ruchu została usunięta; dawna wartość w pliku jest ignorowana. Prace przyszłych
widoków zależne od widoczności należy wiązać z `host.interactive`, nie
z samym istnieniem załadowanego obiektu. Aktualne widoki nie mają takich
zadań ani okresowych timerów. Od etapu 05 `PanelHost` wywołuje jawne
`brightness.refresh()` przy otwarciu sesji Quick Settings, również podczas
fade. Sam widok nie zarządza procesem ani pollingiem.

Ponowne otwarcie na tym samym monitorze podczas fade anuluje usunięcie
i wykorzystuje okno ponownie. Zmiana strony niszczy poprzedni podwidok;
zmiana monitora najpierw wyłącza i usuwa poprzednie okno. Nie ma dwóch
interaktywnych paneli. Usunięcie ekranu zamyka sesję bez przywracania fokusu
na nieistniejącym monitorze. Spóźnione zdarzenie natywnego okna sprawdza
tożsamość bieżącego obiektu przed zamknięciem. OSD/toasty nie używają tego
koordynatora; OSD od etapu 04 ma osobny host, toasty pozostają dalszym etapem.

## Polityka wejścia

Produkcyjne okno używa natywnego `HyprlandFocusGrab` z panelem na liście
dozwolonych okien i trybu layer-shell `OnDemand`. Grab nadaje i utrzymuje
fokus klawiatury. `Exclusive` nie jest łączone z grabem: w Hyprlandzie
0.56.2 kierowało kliknięcia spoza panelu z powrotem do jego powierzchni,
uniemożliwiając zamknięcie. Odbiór etapu 12 wykrył tę regresję i potwierdził
naprawę rzeczywistym wirtualnym wskaźnikiem w prywatnym Waylandzie.
Klik lub dotyk poza nim powoduje `cleared` i
`close(false)`. Putkin nie odtwarza kliknięcia ani nie stawia pełnoekranowej
warstwy przechwytującej pulpit. Dostarczenie tego samego kliknięcia do okna
pod spodem pozostaje decyzją Hyprlanda; nie obiecujemy jego pochłonięcia.
Dotyczy to także kliknięcia w pasek i drugi monitor. Jest to polityka
natywnego graba; wynik kliknięcia i powrotu klawiatury do osobnego procesu
opisuje [odbiór etapu 12](validation.md). Dotyku nie testowano.
[API graba](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandFocusGrab/),
[protokół](https://github.com/hyprwm/hyprland-protocols/blob/main/protocols/hyprland-focus-grab-v1.xml).

Testowa scena zastępuje grab jawnym `MouseArea`, które pochłania zdarzenie
poza panelem. Test tego elementu potwierdza zamknięcie i decyzję o fokusie,
nie dostarczenie zdarzenia przez prawdziwego Hyprlanda.

Otwarcie myszą lub IPC ustawia logiczny fokus na pierwszej dostępnej kontroli audio,
następnie jasności/jej diagnostyce, a w ustawieniach
na „Wstecz”. Od korekty 2026-09-19 otwarcie myszą nie rysuje ramki;
powód wejścia jest przekazywany przez koordynator, strony i podmenu.
Pierwszy klawisz przywraca obrys także na tej samej kontrolce.
Powrót aktywności okna zachowuje ostatni sposób wejścia.
`h/l` obsługują poziomy rząd, `j/k` przejście między rzędami.
Wyłączone kontrolki są pomijane. Enter i Enter numeryczny wywołują
standardowe `AbstractButton.click()` raz; autorepeat jest pomijany.
Tab/Shift+Tab pozostają w aktywnym panelu, strzałki i Spacja działają przez
kontrolki Qt. Litery są obsługiwane wyłącznie przez przyciski — pole tekstowe
zachowuje wpisywanie `hjkl`. [AbstractButton Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-controls-abstractbutton.html).

Escape zwija rozwiniętą listę audio, szczegóły jasności lub opis motywu,
a następnie zamyka panel. Jeśli wejście
nastąpiło podczas nawigacji paska, Escape, klawiaturowe „Zamknij” i `ui closePanels`
oddają fokus elementowi wywołującemu (fallback: przycisk Quick Settings).
Po zwykłym wejściu myszą/IPC klawiatura wraca do kompozytora. Kliknięcie
poza panelem, usunięcie monitora i jawne `bar focus` nie odtwarzają starego
fokusu paska. Zamknięcie przyciskiem myszy również nie wznawia nawigacji
paska. `bar focus` zamyka panel przed rozpoczęciem nawigacji.

Przycisk paska pokazuje aktywność pełnym akcentem i ma tooltip. Produkcyjny
pasek używa `Popup.Window`, aby tooltip mógł wyjść poza wysokość 32 px;
duża scena testowa używa `Popup.Item` z tą samą treścią i stylem.
[Popup Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-controls-popup.html#popup-type).
Natywne tooltipy również wymagają odbioru Waylanda.

## Rozszerzenie etapu 06

Menu traya i overflow są pełnoprawnymi sesjami tego samego koordynatora.
Przechowuje on klienta, pozycję prawej krawędzi przycisku i powrót do
listy overflow; stos podmenu należy do `TrayView`. Podmenu pozostaje
wewnątrz jednego okna, graba i maski. Zamyka się według tych samych zasad.

Quick Settings/Wygląd pozostają przy prawym brzegu monitora. Rodzina menu
traya kotwiczy się przy wywołującym przycisku; `PanelHost.surfaceX` ogranicza
pozycję do obu brzegów monitora. Zmiana rozmiaru przelicza ograniczenie.
Usunięcie klienta zamyka menu, usunięcie podmenu cofa do rodzica;
wybrany usunięty element ma dostępny fallback fokusu. Inne interaktywne
panele, w tym podgląd akcentów, są zastępowane i zwalniane.
Szczegóły klawiatury i protokołu: [bateria/tray](battery-tray.md).
