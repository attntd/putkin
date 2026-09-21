# Etap 11 — Opcjonalne dopasowanie pulpitu i Night Light

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 11; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–03 i 10. Ten etap jest opcjonalny; pominięcie nie blokuje minimalnego wydania.

**Cel:** Dopasowanie elementów z referencji, którymi zarządzają programy poza Quickshellem.

**Doprecyzowanie użytkownika z 2026-09-16:** tapeta ma być renderowana
bezpośrednio przez opcjonalny moduł Quickshella. Hyprpaper nie jest
zależnością Putkin. Osobny backend dotyczy Night Light, nie tapety.
Aktualny kontrakt: [pulpit](../desktop.md).

## Materiały

Wszystkie cztery obrazy i tabela właścicieli w docs/design.md. Obecne PNG zawierają interfejs i nie są czystymi tapetami.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Sprawdź dostępny backend tapety i temperatury barwowej oraz aktualne wersje/sposób konfiguracji Hyprlanda. Przygotuj mały, jednoznaczny zestaw przykładów dla faktycznie wspieranej wersji. Nie kopiuj składni hyprland.conf z obrazka, jeśli zainstalowana wersja używa innej.

2. Zaproponuj opcjonalny fragment wyglądu kompozytora: ostre rogi, cienka ramka aktywnego okna w domyślnym akcencie, spokojne gaps. Fragment ma dać się włączyć i wycofać oddzielnie, bez zastępowania całej konfiguracji użytkownika.

3. Do tapety użyj czystego zasobu, jeżeli użytkownik go dostarczył. Gdy go brak, przygotuj konfigurację i neutralny fallback oraz odnotuj brak pliku; nie ustawiaj screenshotu z wypalonymi oknami/paskiem. Przygotowanie nowej ilustracji jest osobnym zadaniem, nie warunkiem działania shella.

4. Dodaj opcjonalny Night Light w Quick Settings przy dostępności wybranego backendu, np. hyprsunset. Zweryfikuj jego API i sposób sprawdzenia stanu. Brak backendu nie może pokazywać fikcyjnego przełącznika on/off.

5. Własność procesu Night Light ma być jasna: albo istniejąca usługa użytkownika, albo jeden jawnie zarządzany proces. Nie uruchamiaj drugiego egzemplarza i nie kończ cudzych procesów. Zakres: przełącznik i prosta temperatura, bez geolokalizacji i rozbudowanych harmonogramów.

6. Przykłady Kitty/Fish/Neovim mogą zostać opisane jako oddzielne motywy; Putkin nie rysuje ich pasków tytułu. Podaj, że zmiana akcentu w Putkin automatycznie dotyczy tylko jego UI; synchronizację z zewnętrznymi aplikacjami zostaw na osobne rozszerzenie.

## Odbiór

- Wczytywanie przykładów w kontrolowanej konfiguracji odpowiedniej wersji oraz prosty rollback.
- Night Light na atrapach: backend absent, stan już aktywny, timeout, odmowa, restart i brak drugiego procesu.
- Porównanie pulpitu do referencji tylko z prawdziwą czystą tapetą, jeśli jest dostępna; wymień elementy poza kontrolą shella.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Opcjonalne integracje wyglądu, Night Light i dokumentacja uruchomienia/wycofania. Status etapu może być pominięty bez obniżania kompletności minimalnego shella.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
