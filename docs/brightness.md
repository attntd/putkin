# Jasność i wspólny OSD — etap 05

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade; ograniczony ruch
wyłącza je natychmiast. Kontrakty adapterów i potwierdzania operacji pozostają.


Jeden `BrightnessService` obsługuje Quick Settings i IPC. Jawnie przekazany
`BrightnessBackend` uruchamia `brightnessctl`; widoki nie znają komend.
Nie ma helpera produkcyjnego, pluginu C++, daemona, wygładzania ani DDC.

## Urządzenie i odczyt

Sprawdzono Quickshell **0.3.1**, Qt **6.11.2** i pakiet
`brightnessctl 0.5.1-3` (`brightnessctl --version` drukuje `0.5`).
Odkrywanie wykonuje listę argumentów:

```text
brightnessctl --class=backlight --machine-readable --list
```

`Backlight.js` waliduje CSV: nazwę bez wildcardów, klasę `backlight`,
całkowity zakres 1…2147483647 i odczyt 0…max. Nie korzysta z zaokrąglonej
kolumny procentowej. Zerowe/nieznane max, nieprawidłowa wartość, duplikat
lub niepoprawny format blokują regulację. LED klawiatury nie jest backlight.

Pierwszy wybór to urządzenie o największym max, przy remisie pierwsza
nazwa leksykograficznie. To heurystyka preferowania drobniejszego zakresu,
nie rozpoznawanie fizycznego monitora. Kolejne odczyty zachowują wybór,
dopóki urządzenie jest dostępne. Po jego zniknięciu kolejny odczyt listy
wybiera urządzenie według tej samej reguły. Każdy zapis wskazuje dokładną
nazwę. Układy z kilkoma podświetleniami wymagają odbioru sprzętowego;
nie ma edytora wyboru ani zapamiętywania poziomu w ustawieniach.

