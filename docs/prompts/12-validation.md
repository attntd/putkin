# Etap 12 — Odbiór funkcjonalny, wygląd i wydajność

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 12; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–10 gotowe do sprawdzenia; etap 11 tylko jeśli wybrany.

**Cel:** Zweryfikowany kandydat pierwszego wydania, z poprawionymi wykrytymi usterkami.

## Materiały

docs/design.md, docs/architecture.md, docs/testing.md, docs/status.md i wyniki dotychczasowych etapów. Audyt poprzednika dostarcza scenariuszy regresji, nie wyników Putkin.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Zbierz faktyczny zakres implementacji i sprawdź podstawową ścieżkę: start → workspace → Quick Settings → zmiana akcentu/zapis → audio/jasność → sieć/BT → toast/DND → anulowanie Power.

2. Uruchom właściwe testy projektu i zdiagnozuj błędy. Usuń wykryte regresje w ramach istniejącego zakresu, zamiast ograniczyć się do listy problemów. Każdy test ma raportować błąd ładowania QML bez maskowania go wtórnym błędem JSON.

3. Sprawdź rzeczywiste renderowanie w kontrolowanym Waylandzie: 1920×1080 i 1366×768, skale 1/1,25/1,5/2, dwa monitory o różnych skalach, otwarte panele przy hotplug, długie teksty i duży tray. Zapisz porównawcze zrzuty bez prywatnych treści.

4. Przejdź wszystko klawiaturą. Sprawdź powrót fokusu, brak przechwytywania go przez OSD/toasty, dostęp do przepełnionego traya i właściwy monitor akcji IPC.

5. Na atrapach sprawdź brak/powrót usług, timeouty, odpowiedzi nie po kolei, zły plik ustawień i reload przy otwartym panelu. Zweryfikuj, że stan niedostępny nie jest udawanym sukcesem.

6. Powtórz pomiar 60 s spoczynku w warunkach bazowych i 20 cykli otwierania paneli. Zapisz CPU/RSS, procesy, aktywne skanowanie i powód każdej pracy w tle; zbadaj utrzymujący się wzrost pamięci. Nie ogłaszaj wyników sprzętowych z samego offscreen.

7. Podziel wynik odbioru na potwierdzone, niewykonane i wymagające naprawy. Brak odpowiedniego compositora/sprzętu nie jest PASS; przygotuj konkretne polecenia/scenariusze do domknięcia tych punktów.

## Odbiór

- Zaliczone wymagane testy, brak nowych błędów QML, zgłoszone wcześniej usterki mają weryfikowalny wynik naprawy.
- Zgodność kompozycji i obu akcentów z docs/design.md; panel mieści się w ekranie, liczba usług nie mnoży się z monitorami.
- Raport nie twierdzi, że sprawdzono hostowy PAM, realny suspend lub sprzęt, jeśli wykonano wyłącznie testy atrap.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

docs/validation.md z warunkami, komendami, wynikami, zrzutami i pozostałymi ograniczeniami; poprawiony kandydat wydania. Etap nie jest zakończony, dopóki obowiązkowe kryteria są niewykonane lub błędne.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.

