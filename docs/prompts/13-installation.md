# Etap 13 — Instalacja, przełączenie i rollback

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 13; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etap 12: zaakceptowany technicznie kandydat z wykonanymi obowiązkowymi kryteriami. Etap 11 nieobowiązkowy.

**Cel:** Przenośny, sprawdzony sposób instalacji i przełączenia z poprzedniego shella.

## Materiały

docs/validation.md, docs/session.md, docs/notifications.md oraz rzeczywisty układ konfiguracji sesji. Ze starego scripts/install i tests/test_install.py adaptuj staging/backup/rollback, bez domyślnego pacman -Syu.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Zbuduj mały instalator użytkownika: --dry-run, --destination do testów, staging, walidacja paczki, kopia poprzedniej wersji i --restore. Kompletny runtime publikuj atomowo: dobierz sprawdzoną operację na katalogach albo niezmienne wersjonowane katalogi i atomową zmianę wskazania. Nie podmieniaj plików aktywnej instalacji pojedynczo; sprawdź reakcję auto-reloadu Quickshella i opisz ewentualny kontrolowany restart. Kopiuj tylko zasoby runtime, nie testy, plany, .git i prywatne ustawienia.

2. Zachowaj oddzielny namespace Putkin dla konfiguracji, danych i stanu. Nigdy nie nadpisuj settings.json przy zwykłej aktualizacji ani nie importuj automatycznie ustawień quickshell-de. Nie zapisuj ścieżek tej maszyny w wersjonowanym kodzie.

3. Sprawdzaj małą listę zależności wymaganych i osobno opcjonalnych. Podaj polecenia/braki, bez automatycznej instalacji pakietów i aktualizacji systemu. Wybierz lokalizację zgodną z wykrywaniem konfiguracji Quickshella: istniejący nadrzędny shell.qml może wpływać na nazwaną konfigurację, więc launch może wymagać jawnego --path.

4. Przygotuj dokładny plan autostartu i skrótów dla wykrytej wersji Hyprlanda/sesji, z odwracalną zmianą w konkretnych plikach. Zapewnij jedną instancję Putkin i jednego właściciela serwera powiadomień. Nie używaj szerokiego pkill ani automatycznego usuwania poprzedniej instalacji.

5. Sprawdź pełną instalację i rollback w katalogu tymczasowym, również update istniejącego celu, błąd kopiowania/checków, przerwanie także w momencie publikacji paczki i ścieżkę ze spacjami. Widoczny runtime musi pozostać kompletną starą albo kompletną nową wersją, a ustawienia użytkownika nienaruszone.

6. Po wykonaniu powyższego przedstaw konkretny zestaw zmian do aktywacji na pulpicie. Jeżeli użytkownik już ją autoryzował, wykonaj ją w tym zakresie; w przeciwnym razie potrzebna jest decyzja wyłącznie o tym ostatnim kroku. Nie zatrzymuj przygotowania i testów w oczekiwaniu na taką decyzję.

7. Po autoryzowanej aktywacji sprawdź pasek, settings, brak konfliktu powiadomień i brak drugiej instancji; w razie błędu użyj przygotowanego rollbacku. Nie wywołuj restartu/wylogowania/locka tylko jako testu poprawności instalacji.

## Odbiór

- Testy instalatora przechodzą w /tmp i nie polegają na wcześniej zbudowanych, nieudokumentowanych bibliotekach.
- Dry-run nie zmienia celu; uszkodzona paczka jest odrzucona; rollback odtwarza poprzedni runtime i nie kasuje ustawień.
- Rozróżnij wynik „instalator przetestowany” od „nowy shell aktywny na pulpicie”; oba mają osobną pozycję w raporcie.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

scripts/install, testy, docs/install.md z backupem/rollbackiem oraz jednoznaczny status wdrożenia. To ostatni etap bazowej roadmapy.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