`brightnessctl` czyta `brightness` i `max_brightness`, nie
`actual_brightness`. Pokazujemy odczytany poziom sterownika, bez obietnicy
pomiaru luminancji. CLI nie oferuje subskrypcji zmian. Kernel opisuje
uevent i zgłaszanie zmian przez sterownik; samo obserwowanie pliku sysfs
przez FileView nie potwierdza dostarczania tych zdarzeń. Nie dodano watchera
ani własnego właściciela logind. [Źródło brightnessctl 0.5.1](https://github.com/Hummer12007/brightnessctl/blob/0.5.1/brightnessctl.c),
[ABI backlight](https://docs.kernel.org/gpu/backlight.html).

`refresh()` odczytuje stan przy starcie, otwarciu Quick Settings (także
podczas fade), przez przycisk „Odśwież podświetlenie” i IPC. Etap 10 może
wywołać je po wznowieniu. Nie ma pollingu także przy widocznym panelu:
**0 odczytów/min w bezczynności**. Obca zmiana jest widoczna przy następnym
odświeżeniu; nie deklarujemy live ani OSD dla zewnętrznych klawiszy firmware.
Skróty Putkin używają IPC.

## Zapis i kolejka

`setPercent(value, monitor)` przyjmuje skończoną liczbę 1–100;
`change(points, monitor)` przyjmuje −100…100 i ogranicza wynik do 1–100.
Tekst, null, NaN i wartości poza zakresem są odrzucane. Wartość surowa to
zaokrąglone `percent * max / 100`, co najmniej `ceil(max / 100)` i 1,
najwyżej max. Nigdy nie zlecamy sprzętowego zera. Zastane 0 jest pokazane
jako 0%, a uchwyt stoi na 1%; otwarcie panelu niczego nie zapisuje.
Na grubych zakresach krok klawiatury obejmuje przynajmniej jeden poziom;
także mała niezerowa zmiana IPC przesuwa o jeden poziom, jeśli zaokrąglenie
pozostawiłoby tę samą wartość. Odczyt pokazuje rzeczywiste zaokrąglenie.

Rozpoczęcia zapisów dzieli co najmniej **120 ms**. W locie jest najwyżej
jeden proces; kolejka przechowuje najnowszy cel. Względne zmiany sumują
się względem oczekującego celu. Końcowe żądanie pozostaje w kolejce po
puszczeniu suwaka lub zamknięciu panelu. Odpowiedź ma identyfikator komendy
i rewizję celu: nie nadpisuje stanu, błędu ani OSD nowszego żądania.
Starszy zapis może zakończyć się w sterowniku, ale najnowszy rusza dopiero
po zakończeniu tamtego procesu.

Zapis używa `--class=backlight --device=NAZWA --quiet set WARTOŚĆ`.
Po kodzie 0 następuje osobne `--device=NAZWA --machine-readable info`:
wydruk `set` zawiera żądanie i nie wystarcza jako potwierdzenie.
Sukces wymaga tej samej nazwy, max i dokładnej wartości surowej z odczytu.
Gdy nadeszło nowsze żądanie, stara odpowiedź jest pomijana, a potwierdzenie
nastąpi po najnowszym zapisie.

Każda komenda ma limit **1500 ms**, następnie SIGTERM i po **150 ms**
SIGKILL, jeśli dziecko nadal żyje. Kolejka czeka na zakończenie procesu.
Nie ma shella ani odłączonych procesów; zniszczenie adaptera/reload kończy
dziecko. Komendy mają locale C. `FailedToStart` w Quickshell 0.3.1 emituje
`runningChanged`, ale nie `exited`; obsługiwane są obie drogi. Natywne
`ExitStatus` nie ma pełnych metadanych QML: sygnał jest połączony przez
wspierane `connect()`, bez wyciszania lintu/importów. Integracja bada także
awarię procesu, brak executable i zabicie po timeout.
[Process 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/Process/),
[implementacja](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/io/process.cpp),
[sygnały Qt 6.11](https://doc.qt.io/qt-6.11/qtqml-syntax-signals.html#connecting-signals-to-methods-and-signals).

## Błędy i interfejs

Błąd zapisu zachowuje ostatni potwierdzony poziom; następuje odczyt bez
skasowania błędu i bez sukcesu. Błąd odczytu usuwa dostępność, nie ustawia
0%. Odmowa, timeout, brak narzędzia i niepotwierdzony zapis są widoczne.
Przy braku urządzenia znikają tytuł poziomu i suwak; pozostają
„Jasność niedostępna · szczegóły”, diagnoza i odświeżenie. Zniknięcie
skupionego suwaka przenosi fokus na szczegóły. Nie przejmuje fokusu innej
poprawnej kontrolki.

Uprawnieniami zarządza instalacja `brightnessctl` (sysfs/udev lub wsparcie
logind danej kompilacji). Putkin nie używa sudo, nie zmienia grup ani reguł
systemu. [Uprawnienia brightnessctl 0.5.1](https://github.com/Hummer12007/brightnessctl/tree/0.5.1#permissions).

`available`, `percent`, `requestedPercent`, `device`, `busy`, `lastError`
i `diagnostic` to stan usługi. Potwierdzony procent jest oddzielony od
uchwytu i etykiety „Zmienianie na …”. `h/l` i strzałki regulują, `j/k`
przechodzą między audio, jasnością, szczegółami i motywem. Enter/Enter
numeryczny potwierdzają poziom, Tab/Shift+Tab i Spacja zachowują wejście Qt.
Escape zwija szczegóły przed zamknięciem. Mały panel przewija fokus.

## OSD

`OsdService` ma `kind`, `level`, `label`, `symbol` i `fillColor`.
Audio i jasność używają **tego samego hosta i loadera**. Potwierdzona akcja
zmienia typ, monitor i odnawia 1500 ms. Jasność używa
`Theme.accentSecondary` i lokalnej ikony słońca; audio `Theme.accent`.
Interaktywne Quick Settings ukrywa oba rodzaje OSD. Odczyt początkowy,
odświeżenie i błędy jasności go nie pokazują. Zasady okna bez fokusu,
wejścia i rezerwacji obszaru pozostają z [etapu 04](audio.md#osd).

Testy i granice odbioru: [testing.md](testing.md), [status.md](status.md),
[dowody etapu 05](evidence/05-brightness.md).
