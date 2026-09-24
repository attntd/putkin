# Środowisko i rozwój

## Odczyt, przewijanie i wzmianki — 2026-09-24

Ponownie sprawdzono `qmake6 -query QT_VERSION`: **6.11.2** oraz
`qs --version`: **0.3.1**. Zweryfikowano oficjalną dokumentację Qt 6.11:
[ScrollBar](https://doc.qt.io/qt-6.11/qml-qtquick-controls-scrollbar.html),
[Popup](https://doc.qt.io/qt-6.11/qml-qtquick-controls-popup.html),
[TextEdit](https://doc.qt.io/qt-6.11/qml-qtquick-textedit.html)
i [ListView](https://doc.qt.io/qt-6.11/qml-qtquick-listview.html).
Popup zachowuje fokus edytora; lista korzysta z currentIndex i
positionViewAtIndex. Widoczność suwaka reaguje na position/pressed,
ponieważ lokalny Qt ustawia active także przy hover. Signal zachowuje
dotychczasowe API sendReceipt; rozszerzenie dotyczy prywatnego bridge.

## Pasek i karty powiadomień — 2026-09-23

Ponowna weryfikacja korekty dolnych akcji: Qt **6.11.2** i Quickshell
**0.3.1**. Dokumentacja Repeatera poniżej opisuje różnicę między `count`
i gotowymi delegatami oraz sygnały `itemAdded`/`itemRemoved`. Sonda testowa
korzysta z oficjalnego [Variants.instances 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/)
i istniejącego okna powiadomień, bez produkcyjnego interfejsu diagnostycznego.

Potwierdzono lokalnie Qt **6.11.2** (`qmake6 -query QT_VERSION`) i Quickshell
**0.3.1** (`qs --version`). Sprawdzono oficjalne API:
[Keys i propagacja zdarzeń](https://doc.qt.io/qt-6.11/qml-qtquick-keys.html),
[Repeater i życie delegatów](https://doc.qt.io/qt-6.11/qml-qtquick-repeater.html),
[Text: elide i maximumLineCount](https://doc.qt.io/qt-6.11/qml-qtquick-text.html),
[HyprlandFocusGrab](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandFocusGrab/)
i [NotificationAction](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationAction/).
Testy klawiatury nie interpretują kodu źródłowego: wysyłają zdarzenia Qt
lub wtype do prywatnego Hyprlanda. W teście wtype `resolve_binds_by_sym`
musi być włączone tak jak w pozostałych testach natywnej klawiatury.

## Sterowanie Message Hubem — 2026-09-23

Lokalnie ponownie potwierdzono `qmake6 -query QT_VERSION`: **6.11.2**
i `qs --version`: **0.3.1**. Sprawdzono oficjalne API Qt 6.11:
[Keys](https://doc.qt.io/qt-6.11/qml-qtquick-keys.html),
[Flickable](https://doc.qt.io/qt-6.11/qml-qtquick-flickable.html),
[WheelHandler](https://doc.qt.io/qt-6.11/qml-qtquick-wheelhandler.html),
[WheelEvent](https://doc.qt.io/qt-6.11/qml-qtquick-wheelevent.html),
[QWheelEvent](https://doc.qt.io/qt-6.11/qwheelevent.html),
[ScrollView](https://doc.qt.io/qt-6.11/qml-qtquick-controls-scrollview.html)
i [QtTest](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html).

Źródło [QQuickFlickable 6.11.2](https://github.com/qt/qtdeclarative/blob/v6.11.2/src/quick/items/qquickflickable.cpp)
potwierdza, że ScrollEnd kończy gest bez generowania własnej bezwładności.
QML WheelEvent nie udostępnia fazy; `WheelHandler.active` uwzględnia
ScrollEnd. Komponent obserwuje gest bez przejmowania zdarzeń i uruchamia
`flick()` po obsłużeniu końca przez Qt. Prędkość pochodzi z ostatnich
niezerowych delt pikselowych; zwykłe zdarzenia kółka nie tworzą tej bezwładności.
Test C++ jest wyłącznie narzędziem wejścia, nie zależnością runtime.

## Fade na obrazie pulpitu — 2026-09-23

Potwierdzono lokalne Quickshell **0.3.1**, Qt **6.11.2** i Hyprland **0.56.2**.
Sprawdzono metadane zainstalowanego ScreencopyView oraz oficjalne
[ScreencopyView](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ScreencopyView/),
[WlSessionLockSurface](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLockSurface/)
i [TextInput.cursorDelegate](https://doc.qt.io/qt-6.11/qml-qtquick-textinput.html#cursorDelegate-prop).
Związek przechwytywania z oknem/scene graph sprawdzono w
[kodzie 0.3.1](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/wayland/screencopy/view.cpp).
Hyprland przestaje renderować pulpit po potwierdzeniu blokady; samo
zmniejszenie opacity widoku odsłania kolor powierzchni. Rozwiązanie używa
jednej klatki sprzed blokady i nie włącza `session_lock_xray`.
[Kod renderera 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/render/Renderer.cpp).

Piksele przejścia sprawdza bezstratne nagranie prywatnego kompozytora przez
wf-recorder **0.6.0**, dekodowane ffmpeg **9.0.1**. Opcje zweryfikowano
w lokalnym oficjalnym `wf-recorder(1)`, `--help` i dokumentacji FFmpeg.

## Odcisk i przejścia blokady — 2026-09-23

Ponownie potwierdzono Quickshell **0.3.1**, Qt **6.11.2**, fprintd **1.94.5**,
Linux-PAM **1.7.2**, systemd **261.3** i Hyprland **0.56.2**. Lokalny oficjalny
`pam_fprintd(8)` dokumentuje ujemny timeout jako oczekiwanie bez limitu czasu;
`max-tries=3` pozostaje bez zmian. Interfejs atrapy odpowiada zainstalowanym
`/usr/share/dbus-1/interfaces/net.reactivated.Fprint.{Manager,Device}.xml`.
Sprawdzono też [PamContext](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pam/PamContext/),
[WlSessionLock](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLock/),
[padding Qt Controls](https://doc.qt.io/qt-6.11/qml-qtquick-controls-control.html),
[NumberAnimation](https://doc.qt.io/qt-6.11/qml-qtquick-numberanimation.html)
i [Can* logind 261](https://github.com/systemd/systemd/blob/v261/man/org.freedesktop.login1.xml).
Odczyt hosta: CanSuspend=`yes`, CanSuspendThenHibernate=`na`; bez wywołania snu.

## Chip i kategorie komend — 2026-09-22

Potwierdzono Qt **6.11.2** i Quickshell **0.3.1**. Parser i metadane
korzystają z udokumentowanego [środowiska JavaScript QML](https://doc.qt.io/qt-6.11/qtqml-javascript-hostenvironment.html).
Podpis kategorii zachowuje istniejący [Layout](https://doc.qt.io/qt-6.11/qml-qtquick-layouts-layout.html).
Wejście i fokus sprawdzono przez [QtTest](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html)
oraz rzeczywiste Super+Spacja i wpisywanie przez wtype w prywatnym Hyprlandzie.

## Centrowanie i przewijanie launchera — 2026-09-22

Ponownie potwierdzono Qt **6.11.2** i Quickshell **0.3.1**. Sprawdzono
oficjalne [ListView](https://doc.qt.io/qt-6.11/qml-qtquick-listview.html),
[ScrollBar](https://doc.qt.io/qt-6.11/qml-qtquick-controls-scrollbar.html),
[stylowanie suwaka](https://doc.qt.io/qt-6.11/qtquickcontrols-customize.html#customizing-scrollbar)
oraz [warstwy Item](https://doc.qt.io/qt-6/qml-qtquick-item.html#layer.enabled-prop).
Pasywny [TapHandler](https://doc.qt.io/qt-6/qml-qtquick-taphandler.html)
utrzymuje nawigację podglądu po kliknięciu przewijanej treści.
Suwak jest podpięty do rzeczywistego Flickable/ListView; zachowuje natywną
obsługę myszy i rozmiar uchwytu. `FadeSwap` używa istniejącego przygotowania
klatek i zatrzymuje pracę po ustaleniu zawartości. Nie animuje wymiarów okna.
Testy wejścia używają API [QtTest](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html),
prywatnych XDG/D-Bus i atrap; odbiór GPU działa w prywatnym Hyprlandzie.

## Czysta instalacja — 2026-09-22

Ponownie potwierdzono Python **3.14.7** i systemd **261.3**. Kopie drzew
używają udokumentowanych `copytree(..., symlinks=True)` i `copy2` z
[Python 3.14](https://docs.python.org/3.14/library/shutil.html).
Semantykę masek `/dev/null` i `daemon-reload` sprawdzono w oficjalnych
lokalnych podręcznikach `systemd.unit(5)` i `systemctl(1)` tej wersji.
`systemctl --user show` nieistniejącej jednostki zwrócił `inactive`, exit 0;
wykonano wyłącznie ten odczyt, bez zmian usług hosta.
Wyłączenie systemowego wpisu autostartu przez użytkownika opiera się na
[`Hidden=true` w specyfikacji XDG](https://specifications.freedesktop.org/autostart/latest/).
Realne operacje na plikach testowano w prywatnym prefiksie, a zachowanie
usług i odmowę przy aktywnym pulpicie przez kontrolowane atrapy poleceń.

## Instalacja na kolejnej maszynie — 2026-09-22

Lokalnie potwierdzono: Python **3.14.7**, Quickshell **0.3.1**, Qt **6.11.2**,
Hyprland **0.56.2**, UWSM **0.27.0**, bubblewrap **0.12.0**, Yazi **26.9.1**,
Neovim **0.12.5**, Zen **1.22.2b**, Kitty **0.48.2**, Fish **4.9.3**.
Instalator wymaga Python ≥3.12, a podane wersje Qt/Quickshell/Hyprlanda
stanowią sprawdzane minimum. Qt jest wykrywane przez `qmake6`, aby obecność
Qt 5 w PATH nie dawała fałszywego wyniku. UWSM jest sprawdzany lokalnym CLI.

Sprawdzono oficjalne, zgodne wersjami źródła i dokumentację:
[Hyprland 0.56.2 — Lua](https://github.com/hyprwm/Hyprland/blob/v0.56.2/example/hyprland.lua),
[Quickshell 0.3.1 — konfiguracje](https://quickshell.org/docs/v0.3.1/guide/introduction/),
[Qt 6.11 — tworzenie Component](https://doc.qt.io/qt-6.11/qtqml-javascript-dynamicobjectcreation.html),
[Python 3.14 — filtr tar](https://docs.python.org/3.14/library/tarfile.html),
[ConfigParser](https://docs.python.org/3.14/library/configparser.html),
[XDG](https://specifications.freedesktop.org/basedir/latest/),
[profile Zen](https://docs.zen-browser.app/guides/manage-profiles).
Użyto także lokalnych stubs Hyprlanda, `Hyprland --help`, `quickshell --help`
i dokumentacji/implementacji UWSM 0.27.0 w `/usr/share`.

Signal jest odtwarzany z [upstream 0.14.8](https://raw.githubusercontent.com/AsamK/signal-cli/v0.14.8/README.md)
i przypiętego Temurina 25.0.4.1+1. Sprawdzono oficjalną sumę JDK,
sumy źródeł i archiwów, a rzeczywisty build zachował wcześniejszy pin całego
runtime. Listy pakietów są w `config/packages/`; opcja instalacji pakietów
jest osobna od zwykłego instalowania plików. Po aktualizacji pakietów
instalator wznawia pracę w nowym interpreterze Pythona.

## Wspólny launcher i shell — 2026-09-21

Potwierdzono lokalnie Qt **6.11.2** i Quickshell **0.3.1**. Opisy wyników
launchera korzystają z `RowLayout`, preferowanej i maksymalnej szerokości
oraz skracania tekstu. Sprawdzono [Layout](https://doc.qt.io/qt-6.11/qml-qtquick-layouts-layout.html)
i [Text](https://doc.qt.io/qt-6.11/qml-qtquick-text.html) dla tej wersji Qt.
Podglądy obejmują aplikacje przy 1366×768 i ścieżkę pliku przy 320×480.
Wspólny `DismissKeys` zachowuje wpisywanie `q` w TextInput/TextEdit,
także w nowych oknach uwierzytelniania.

## Okna uwierzytelniania — 2026-09-20

Sprawdzono Quickshell 0.3.1, Qt 6.11.2, Polkit 127, OpenSSH 10.5p1,
Pinentry 1.3.3, GnuPG 2.4.9 i fprintd 1.94.5. Moduł Services.Polkit
udostępnia natywny agent; nie dodano pluginu C++ ani dodatkowego demona.
Pomocniki SSH/Pinentry używają standardowej biblioteki Python 3.14,
prywatnych gniazd Unix i SO_PEERCRED. Widoki otrzymują zależności jawnie.

W qmltypes 0.3.1 typ flow pomija przestrzeń nazw C++, a sygnał Socket.error
nie opisuje LocalSocketError. Adapter czyta natywne flow przez wariant
i łączy sygnał błędu przez connect; nie wyłącza kontroli importów.
Obie ścieżki przetestowano na prawdziwym Quickshell/libpolkit.
[Oficjalne API i kontrakt](authentication.md), [izolacja testów](testing.md#okna-uwierzytelniania--2026-09-20).

Przy korekcie odliczania ponownie potwierdzono Qt 6.11.2 i Quickshell 0.3.1.
Sprawdzono [FileView.text / watchChanges](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/)
oraz [NumberAnimation](https://doc.qt.io/qt-6/qml-qtquick-numberanimation.html).
Lokalny `pam_fprintd(8)` opisuje domyślny timeout 30 s; odczyt
`/etc/pam.d/polkit-1` potwierdził jawne `max-tries=1 timeout=30`.

## Interakcje powiadomień — 2026-09-20

Przed zmianą potwierdzono lokalnie `qmake6 -query QT_VERSION`: **6.11.2**
i `qs --version`: **0.3.1**. Sprawdzono oficjalne API Qt 6.11:
[Text.truncated / maximumLineCount](https://doc.qt.io/qt-6.11/qml-qtquick-text.html),
[ScrollView](https://doc.qt.io/qt-6.11/qml-qtquick-controls-scrollview.html),
[Control.wheelEnabled](https://doc.qt.io/qt-6.11/qml-qtquick-controls-control.html#wheelEnabled-prop),
[Flickable.interactive](https://doc.qt.io/qt-6.11/qml-qtquick-flickable.html#interactive-prop),
[AbstractButton](https://doc.qt.io/qt-6.11/qml-qtquick-controls-abstractbutton.html)
i [ShapePath.strokeWidth](https://doc.qt.io/qt-6.11/qml-qtquick-shapes-shapepath.html#strokeWidth-prop).
Wspólny `Glyph` przyjmuje opcjonalną szerokość obrysu w pikselach widoku;
domyślne ikony pozostają bez obrysu. Karty centrum wyłączają własną obsługę
kółka i gestu przewijania, przekazując je otaczającemu panelowi.

## Fade — 2026-09-20

Lokalne `qs --version`, `qmake -query QT_VERSION` i qmltypes potwierdzają
Quickshell **0.3.1** oraz Qt **6.11.2**. Przed zmianą sprawdzono oficjalne
API [warstw i przezroczystości Item](https://doc.qt.io/qt-6/qml-qtquick-item.html#layer-opacity-vs-item-opacity),
[FrameAnimation](https://doc.qt.io/qt-6.11/qml-qtquick-frameanimation.html),
[Window](https://doc.qt.io/qt-6.11/qml-qtquick-window.html),
[NumberAnimation](https://doc.qt.io/qt-6.11/qml-qtquick-numberanimation.html)
i [QtTest](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html).
Warstwa składa poddrzewo przed zastosowaniem jego opacity, co eliminuje
przebijanie nakładających się teł. Jest utrzymywana przez czas widoczności
powierzchni i zwalniana po zamknięciu. Przygotowanie klatkowe działa tylko
podczas otwierania; po ustabilizowaniu geometrii kończy pracę.

## Domyślna instalacja — 2026-09-20

Sprawdzono Quickshell **0.3.1-1**, UWSM **0.27.0-1**, Python **3.14.7**,
Qt **6.11.2**, Hyprland **0.56.2-3** i chezmoi **2.72.2**. Wykrywanie
konfiguracji potwierdza `qs --help` i
[dokumentacja Quickshell 0.3.1](https://quickshell.org/docs/v0.3.1/guide/introduction/#config-files).
Usługę bez daemonizacji, slice i dziedziczenie środowiska sprawdzono w
zainstalowanych `uwsm app --help`, `/usr/share/doc/uwsm/README.md`
i `/usr/share/uwsm/modules/uwsm/main.py` (0.27.0).
Operacje publikacji odpowiadają
[os.replace w Pythonie 3.14](https://docs.python.org/3.14/library/os.html#os.replace).

Instalator wymaga quickshell, uwsm, hyprctl, busctl, gdbus, systemctl,
Python oraz modułów dbus i gi. Narzędzia QML są sprawdzane przez
`scripts/check`. brightnessctl, hyprsunset, wl-clipboard, cliphist, fd
i file są raportowane osobno jako zależności poszczególnych funkcji.
Nie instaluje pakietów ani nie wykonuje aktualizacji systemu.
Szczegóły: [instalacja](install.md#domyślne-qs-uwsm-i-pięć-buildów--2026-09-20).

## Screenshot — 2026-09-20

Sprawdzone lokalnie: Quickshell **0.3.1**, Qt **6.11.2**, Hyprland
**0.56.2-3**, grim **1.5.0-2**, wl-clipboard **2.3.0-1**, Python **3.14.7**.
Adapter używa zainstalowanych grim, wl-copy, hyprctl oraz biblioteki
standardowej Pythona. Brak grim/clipboard zgłasza błąd; wybór zakresu nie
uruchamia tych narzędzi. `grim -o` i `-g` są rozłączne: pełny monitor używa
`-o`, wycinek/okno używają `-g`, w obu przypadkach z jawną skalą i PNG level 1.

Przed implementacją sprawdzono lokalne qmltypes, `man grim`,
`man wl-clipboard`, `hl.meta.lua` oraz oficjalne API wersji:
[PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
[QsWindow.backingWindowVisible](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/),
[FloatingWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/),
[Process](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/),
[MouseArea](https://doc.qt.io/qt-6.11/qml-qtquick-mousearea.html),
[StandardPaths](https://doc.qt.io/qt-6.11/qml-qtcore-standardpaths.html),
[wl-clipboard 2.3.0](https://github.com/bugaevc/wl-clipboard/blob/v2.3.0/data/wl-clipboard.1),
[TemporaryDirectory](https://docs.python.org/3.14/library/tempfile.html),
[subprocess](https://docs.python.org/3.14/library/subprocess.html).
PNG tymczasowy trafia do prywatnego XDG_RUNTIME_DIR. Docelowy katalog obrazów
wyznacza Qt StandardPaths zgodnie z XDG; w nim powstaje `Screenshots`.

Reguła nakładki używa `hl.layer_rule` ze stałym `name="putkin-screenshot"`.
W Hyprlandzie 0.56.2 ponowne wywołanie aktualizuje tę samą nazwaną regułę;
reload kompozytora usuwa reguły, więc adapter odtwarza ją po `configreloaded`.
Uchwyt `HL.LayerRule` udostępnia `set_enabled` i `is_enabled`, bez `remove`.
Sprawdzono zainstalowane `/usr/share/hypr/stubs/hl.meta.lua` i źródła wersji:
[rejestracja reguły](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/bindings/LuaBindingsConfigRules.cpp#L1182),
[uchwyt](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/objects/LuaLayerRule.cpp#L53),
[reload konfiguracji](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/lua/ConfigManager.cpp#L647).
Test natywny sprawdza również oba tryby
[Quickshell.reload](https://quickshell.org/docs/v0.3.1/types/Quickshell/Quickshell/#func.reload).

## Natywna sesja — migracja 2026-09-20

Runtime wymaga Quickshell 0.3.1 z modułami Wayland i Services.Pam, Qt 6.11.2,
Hyprlanda 0.56.2 (Lua), Linux-PAM, systemd 261.3, python-dbus i python-gobject.
Odcisk jest opcjonalny i korzysta z pam_fprintd/fprintd. Hasło obejmuje
systemowy stos `system-auth` z absolutnego include w pliku PAM wydania,
z pam_shells i pam_nologin. Osobna rozmowa obsługuje odcisk. Hyprlock i Hypridle są
wycofane z runtime. Starsze sekcje poniżej dokumentują środowisko danych etapów.
Oficjalne API, cykl życia i granice restartu: [sesja](session.md).
Test `scripts/test-wayland --nested --native-session` maskuje hostowy PAM
i używa wyłącznie kompilowanej atrapy, prywatnego Waylanda i login1.


Ikony Material Symbols sprawdzono 2026-09-20: Quickshell **0.3.1-1**,
Qt Base **6.11.2-3**, Qt Declarative **6.11.2-2**, Qt SVG **6.11.2-1**.
Przed implementacją potwierdzono lokalne qmltypes i oficjalne API Qt 6.11:
[Shape](https://doc.qt.io/qt-6.11/qml-qtquick-shapes-shape.html),
[ShapePath](https://doc.qt.io/qt-6.11/qml-qtquick-shapes-shapepath.html),
[PathSvg](https://doc.qt.io/qt-6.11/qml-qtquick-pathsvg.html).
Przy korekcie topbara potwierdzono te same wersje oraz
[Text.color](https://doc.qt.io/qt-6.11/qml-qtquick-text.html#color-prop):
Clock i ikony paska korzystają z tego samego `Theme.text`.
Przed korektą centrowania ponownie potwierdzono Qt **6.11.2** oraz
[FontMetrics.tightBoundingRect](https://doc.qt.io/qt-6.11/qml-qtquick-fontmetrics.html#tightBoundingRect-method),
[Text](https://doc.qt.io/qt-6.11/qml-qtquick-text.html) i
[Control.contentItem](https://doc.qt.io/qt-6.11/qml-qtquick-controls-control.html#contentItem-prop).
Położenie znaków uwzględnia obrys względem baseline, a dodatkowy Item
oddziela je od geometrii contentItem zarządzanej przez kontrolkę.
Renderer korzysta z CurveRenderer na GPU i natywnego QPainter w software.
Uwzględnia viewBox SVG (także ujemne Y), bez pośredniej bitmapy i Canvas.
Przy poszerzeniu ikony ładowania potwierdzono Quickshell **0.3.1**, Qt
**6.11.2**, lokalne qmltypes `Item.scale` / `implicitWidth` oraz powyższe
API Shape/PathSvg. Jednorodne skalowanie dopasowuje wysokość viewportu,
a implicitWidth przenosi potrzebną szerokość do przycisku i Row paska.

Przed korektą Signala sprawdzono Signal Desktop **8.27.0-1**, Quickshell
**0.3.1-1**, Qt Base **6.11.2-3**, lokalne qmltypes i oficjalne API
[SystemTrayItem](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.SystemTray/SystemTrayItem/),
[Status](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.SystemTray/Status/),
[Canvas](https://doc.qt.io/qt-6.11/qml-qtquick-canvas.html) oraz
[Context2D](https://doc.qt.io/qt-6.11/qml-qtquick-context2d.html).
Zainstalowany SystemTrayService przekazuje liczbę nieprzeczytanych do
wariantu PNG tray-icons/alert, zachowując status Active. Ma cztery rozmiary
16/32/48/256 i liczniki 1–9/9+. Czytnik w Canvas odracza ładowanie przez
Qt.callLater i próbkuje w onPaint, aby nie wchodzić ponownie do renderera
z sygnału ładowania. Oryginalne PNG służą wyłącznie do odczytu stanu;
widoczne ikony są lokalnymi wektorami `chat_bubble` i `chat` Google.

Zasoby Google Material Symbols Outlined są lokalne w `assets/material`:
SVG, Apache 2.0, manifest adresów i sum SHA-256, wygenerowane `Paths.js`.
`python3 scripts/update-icons` odtwarza oryginalne ścieżki i metadane
viewportu ładowania bez sieci; `--fetch` to jawne
odświeżenie zestawu przez dewelopera. Runtime nie pobiera ikon i nie wymaga
Papirusa, qt6ct ani dodatkowej czcionki ikon. Google Material Symbols jest
innym katalogiem niż Material Design Icons Pictogrammers w Nerd Fonts.
[Źródło i warianty](https://developers.google.com/fonts/docs/material_symbols),
[brak logotypów innych firm](https://github.com/google/material-design-icons#third-party-logos).

Ramki okien sprawdzono 2026-09-20 na **Hyprland 0.56.2**, commit
`efb50993780079460b0cbed1363e2166a2de1d9f`, Quickshell **0.3.1-1** i Qt
**6.11.2**. API potwierdzono w lokalnych `stubs/hl.meta.lua` i qmltypes oraz
w oficjalnych źródłach: [konfiguracja Lua 0.56.2](https://github.com/hyprwm/Hyprland/blob/v0.56.2/example/hyprland.lua),
[shader gradientu](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/render/shaders/glsl/gradient.glsl),
[shader ramki](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/render/shaders/glsl/border.glsl),
[dispatch i rawEvent](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/Hyprland/).
Ustawienie 30° wynika z funkcji wag w tej wersji renderera, a nie z kąta
geometrycznej przekątnej okna. Rzeczywiste piksele porównuje test natywny.

Gradienty grup sprawdzono 2026-09-20 na Quickshell **0.3.1-1**, Qt Base
**6.11.2-3** i Qt Declarative **6.11.2-2**. Lokalny `QtQuick.Shapes`
udostępnia `LinearGradient`, `ShapePath` i `PathRectangle`. Przed użyciem
sprawdzono metadane zainstalowanego modułu i oficjalne API Qt 6.11:
[Shape](https://doc.qt.io/qt-6/qml-qtquick-shapes-shape.html),
[LinearGradient](https://doc.qt.io/qt-6/qml-qtquick-shapes-lineargradient.html),
[ShapePath](https://doc.qt.io/qt-6/qml-qtquick-shapes-shapepath.html).
Testy obejmują renderer software oraz GPU w prywatnym Waylandzie.
Natywny runner odczytuje piksele PNG przez lokalny ImageMagick **7.1.2-31**,
`magick … -depth 8 RGB:-`; sprawdzono [format RGB](https://imagemagick.org/formats/)
i [opcję depth](https://imagemagick.org/command-line-options/#depth).
Sprawdzono także [Repeater.itemAt/itemAdded](https://doc.qt.io/qt-6/qml-qtquick-repeater.html):
liczba modelu nie gwarantuje, że asynchroniczne delegaty są już utworzone.

Zweryfikowano **16 września 2026**, etapy 00–12. Źródła nie wymagają `../putpuccin`.

Rozszerzenie z **17 września 2026** używa tych samych wersji Quickshell,
Qt i Hyprlanda. Osobne okno Ustawienia korzysta z `FloatingWindow` oraz
natywnego modelu okien Hyprlanda. Skróty wymagają API Lua Hyprlanda 0.56.2
(`hl.bind`, usuwalne uchwyty, `hyprctl eval`) i lokalnego `libxkbcommon`.
Pomocnik Python działa tylko podczas odczytu, walidacji lub zmiany przypisań;
nie dodaje stałego procesu. Kolory pozostają w `settings.json`, skróty
i komendy zapisują się oddzielnie w `keyboard.json`. [Kontrakt](keyboard.md),
[test prywatnego Waylanda](testing.md#okno-ustawienia-skróty-i-komendy--2026-09-17).

Ponowna kontrola w etapie 12 potwierdziła Quickshell 0.3.1, Qt 6.11.2,
Hyprland 0.56.2 / Aquamarine 0.15.0 i hyprsunset 0.4.0-3.
Istotne doprecyzowanie izolacji: `/dev/dri` jest niewidoczny w sandboxie,
natomiast poza nim istnieją `card0` i `renderD128`. Start z prywatnym
`/dev`, bez hostowego Waylanda, kończy się brakiem alokatora. Próbę
zagnieżdżonego kompozytora z socketem rodzica i samym `renderD128`
początkowo odrzucił automatyczny przegląd uprawnień. Po wyraźnej zgodzie
użytkownika wykonano 12-sekundowy start. Po skróceniu prywatnego
XDG_RUNTIME_DIR działa także odczyt `hyprctl -i <prywatna sygnatura> -j monitors`
i powstaje socket zdarzeń (100 bajtów ścieżki). [Wynik](evidence/12-wayland-short-runtime.json).
Szerszy test został najpierw odrzucony jako wykraczający poza zgodę na próbę
samego kompozytora. Użytkownik następnie zatwierdził cały dalszy odbiór UI
z koniecznymi powtórzeniami do 10 minut. Produkcyjne okna Putkin uruchomiono
w prywatnym Waylandzie na GPU, z atrapami domen. Potwierdzono natywne
wejście, grab, layer-shell i macierz rozdzielczości/skali. Fizyczny sprzęt,
PAM i operacje sesji pozostają poza tymi próbami.
Szczegóły i komendy: [odbiór etapu 12](validation.md).

## Caffeinate — 2026-09-20

Sprawdzono lokalnie: Quickshell 0.3.1-1, Qt Base 6.11.2-3,
Qt Declarative 6.11.2-2, systemd 261.3-1, Hypridle 0.1.8-2,
python-dbus 1.4.0-2, python-gobject 3.56.3-1, VoxType 1.0.1-1.
Pomocnik używa istniejących dbus-python i GLib, tak jak adapter sesji.
API `Inhibit`, `BlockInhibited` i własność FD sprawdzono w zainstalowanym
`man org.freedesktop.login1`; semantykę kontroli inhibitorów w `man systemctl`.
Źródła oficjalne i zachowanie [Caffeinate](caffeinate.md).

## Faktyczne wersje

| Element | Wynik / sposób sprawdzenia |
| --- | --- |
| Quickshell | `quickshell --version`: **0.3.1**, dystrybucja Arch; pakiet `0.3.1-1` |
| Qt | `qmake6 -query QT_VERSION`: **6.11.2** |
| Qt Base / Declarative | `pacman -Q qt6-base qt6-declarative`: `6.11.2-3` / `6.11.2-1` |
| Qt SVG / Wayland | `pacman -Q qt6-svg qt6-wayland`: oba `6.11.2-1` |
| Hyprland | `Hyprland --version`: **0.56.2**, commit `efb50993780079460b0cbed1363e2166a2de1d9f`; pakiet `0.56.2-3` |
| Aktywna sesja Hyprlanda | Końcowy `hyprctl -j version`: **0.56.2**, ten sam commit co executable, Aquamarine **0.15.0**; [odczyt etapu 12](evidence/12-closeout-live.json). Wcześniejszy brak połączenia w sandboxie jest wynikiem historycznym. |
| D-Bus | pakiet `dbus 1.16.2-1`; dostępny `dbus-run-session` |
| Python | pakiet `python 3.14.7-1`; narzędzia projektu używają wyłącznie biblioteki standardowej |
| Audio | PipeWire **1.6.8** (`1:1.6.8-1`), WirePlumber **0.5.17** (`0.5.17-1`). Integracja testuje prywatny PipeWire z wirtualnymi sinkami; nie uruchamia WirePlumber ani sprzętu. |
| Jasność | `brightnessctl 0.5.1-3`; `--version` drukuje `0.5`. Produkcja używa klasy backlight. Testy Process otrzymują atrapę executable; bez sysfs/sprzętu. |
| Font | **JetBrainsMono Nerd Font Mono** — zainstalowany i potwierdzony przez `fc-match` oraz Qt.fontFamilies() |
| Kernel pomiaru | `7.2.4-arch1-2`; środowisko udostępnia 8 logicznych CPU |
| Prywatny kompozytor testowy | Weston/Sway/Cage niedostępne. Z zatwierdzonym socketem rodzica i `renderD128` Hyprland działa w prywatnym bubblewrap; krótkie XDG_RUNTIME_DIR zapewnia IPC. Rzeczywiste okna Putkin i przechwytywanie wyjść HEADLESS działają. |
| Wejście testowego Waylanda | `wtype 0.4-2`; dokumentacja v0.4. `wayland-scanner` / libwayland-client **1.26.0**, `cc` i `pkg-config` budują prywatny klient kliknięcia z protokołu w repo. Wejście wyłącznie do zagnieżdżonego kompozytora. |
| Zrzuty testowego Waylanda | `grim 1.5.0-2`, oficjalny pakiet rozpakowany do `/tmp/putkin-grim`, bez instalacji systemowej. SHA-256 zgodne z lokalną bazą Arch; [dowód](evidence/12-grim-package.json). Runner obsługuje `PUTKIN_GRIM=/ścieżka/do/grim`. |

`qmlformat`, `qmllint`, `qmltestrunner` i `qtpaths` znajdują się w
`/usr/lib/qt6/bin`, poza domyślnym PATH. `qmlformat --version` i
`qmllint --version` potwierdzają 6.11.2. Skrypty sprawdzają PATH, następnie
`/usr/lib/qt6/bin` i `/usr/lib64/qt6/bin`. W razie niestandardowej instalacji
można ustawić `PUTKIN_QMLFORMAT`, `PUTKIN_QMLLINT`, `PUTKIN_QMLTESTRUNNER`
lub `PUTKIN_QUICKSHELL` na bezwzględną ścieżkę executable. Nieistniejący override
jest błędem, bez cichego powrotu do innego narzędzia.

`/usr/lib/qt6/bin/qtpaths --query QT_INSTALL_QML` wskazuje `/usr/lib/qt6/qml`.
Potwierdzono pliki `qmldir` dla QtQml, QtQuick, QtQuick.Controls.Basic,
QtQuick.Layouts, QtTest oraz Quickshell. Te moduły uczestniczą w sprawdzonym
grafie podglądu/testów. Dostępne są też metadane Quickshell.Hyprland,
Networking, Bluetooth, Services.Pipewire, UPower, SystemTray i Notifications;
**ich usług nie inicjalizowano i nie testowano** w etapie 00.

## Uruchamianie

Z katalogu projektu:

```sh
scripts/check
scripts/test
scripts/preview
scripts/preview --bar --size 1920x1080 --screenshot artifacts/bar.png
scripts/measure-idle
scripts/measure-idle --bar --output artifacts/bar-idle.json
scripts/preview --panels --scenario settings --screenshot artifacts/settings.png
scripts/test-panels-integration
scripts/test-settings-integration
scripts/measure-idle --panels --output artifacts/panels-idle.json
scripts/preview --audio --scenario osd --screenshot artifacts/audio-osd.png
scripts/test-audio-integration
scripts/test-audio-integration --idle --output artifacts/audio-idle.json
scripts/preview --brightness --scenario brightnessOsd --screenshot artifacts/brightness-osd.png
scripts/test-brightness-integration --idle --output artifacts/brightness.json
```

`scripts/preview` uruchamia prawdziwy Quickshell z `preview.qml`, zapisuje
`artifacts/foundation.png` i log, a po 3 s zamyka własne procesy. Nie otwiera
okna na aktywnym pulpicie: renderuje offscreen, na atrapach, w prywatnych XDG
i D-Bus. Opcja `--seconds` zmienia czas życia, `--screenshot` miejsce zapisu.

`shell.qml` składa usługę Hyprlanda, zegar minutowy, kontroler/IPC paska,
koordynator/IPC paneli, jeden lazy loader i `Variants` paska dla ekranów Qt.
Etap 04 dodaje pojedynczy adapter audio, jego IPC oraz osobny loader OSD.
Etap 05 dodaje adapter brightnessctl, model/IPC jasności i drugi typ w tym
samym OSD. Proces pomocniczy żyje tylko podczas odczytu lub zapisu;
brak okresowego pollingu. [Kontrakt i zweryfikowane API](brightness.md).
Pragma `QS_PIPEWIRE_IMMEDIATE_RECONNECT=1` włącza oczekiwanie na późniejszy
start PipeWire; szczegóły API, odczytu po operacji i niestandardowych socketów
opisuje [audio.md](audio.md).
Standardowe uruchomienie w docelowej sesji
to `quickshell --path /ścieżka/putkin/shell.qml`. Nie używaj go jako podglądu
na aktywnym pulpicie. `scripts/preview --bar` uruchamia osobny
`bar-preview.qml` z atrapą; `--root` z etapu 00 usunięto, bo korzeń jest
teraz konfiguracją produkcyjną, wymagającą Waylanda i Hyprlanda.

`preview.qml` pozostaje osobnym punktem wejścia także po rozbudowie właściwego
shella. Oba entrypointy są w katalogu głównym: Quickshell 0.3.1 ogranicza graf
lokalnych plików do katalogu konfiguracji. Entry point wewnątrz `preview/`
powodował przy imporcie `../components` błąd `qrc:/qs-blackhole`.

## Kod fundamentu

- `core/Theme.qml`: role Mocha i dwa akcenty. Rola `onAccent` z projektu ma
  w QML nazwę `accentText`; `onAccent` z inicjalizatorem było interpretowane
  przez lokalny runtime jako handler sygnału. Od etapu 03 kolory
  pochodzą z efektywnych ustawień; tekst i obrys dobierają kontrast.
- `core/Metrics.qml`: zerowy promień, obramowanie 2 px, fokus 2 px,
  odstępy, kontrolki 36 px, tekst 13/12 px.
- `components/`: Button, IconButton, PanelFrame i Slider oparte na
  Qt Quick Controls Basic; wspólny ToolTip. Standardowe wejście Qt pozostaje
  zachowane. Ikona resetu jest lokalnym SVG, z tekstowym fallbackiem `?`.
- `preview/FoundationView.qml`: wspólny widok okna i testów. Otrzymuje jawny
  `MockState` z poziomem 60 i stanem wyboru; akcje zmieniają tylko tę atrapę.
- `preview/PreviewWindow.qml`: zwykłe `FloatingWindow`, opcjonalny jednorazowy
  zrzut, bez okresowego odpytywania. Bez zmiennej `PUTKIN_SCREENSHOT` timer
  zrzutu pozostaje wyłączony.

Materiały PNG z katalogu głównego są wyłącznie referencjami. Nie wchodzą do
grafu zasobów UI. W etapie 01 doszły `services/`, `modules/bar/`, `BarFocus`,
podgląd paska i test protokołu. Kontrakty: [workspace](workspaces.md),
[IPC](ipc.md). Etap 02 dodaje `PanelCoordinator`, `PanelHost`, `PanelIpc`,
`NavigationButton`, produkcyjne widoki `modules/quicksettings/` i
`modules/settings/`. Etap 03 dodaje edycję
i zapis ustawień opisane w [settings.md](settings.md).

Zrzuty paska: `--size 1920x1080` / `1366x768`, scenariusze `basic`,
`overflow` (30 numerów), `focus` i `unavailable`. Domyślnie podgląd używa
stałej daty dla powtarzalności. Pomiar `--bar` włącza prawdziwy
`SystemClock.Minutes`. Test-only `bar-test.qml` uruchamiaj wyłącznie przez
`scripts/test-bar-integration`; wrapper zapewnia prywatne sockety.

`scripts/preview --panels` używa prawdziwego `LazyLoader`, produkcyjnych
widoków i koordynatora z jawnymi atrapami ekranu/Hyprlanda/graba. Scenariusze:
`quickSettings` (również domyślny `basic`), `settings`, `closed`.
Przykład małego ekranu: `--size 320x220 --scenario settings`.
Test-only `panels-test.qml` uruchamiaj przez `scripts/test-panels-integration`.
Nie podłącza produkcyjnego `InteractivePanelWindow` ani natywnego graba.

Quickshell tej instalacji ma pluginy w executable; zwykły `qmltestrunner`
nie może zaimportować jego głównego modułu. Dlatego koordynator i host
pozostają czystym Qt, a loader jest jawną zależnością. QtTest przekazuje
adapter `QtQuick.Loader`, test integracyjny — rzeczywisty `LazyLoader`.
Żaden test nie przepisuje importów w źródłach.

## Dokumentacja API sprawdzona przed implementacją

- Quickshell **0.3.1**: [ShellRoot](https://quickshell.org/docs/v0.3.1/types/Quickshell/ShellRoot/),
  [FloatingWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/),
  [QsWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/QsWindow/).
- Qt **6.11.2**: [dostosowanie kontrolek](https://doc.qt.io/qt-6.11/qtquickcontrols-customize.html),
  [AbstractButton](https://doc.qt.io/qt-6.11/qml-qtquick-controls-abstractbutton.html),
  [Slider](https://doc.qt.io/qt-6.11/qml-qtquick-controls-slider.html),
  [Window / requestActivate](https://doc.qt.io/qt-6.11/qml-qtquick-window.html),
  [TestCase](https://doc.qt.io/qt-6.11/qml-qttest-testcase.html).
- Lokalne `.qmltypes`, implementacja `QtTest/TestCase.qml` i `--help`
  narzędzi Qt służyły do sprawdzenia sygnatur i flag CLI tej instalacji.
- Etap 01, Quickshell **0.3.1**:
  [PanelWindow](https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/),
  [Variants](https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/),
  [WlrLayershell](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrLayershell/),
  [WlrKeyboardFocus](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrKeyboardFocus/),
  [SystemClock](https://quickshell.org/docs/v0.3.1/types/Quickshell/SystemClock/),
  [IpcHandler](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/).
- Qt **6.11.2**:
  [ListView](https://doc.qt.io/qt-6.11/qml-qtquick-listview.html),
  [formatowanie Qt](https://doc.qt.io/qt-6.11/qml-qtqml-qt.html).
  API Hyprlanda i ograniczenie dostępności opisuje [kontrakt adaptera](workspaces.md).

API ponownie sprawdzone przed etapem 02: lokalne `quickshell --version`
i `qmake6 -query QT_VERSION` nadal dają 0.3.1 / 6.11.2. Przeczytano oficjalne
strony wersji dla `LazyLoader`, `PanelWindow`, `QsWindow`, `WlrLayershell`,
`HyprlandFocusGrab` oraz Qt `ScrollView`, `Keys`, `KeyNavigation`,
`AbstractButton.click()` i `Popup.popupType`. Linki i wynikające z nich
decyzje znajdują się w [kontrakcie paneli](panels.md).

## Ustawienia — etap 03

Lokalne `quickshell --version` i `qmake6 -query QT_VERSION` ponownie
potwierdziły **0.3.1 / 6.11.2**. Zweryfikowano wersjonowaną dokumentację
FileView/FileViewError, kod FileView oraz Qt TextField/TextInput i
AbstractButton. [Linki i decyzje](settings.md#implementacja-i-potwierdzone-api).
Nie dodano pakietów, procesów ani usług hosta.

`shell.qml` tworzy `SettingsFile` i `Settings`, wiąże Theme z efektywnym
stanem i przekazuje model koordynatorowi. `Appearance.js` zawiera defaults,
walidację, presety i kontrast. Edytor dostaje model przez host. Brak pliku
jest zwykłym stanem; odczyt i podgląd go nie tworzą.

Podgląd paneli używa rzeczywistego Settings/FileView z prywatnym XDG.
`--accent '#94e2d5' --secondary '#fab387'` przygotowuje wyłącznie prywatny
plik podglądu. QtTest podaje jawny `MockSettingsFile`; integracja odpala
`settings-test.qml` z prawdziwym FileView i testowym IPC. Produkcyjne IPC
nie zostało rozszerzone o testowe metody.

## Git

`git status --short --branch` zwraca `fatal: not a git repository`.
Pliki zapisano w workspace; **nie utworzono commitów**. `.gitignore` pomija
artefakty i prywatne dane, zachowując dokumentację, prompty, zasady i wybrane
dowody w `docs/evidence/`.

## Pulpit i Night Light — etap 11

Ponownie potwierdzono Quickshell 0.3.1, Qt 6.11.2 i Hyprland 0.56.2.
Na początku nie było backendów tapety/temperatury; użytkownik zainstalował
`hyprsunset 0.4.0-3` (`hyprsunset --version`: 0.4.0). Hyprutils 0.14.2
i systemd 261.3. Hyprpaper nie jest zależnością: zgodnie z doprecyzowaniem
użytkownika tapetę renderuje Quickshell. Nie instalowano żadnego programu
ani nie uruchomiono usługi użytkownika podczas implementacji etapu 11.
Późniejszą aktywację i potwierdzony wizualny odbiór Night Light opisuje
[dokumentacja pulpitu](desktop.md#aktywacja-lokalna-2026-09-16).

`PUTKIN_WALLPAPER=solid` lub bezwzględna ścieżka włącza moduł tła;
brak zmiennej pozostawia go wyłączonym. `shell.qml` ma 95 linii.
`NightLightService` korzysta z krótkiego pomocnika Python (stdlib, Linux)
i istniejącej jednostki `hyprsunset.service`. Brak stałego procesu pomocnika,
pollingu, nowych pól settings.json i nowych produkcyjnych metod IPC.

```sh
scripts/preview --desktop --wallpaper solid --screenshot artifacts/desktop.png
scripts/preview --desktop --scenario nightLightAbsent --size 1366x768 --scale 1.25
scripts/preview --desktop --scenario nightLightDenied --size 320x220 --scale 2
scripts/test-desktop-integration --idle --output artifacts/desktop.json
```

Podglądy używają `MockNightLightBackend`; nie inicjalizują socketu
prawdziwego hyprsunset. Test protokołu ma osobny proces atrapy, prywatny
socket instancji, XDG i D-Bus. Sprawdza również negatywną identyfikację
atrapy przez kod produkcyjny. Źródła API, zakres i instrukcje rollbacku:
[desktop.md](desktop.md).

## Bateria i tray — etap 06

Ponownie sprawdzono Quickshell **0.3.1**, Qt **6.11.2** i lokalne qmltypes
UPower/SystemTray/DBusMenu. Dostępne: UPower **1.91.4-1**, glib2 **2.88.3-1**
(`gdbus`), systemd **261.3-1** (`busctl`), testowe python-dbus **1.4.0-2**
i python-gobject **3.56.3-1**. Nie instalowano pakietów.

W produkcji jest jeden natywny adapter UPower i jeden gdbus obserwujący
sygnały/właściciela. Busctl działa przejściowo przy odczycie awaryjnym
po powrocie usługi. Powód i ograniczenia:
[kontrakt oraz źródła wersji](battery-tray.md).
Tray używa natywnego modelu SNI i DBusMenu; nie dodaje procesu.

```sh
scripts/preview --status --scenario batteryLow --screenshot artifacts/battery.png
scripts/preview --status --scenario trayMenu --screenshot artifacts/tray.png
scripts/preview --status --scenario trayOverflow --size 320x220 --scale 2 --screenshot artifacts/tray-small.png
scripts/test-status-integration --idle --output artifacts/status.json
```

`--status` rozszerza podgląd paneli o jawne MockBatteryBackend/MockTray,
a `--scale` przyjmuje 1 / 1.25 / 1.5 / 2. Integracja `status-test.qml`
jest uruchamiana tylko przez wrapper z osobnym D-Bus. Oba adresy,
**systemowy i sesyjny**, wskazują ten prywatny socket. Fikcyjne UPower,
SNI i DBusMenu nie korzystają ze sprzętu. Usługi hosta pozostają nietknięte.


## Sieć — etap 07

Potwierdzono Quickshell **0.3.1-1**, Qt **6.11.2** oraz NetworkManager
**1.58.1-1**. Oficjalne XML interfejsów NM są w
`/usr/share/dbus-1/interfaces/`; źródła Quickshell tagu v0.3.1 i lokalne
qmltypes potwierdzają `connectWithPsk(string)`, `connectionFailed(reason)`
i `WifiDevice.scannerEnabled`. [API i ograniczenia](network.md).

Produkcja wymaga NetworkManagera z Wi-Fi oraz istniejących gdbus/busctl
(glib2/systemd). Jeden obserwator gdbus utrzymuje subskrypcję; busctl odczytuje
stan po zdarzeniach i potwierdza zapis boolean radia. Bez własnego demona,
plugina C++ i pollingu. `nm-connection-editor` jest opcjonalny i nie jest
zainstalowany w tym środowisku. Nie instalowano żadnych pakietów.

```sh
scripts/preview --network --scenario networkPassword --screenshot artifacts/wifi.png
scripts/preview --network --scenario networkPortal --size 1366x768 --scale 1.25 --screenshot artifacts/portal.png
scripts/test-network-integration --idle --output artifacts/network.json
```

`--network` dodaje jawny model atrapowy do istniejącego podglądu paneli.
Integracja natywna korzysta z `network-test.qml`, python-dbus i python-gobject,
fałszywego NetworkManagera oraz osobnych XDG i obu adresów D-Bus.
Nie wykonuje żadnych połączeń Wi-Fi ani zapisów radia hosta.
Restart/późny start NM i twardy reload wymagają pełnego restartu procesu
Putkin z powodu cyklu życia singletonu 0.3.1. Zwykły reload zachowuje
obserwowaną tożsamość usługi i ochronę przed starymi danymi.


## Bluetooth — etap 08

Ponownie potwierdzono Quickshell **0.3.1-1**, Qt **6.11.2** oraz
BlueZ/bluez-utils **5.87-2**. gdbus/busctl i testowe python-dbus/python-gobject
były dostępne. Blueman nie jest zainstalowany; pakietów nie dodawano.
[Zweryfikowane API, wybór adaptera i ograniczenia](bluetooth.md).

```sh
scripts/preview --bluetooth --scenario bluetoothMultiple --screenshot artifacts/bluetooth.png
scripts/preview --bluetooth --scenario bluetoothDeviceFocus --size 320x220 --scale 2 --screenshot artifacts/bluetooth-small.png
scripts/test-bluetooth-integration --idle --output artifacts/bluetooth.json
```

Podgląd używa tylko MockBluetoothBackend/Adapter/Device. Integracja importuje
produkcyjny backend w `bluetooth-test.qml`, z fikcyjnym BlueZ oraz dwoma
adresami D-Bus kierowanymi na prywatny socket. PATH testu udostępnia tylko
niezbędne helpery; test menedżera uruchamia wyłącznie własny executable.
Nie skanuje, nie paruje i nie dotyka sprzętu hosta. Produkcja ma jednego
pasywnego obserwatora gdbus i przejściowy busctl podczas operacji.

## Powiadomienia — etap 09

Ponownie sprawdzono Quickshell **0.3.1-1**, Qt **6.11.2**, dbus **1.16.2-1**,
systemd/busctl **261.3-1**, python-dbus **1.4.0-2**, python-gobject **3.56.3-1**.
Nie instalowano pakietów. Python/dbus/gobject są teraz także zależnością
produkcyjnego obserwatora zastąpień; szczegóły i oficjalne źródła:
[powiadomienia](notifications.md#api-zależności-i-własność-nazwy).

```sh
scripts/preview --notifications --scenario notification --screenshot artifacts/notification.png
scripts/preview --notifications --scenario notificationLong --size 320x220 --scale 2 --screenshot artifacts/notification-small.png
scripts/preview --notifications --scenario notificationDnd --screenshot artifacts/dnd.png
scripts/test-notifications-integration --idle --output artifacts/notifications.json
```

Podgląd używa `MockNotificationBackend` i produkcyjnych widoków/usługi;
nie uruchamia natywnego serwera. `notifications-test.qml` przez wrapper
uruchamia tylko produkcyjny serwer/obserwatora powiadomień; pozostałe usługi
są atrapami. Oba adresy D-Bus i wszystkie XDG są prywatne. Klienci są
rzeczywistymi połączeniami python-dbus, bez serwera mako/dunst/SwayNC hosta.
Jeden obserwator działa zdarzeniowo; `busctl` kończy się po preflight.
Natywny singleton wymaga zakończenia procesu dla zwolnienia nazwy.
W etapie 09 nie aktywowano Putkin na pulpicie; `/dev/dri` pozostawał
niewidoczny w sandboxie, bez Westona, Sway i Cage. Późniejszy odbiór
Waylanda i aktywację dokumentują [etap 12](validation.md) oraz [instalacja](install.md).

## Sesja — etap 10

Ponownie sprawdzono Quickshell **0.3.1**, Qt **6.11.2**, Hyprland **0.56.2**,
Hyprlock **0.9.6-3**, Hypridle **0.1.8-2**, uwsm **0.26.7-1** i systemd
**261.3-1**. python-dbus **1.4.0-2** i python-gobject **3.56.3-1** są dostępne.
Wówczas `hyprctl -j version` zgłaszał `Couldn't set socket timeout (2)`;
wersję aktywnej sesji potwierdzono później w etapie 12, w tabeli powyżej.
Pakietów nie instalowano.

Przed implementacją przeczytano lokalny podręcznik login1 z systemd 261.3,
README uwsm 0.26.7, przykłady Hyprlock/Hypridle oraz oficjalne źródła tagów
Hypridle 0.1.8, Hyprlock 0.9.6 i Hyprlanda 0.56.2.
[Źródła i znaczenie potwierdzenia blokady](session.md).
Sprawdzono również [Process Quickshell 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/),
[Button Qt 6.11.2](https://doc.qt.io/qt-6.11/qml-qtquick-controls-button.html),
[tutorial dbus-python](https://dbus.freedesktop.org/doc/dbus-python/tutorial.html)
i lokalne sygnatury zainstalowanego modułu.

```sh
scripts/preview --session --scenario power --screenshot artifacts/power.png
scripts/preview --session --scenario powerConfirm --size 1366x768 --scale 1.25 --screenshot artifacts/power-confirm.png
scripts/preview --session --scenario powerUnavailable --size 320x220 --scale 2 --screenshot artifacts/power-small.png
scripts/test-session-integration --idle --output artifacts/session.json
```

Podgląd używa `MockSessionBackend`; entrypoint integracyjny
`session-test.qml` otrzymuje produkcyjny adapter i fikcyjne login1/ScreenSaver.
Oba adresy D-Bus, XDG i PATH są prywatne. Wyłącznie testowy helper podmienia
sprawdzenie tożsamości obserwatora. Osobny scenariusz weryfikuje odrzucenie
tej atrapy przez produkcyjne sprawdzenie tożsamości. Locker to testowy proces
rejestrujący argv, bez Waylanda/PAM. Nie uruchamiaj entrypointu ręcznie
na aktywnym pulpicie.

## Rozszerzenie launchera

Podgląd 2026-09-20: ponownie potwierdzone Qt **6.11.2**, Quickshell
**0.3.1-1**, Qt Declarative **6.11.2-2**, Python **3.14.7-1**, cliphist
**0.7.0-2** i wl-clipboard **2.3.0-1**. Nie dodaje pakietów.
[Sprawdzone oficjalne API](launcher.md#api-sprawdzone-przed-użyciem).

Wymagane narzędzia: Python 3.14, fd, xdg-open; dla schowka wl-clipboard,
cliphist i file; aplikacje Terminal=true korzystają z Kitty. Lokalne wersje
oraz API zapisano w [kontrakcie](launcher.md). Bez instalacji nowych pakietów.
Podgląd: `scripts/preview --scenario launcherApps --size 1366x768` albo
`--scenario launcherClipboard --size 320x220 --scale 1.5`.
`scripts/test-launcher-integration` uruchamia jedynie testowy punkt wejścia
z prywatnymi danymi i atrapami poleceń schowka/aplikacji. Zwykły shell
ma zdarzeniowego pomocnika oraz dwa watchery wl-paste; nie ma pollingu.

## Audio i wejścia launchera — 2026-09-17

Quickshell 0.3.1 / Qt 6.11.2 / Hyprland 0.56.2 ponownie potwierdzone.
Panel audio i mikrofon używają wspólnego serwisu i dwóch trackerów, bez
nowego procesu. `scripts/test-audio-integration` ma teraz dwa wirtualne
wejścia obok dwóch wyjść. Wszystkie testy zachowują izolację sprzętu.
Skróty `Super+V` i `Super+:` są w `config/menu-keybinds.lua`. Wersja Lua
0.56.2 rozpoznaje bazowy `semicolon` z modyfikatorami SUPER+SHIFT; lokalny
XKB układu pl potwierdza dwukropek jako Shift+AC10.
[Wyniki i ograniczenia](status.md), [kontrakt audio](audio.md).
