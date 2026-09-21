# Etap 00 — Fundament i bezpieczne środowisko pracy

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 00; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Brak. Repo zawiera referencje oraz dokumentację planu; nie zakładaj istnienia kodu shella.

**Cel:** Uruchamialny, mały szkielet Quickshell z tokenami wyglądu i powtarzalnym podglądem na atrapach.

## Materiały

Obejrzyj cztery PNG z katalogu głównego. W poprzednim projekcie opcjonalnie przeczytaj shell.qml, core/Theme.qml, core/Metrics.qml i scripts/test-static; audyt opisuje błąd tego ostatniego.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Sprawdź Quickshell, Qt, Hyprland oraz dostępność modułów QML i narzędzi Qt. Zapisz wersje i sposób uruchamiania w docs/development.md. Punktem odniesienia audytu były Quickshell 0.3.1, Qt 6.11.2 i pakiet Hyprland 0.56.2; nie zakładaj tych wersji bez sprawdzenia.

2. Utwórz cienki shell.qml, minimalne qmldir/importy, core/Theme.qml i Metrics.qml oraz demonstracyjny widok. Domyślnie Mocha, accent #cba6f7, accentSecondary #89b4fa, rogi 0, nieprzezroczyste tła, font monospace. Referencje nie są teksturami produkcyjnymi. Na tym etapie kolory mogą mieć wartości domyślne; zapis i edytor dojdą w 03.

3. Przygotuj jeden mały zestaw kontrolek rzeczywiście użytych przez podgląd: przycisk, przycisk ikony, ramka, suwak. Zachowaj wejście Qt Quick Controls, semantyczne kolory, tooltip, nazwę dostępności i widoczny fokus.

4. Utwórz scripts/check z kontrolą składni i rozwiązywania importów. Agreguj kody błędów, odróżniaj brak narzędzia od sukcesu; nie kopiuj find -exec ze starego skryptu. Dodaj test bramki na celowo błędnym QML w katalogu tymczasowym.

5. Przygotuj udokumentowany tryb podglądu/testowania z atrapami i odrębnymi XDG. Nie importuj w nim usług PAM, powiadomień hosta ani sprzętu. Opisz oddzielnie renderer offscreen i prywatny compositor; offscreen nie dowodzi poprawności layer-shell.

6. Utwórz krótkie AGENTS.md z linkami do aktualnych kontraktów oraz .gitignore dla artefaktów i prywatnych danych, bez ignorowania docs, promptów i zasad. Jeśli metadane .git są niedostępne, zgłoś to zamiast twierdzić, że dokumenty zostały zacommitowane.

## Odbiór

- Podgląd ładuje się bez nowych błędów QML. Zrzut pokazuje kwadratowe kontrolki i czytelny fokus.
- Błędny plik QML daje niezerowy kod scripts/check; poprawna próbka przechodzi. Test nie zmienia źródeł.
- Udokumentuj bazowy pomiar 60 s spoczynku (RSS, CPU, procesy, warunki) dla dostępnego trybu. Brak prawdziwego Waylanda wpisz jako niezweryfikowany zakres.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Działający szkielet i podgląd, scripts/check, instrukcja testowania w docs/testing.md, faktyczne wersje oraz wpis etapu 00 w docs/status.md. Nie buduj jeszcze usług i paneli kolejnych etapów.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.

