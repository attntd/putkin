# Etap 03 — Ustawienia wyglądu i edycja akcentów

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 03; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–02: Theme/Metrics, pasek, otwieranie paneli i widok ustawień.

**Cel:** Użytkownik zmienia kolory w interfejsie, widzi je od razu i zachowuje po restarcie.

## Materiały

docs/design.md, sekcja kolorów. Ze starego repo: core/Settings.qml, tests/test_settings_validation.py i test_settings_stability.py; zachowaj odporność, ogranicz schemat.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Zbuduj mały Settings z schemaVersion, appearance.accent, appearance.accentSecondary. Ustawienia przechowuj w ${XDG_CONFIG_HOME:-$HOME/.config}/putkin/settings.json. Pierwszy zapis musi utworzyć także brakujący katalog aplikacji, z obsługą błędu tej operacji. Nie importuj ustawień quickshell-de.

2. Utwórz stronę Wygląd: próbki Mauve/Pink/Blue/Lavender/Peach/Teal, pole #RRGGBB dla obu akcentów, Zapisz, Anuluj i Przywróć domyślne. Opcja ograniczania ruchu została usunięta 2026-09-20; istniejący boolean reducedMotion jest ignorowany przy odczycie i pomijany przy zapisie. Czytelna nawigacja klawiaturą, etykiety i błąd przy niepoprawnym polu.

3. Oddziel utrwalony stan od roboczego podglądu. Zmiana działa na wszystkich monitorach i otwartych kontrolkach. Anulowanie przywraca stan utrwalony. Każde zamknięcie bez udanego zapisu — Escape, kliknięcie poza panelem, zastąpienie inną powierzchnią, hotplug lub reload — również odrzuca podgląd. Reset dotyczy edytowanej wersji; zapis jest jawną osobną akcją.

4. Połącz semantyczne tokeny Theme z efektywnymi ustawieniami. Dobieraj onAccent z czytelnego jasnego/ciemnego wariantu. Nie zmieniaj znaczenia success/warning/error i nie używaj koloru jako jedynego wskaźnika fokusu lub stanu.

5. Użyj walidacji przed zastosowaniem, jednego źródła defaults oraz atomowego zapisu FileView z obsługą saved/saveFailed. Nie nadpisuj uszkodzonego pliku automatycznie; zachowaj ostatni poprawny stan i pokaż problem.

6. Obsłuż brak pliku, zły JSON, złą wersję, błąd zapisu, własne zdarzenia watch/reload oraz zewnętrzną edycję przy otwartym formularzu. Przy konflikcie nie nadpisuj zmian po cichu. Nowszego, nieobsługiwanego schematu nie zapisuj starszym formatem.

7. Zapisz config/settings.example.json, opis schematu i zachowania w docs/settings.md. Dodawaj tylko istniejące opcje, bez edytora wszystkich metryk i layoutu paska.

## Odbiór

- Presety i własny HEX: podgląd, anulowanie przyciskiem i wszystkimi ścieżkami zamknięcia, zapis, reset i restart; jasny oraz bardzo ciemny akcent mają czytelny tekst.
- Rzeczywisty odczyt/zapis pliku w tymczasowym XDG, pierwszy zapis bez całego katalogu putkin, malformed JSON, błąd uprawnień, zewnętrzna zmiana podczas edycji i brak pętli zapisu.
- 20 zmian/reloadów bez niszczenia otwartego panelu lub jego fokusu. Sprawdź, że zapis sukcesu następuje dopiero po potwierdzeniu.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Działające ustawienia wyglądu, dynamiczne tokeny, mały format konfiguracji i testy trwałości. Odbiór etapu 03 ma zawierać dwa zrzuty tego samego widoku z różnymi akcentami.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
