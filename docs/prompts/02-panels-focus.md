# Etap 02 — Quick Settings, okna i fokus

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 02; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–01: pasek z kontekstem monitorów i wspólne kontrolki.

**Cel:** Stabilne otwieranie jednego kompaktowego panelu oraz podstawa pod ustawienia.

## Materiały

Obraz (3), pole Quick Settings. Ze starego repo: components/PopupLoader.qml i KeyboardNavigation.qml; nie przenoś całego BarIsland/SurfaceManager.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Dodaj działający przycisk Quick Settings na pasku i niewielki koordynator z jawnymi akcjami otwarcia, przełączenia i zamknięcia. Panel przy prawym brzegu, pod paskiem; osobny widok ustawień można na razie ograniczyć do prawdziwego opisu aktualnego motywu.

2. Domyślnie tylko jeden interaktywny panel w całym shellu. Przełączenie monitora zamyka poprzedni. OSD/toasty nie są częścią tej wyłączności. Otwieranie nieistniejącej powierzchni zwraca błąd zamiast zapisywać pozornie aktywny stan.

3. Użyj właściwego okna i loadera dla Quickshella w zainstalowanej wersji. Ogranicz obie osie panelu do dostępnego ekranu, przy długiej treści zapewnij przewijanie. Stan sekcji i wybranych wierszy pozostaje lokalny.

4. Podstawowa nawigacja jest vimowa: h/j/k/l = lewo/dół/góra/prawo, Enter potwierdza/aktywuje wybraną pozycję. Zachowaj wpisywanie liter w polach tekstowych oraz dodatkowe wejście Qt: Tab/Shift+Tab, strzałki i Spację. Escape zamyka najpierw lokalną rozwiniętą sekcję, potem panel. Przy otwarciu z myszy/IPC fokus trafia w użyteczne miejsce; zamknięcie oddaje go przewidywalnie.

5. Kliknięcie poza panelem zamyka go zgodnie z udokumentowaną polityką wejścia. Wskaźnik active i tooltip przycisku muszą być faktycznie renderowane. Usuń panel po krótkim fade, ale zatrzymaj interakcję i pracę zależną od widoczności od razu; ponowne otwarcie w trakcie zamykania nie może zniszczyć nowego widoku.

6. W produkcyjnym Quick Settings pokazuj tylko zrealizowane funkcje. Docelowy układ z atrapami suwaków może istnieć wyłącznie w wyraźnie testowym podglądzie. Uzupełnij docs/ipc.md.

## Odbiór

- Szybkie open/close/open, 20 cykli, usunięcie monitora z otwartym panelem, otwarcie przez IPC i mysz.
- Panel na małym logicznym ekranie mieści się w obu osiach; fokus pozostaje widoczny i nie ginie w zniszczonym elemencie.
- Rzeczywiste zdarzenia h/j/k/l przenoszą fokus zgodnie z układem, pomijając niedostępne elementy; Enter aktywuje wybraną kontrolkę dokładnie raz. Sprawdź także Enter z klawiatury numerycznej.
- Test ładuje prawdziwy koordynator z jawnymi atrapami, bez tekstowego przepisywania importów i zależności PAM.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Gotowe hostowanie Quick Settings i ustawień, mały koordynator, test fokusu/lifecycle i opis reguł okien. Etap 02 nie implementuje jeszcze audio, sieci ani zasilania.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
