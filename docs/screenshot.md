# Screenshot

Zakres wybrany 2026-09-20. Print Screen i `:screenshot` uruchamiają ten sam
mechanizm na bieżącym monitorze. Nakładka lekko przyciemnia żywy pulpit,
pokazuje celownik i pozwala przeciągnąć prostokąt. Puszczenie myszy pozostawia
zaznaczenie do zatwierdzenia; kolejne przeciągnięcie je zastępuje.

- Enter: zaznaczenie, a bez niego cały monitor.
- W: okno aktywne przed uruchomieniem, także przed otwarciem launchera.
- Escape/Q: anulowanie bez przechwytywania i bez zmiany schowka.
- Podgląd: Enter/F zapisuje PNG do `Pictures/Screenshots` (katalog obrazów
  z ustawień XDG), Escape/Q zamyka. Zapis także zamyka podgląd.

Przed zatwierdzeniem nie powstaje obraz ani proces przechwytujący. Nakładka
znika przed przechwyceniem; nie trafia do PNG. Okno jest wycinane z bieżącego
obrazu pulpitu według zapamiętanego identyfikatora, bez przełączania fokusu.
Zamknięte lub niewidoczne okno powoduje błąd zamiast zrzutu innego okna.

Po przechwyceniu PNG jest kopiowany jako `image/png` do schowka. Podgląd
ma tylko obraz i przyciski Zapisz/Zamknij, bez instrukcji i tooltipów.
Tymczasowy plik należy do prywatnego katalogu XDG_RUNTIME_DIR i znika po
zamknięciu podglądu. Schowek zachowuje własną kopię do zastąpienia zawartości.
Trwały plik powstaje wyłącznie na żądanie zapisu, z unikalną nazwą i prawami
0600. Błąd zapisu pozostawia podgląd do ponowienia; błędy trafiają do
istniejących powiadomień. Blokada sesji zamyka wybór i podgląd.

Jedna sesja przechwytywania naraz. Zmiana układu monitorów podczas wyboru
anuluje operację. Geometria zaznaczenia jest lokalna względem monitora;
adapter przelicza ją na współrzędne Hyprlanda przy zatwierdzeniu, uwzględniając
skalę i obrót. W zachowuje części okna widoczne na różnych monitorach;
przy różnych skalach używa największej skali spośród przecinanych ekranów.
Widoki nie wykonują poleceń systemowych.
