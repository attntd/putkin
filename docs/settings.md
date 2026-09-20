# Ustawienia — Wygląd i Klawiatura

Rozszerzenie 2026-09-17: `ui openSettings` tworzy natywne `FloatingWindow`
z tytułem **Ustawienia**, dwiema sekcjami i rozmiarem początkowym 720×680
(ograniczonym dostępnym ekranem). Wygląd zawiera dotychczasowe próbki kolorów
i HEX. Klawiatura ma [osobny kontrakt](keyboard.md).
Zmiana sekcji zachowuje wersje robocze obu formularzy. Każda sekcja zapisuje
własny plik. Fokus poza oknem nie zamyka edytora; ponowne wywołanie przywołuje
istniejące okno. Inna powierzchnia Putkina zastępuje Ustawienia.

Aktualizacja wyglądu 2026-09-16: obowiązuje [skorygowany kontrakt UI](design.md).
Wcześniejsze opisy tooltipów, błędów przy kontrolkach i rozbudowanych opisów
widocznych w panelu są zastąpione przez brak tooltipów, krótkie etykiety
i osobne powiadomienia błędów. Przejścia wyłącznie fade 200 ms; opcja ograniczenia ruchu została usunięta. Kontrakty adapterów i potwierdzania operacji pozostają.


Quickshell **0.3.1**, Qt **6.11.2**. Strona **Wygląd** jest dostępna przez
Quick Settings → Ustawienia oraz istniejące IPC `ui openSettings`.
Kolory zmieniają wyłącznie Putkin.

Od 2026-09-20 te dwa kolory wyznaczają wspólny gradient każdej grupy UI:
akcent główny w lewym górnym, dodatkowy w prawym dolnym rogu paska lub
panelu. Próbki edytora zachowują jednolite, dosłowne kolory wyboru.

## Plik i schemat

`${XDG_CONFIG_HOME:-$HOME/.config}/putkin/settings.json` jest niezależny
od katalogu źródeł Quickshella. [Przykład](../config/settings.example.json):

```json
{
  "schemaVersion": 1,
  "appearance": {
    "accent": "#cba6f7",
    "accentSecondary": "#89b4fa"
  }
}
```

| Pole | Kontrakt |
| --- | --- |
| `schemaVersion` | Wymagana liczba `1`. Inne wersje blokują zapis, także po resecie formularza. |
| `appearance.accent` | Akcent główny, dokładnie `#RRGGBB`; domyślnie Mauve. |
| `appearance.accentSecondary` | Akcent dodatkowy, ten sam format; domyślnie Blue. |

Starsze pliki mogą zawierać boolean `appearance.reducedMotion`. Odczyt
akceptuje i ignoruje to pole, zachowując oba akcenty. Pierwszy jawny zapis
pomija je; samo wczytanie pliku nie zmienia danych na dysku.

Brak `appearance` lub znanego pola uzupełnia się domyślną wartością w pamięci.
Nie wywołuje to zapisu. `null`, tablice, niepoprawne typy, kolory nazwane,
krótkie HEX i kolory z kanałem alpha są odrzucane. Nieznane pola również
blokują zapis, aby starszy Putkin nie usunął cudzych opcji.

Jedynym źródłem defaults w runtime jest `core/Appearance.js`; przykład
konfiguracji jest dokumentem. Nie importujemy ustawień poprzedniego shella.
Brak pliku przy starcie oznacza Mocha/Mauve/Blue bez błędu. Odczyt i otwarcie
formularza nie tworzą ani katalogu, ani pliku. Pierwszy jawny zapis tworzy
brakujące katalogi; brak uprawnień zgłasza błąd w formularzu.

## Formularz i podgląd

Dla każdego akcentu są próbki Mauve, Pink, Blue, Lavender, Peach i Teal oraz
pole HEX. Poprawny kolor działa natychmiast w jednym współdzielonym Theme,
w tym na paskach wszystkich monitorów i w już istniejących kontrolkach.
Niepoprawny tekst zostaje w polu, pokazuje błąd i blokuje „Zapisz”; podgląd
zachowuje ostatni poprawny kolor. Przyjęty zapis normalizuje litery HEX
na małe.

- **Zapisz** sprawdza plik, zapisuje atomowo i potwierdza zawartość odczytem.
  Do tego czasu widać „Zapisywanie…”, a edycja jest wyłączona. Formularz
  pozostaje otwarty. „Zapisano ustawienia” pojawia się dopiero po potwierdzeniu.
- **Anuluj**, **Zamknij**, **Wstecz**, Escape, zamknięcie okna przez kompozytor,
  zastąpienie powierzchni, zmiana/usunięcie monitora oraz `bar focus` odrzucają
  podgląd. Koordynator robi to natychmiast, również przed utworzeniem widoku
  i podczas opóźnionego usuwania okna. Pełny reload Quickshella tworzy nowy
  model z pliku i zamkniętym edytorem; nie przenosi wersji roboczej.
- **Przywróć domyślne** zmienia tylko podgląd. Utrwalenie wymaga „Zapisz”.
- Zamknięcie anuluje zapis oczekujący na odczyt wstępny. Rozpoczętego
  atomowego zapisu nie odwracamy: jego potwierdzony wynik staje się stanem
  utrwalonym, ale nie otwiera ponownie edytora ani podglądu.

Próbki używają h/l w rzędzie, j/k między rzędami i Enter/Spacji do wyboru.
W polach `hjkl` pozostaje tekstem;
Enter w poprawnym polu przechodzi do kolejnej sekcji, bez zapisu całego
formularza. Tab/Shift+Tab przechodzą po kontrolkach i zostają w panelu.
Fokus ma obrys, wybrana próbka znak ✓.
Małe ekrany przewijają formularz wraz z fokusem.

Tekst na obu akcentach wybiera czerń lub biel według większego kontrastu
luminancji sRGB. Bardzo ciemne kolory dostają jasny obrys fokusu i aktywnych
przycisków/workspace oraz ostrzeżenie w edytorze. Kolory sukcesu, ostrzeżenia
i błędu pozostają niezależne od akcentów. Nazwa QML roli `onAccent` to
`accentText`; druga rola to `accentSecondaryText`.

## Błędy, zewnętrzne zmiany i własne zdarzenia

`Settings` rozdziela `persisted`, tekstową wersję `draft` i zweryfikowany
`preview`. `effective` wybiera podgląd tylko podczas edycji. Błędny JSON,
nieobsługiwana wersja lub błąd odczytu zachowuje ostatni poprawny stan
**bieżącego procesu** i pokazuje przyczynę w ustawieniach. Przy starcie z
uszkodzonym plikiem fallbackiem są defaults. Nie ma automatycznej naprawy,
kopii pliku na dysku ani nadpisywania błędnej konfiguracji.

`SettingsFile` obserwuje plik, jego katalog oraz utworzenie katalogu aplikacji.
Zdarzenia uruchamiają odczyt; nie ma okresowego pollingu. Usunięcie pliku
przywraca defaults w stanie utrwalonym. Poprawna zewnętrzna edycja aktualizuje
go bez przebudowy panelu. Otwarte pole, kursor i roboczy podgląd zostają na
miejscu, pojawia się konflikt, a zapis jest zablokowany — również gdy przed
zmianą formularz nie był zmodyfikowany. Zmiana samych białych znaków też
jest zmianą pliku.

**Wczytaj plik i odrzuć podgląd** przyjmuje ostatni odczytany stan i ponawia
odczyt. Uszkodzony plik trzeba wcześniej poprawić zewnętrznie; reset i ten
przycisk nie omijają walidacji ani ochrony wersji. Anulowanie przy konflikcie
pokazuje najnowszy poprawny stan utrwalony, nie stary stan z chwili otwarcia.

Zapis dodatkowo porównuje świeży odczyt z treścią z początku edycji, aby
wykryć zmianę nawet przed dostarczeniem zdarzenia watch. Własny zapis jest
rozpoznawany po treści oczekującego dokumentu i potwierdzeniu; jego zdarzenia
watch nie powodują konfliktów ani kolejnych zapisów. Zapis identycznej
zawartości kończy się po świeżym odczycie bez zmiany pliku.

Ochrona konfliktu jest optymistyczna. FileView nie oferuje atomowej operacji
„zapisz tylko, jeśli plik jest nadal taki sam” ani blokady respektowanej
przez zewnętrzne edytory. Porównanie przed zapisem i kontrola po nim nie
usuwają wąskiego wyścigu z równoczesnym, niezależnym pisarzem między
odczytem a podmianą pliku. Nie deklarujemy transakcji między aplikacjami.

## Implementacja i potwierdzone API

- `core/Settings.qml` jest pojedynczym modelem w korzeniu, z jawnym adapterem
  storage. Czyste Qt umożliwia testowanie wejścia i opóźnionych potwierdzeń.
- `core/SettingsFile.qml` używa
  [FileView 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/FileView/)
  z `atomicWrites`, `saved`, `saveFailed`, `fileChanged` i `reload`.
  Sekwencja to odczyt → porównanie → zapis → odczyt kontrolny. Brak `Process`.
- [Implementacja FileView 0.3.1](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/io/fileview.cpp)
  sama tworzy katalogi. W tej wersji emituje sygnały przed wyzerowaniem
  bieżącej operacji, pomija identyczne `setText` i jedynie loguje nieudany
  `QSaveFile.commit()`. Dlatego kolejne operacje są odroczone przez
  `Qt.callLater`, a `saved` wymaga dodatkowego odczytu kontrolnego.
- Obsługiwane błędy FileView trafiają do UI; nie wyciszamy diagnostyki QML
  ani importów. Testy zachowują dokładny komunikat inotify przy chmod(000).
- Pole bazuje na [TextField Qt 6.11](https://doc.qt.io/qt-6.11/qml-qtquick-controls-textfield.html),
  edycja na `textEdited` z [TextInput](https://doc.qt.io/qt-6.11/qml-qtquick-textinput.html),
  przyciski na standardowym `AbstractButton`. Produkcyjne widoki nie znają
  ścieżek konfiguracji ani poleceń systemowych.

Testy, komendy i ograniczenia środowiska: [testing.md](testing.md),
[dowody etapu](evidence/03-appearance.md), [status](status.md).
