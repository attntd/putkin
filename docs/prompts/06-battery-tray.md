# Etap 06 — Bateria i tray

Uwaga po odbiorze: 2026-09-17 użytkownik wybrał osobne rozszerzenie
panelu baterii z procentem, paskiem, czasem i profilami. Dotychczasowe
wyłączenie profili w punkcie 6 opisuje historyczny etap 06; aktualna
adaptacja poprzednika jest opisana w [kontrakcie](../battery-tray.md).

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 06; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–03: pasek, kontrolki, fokus paneli i ustawienia wyglądu. W zalecanej kolejności wykonaj po 05.

**Cel:** Uzupełniony prawy status paska bez dodatkowych ciężkich usług.

## Materiały

Obrazy (1)–(3). Kandydaci poprzednika: services/PowerService.qml, modules/statusbar/BatteryModule.qml i TrayModule.qml.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Podłącz pojedynczy adapter do Quickshell.Services.UPower. Pokazuj właściwą baterię zasilającą komputer, procent, ładowanie i sensowną informację o czasie, jeśli backend ją zna.

2. Nie myl baterii myszy/słuchawek z baterią komputera. Brak głównej baterii usuwa jej element z paska. Ostrzeżenie ma tekst/ikonę oraz kolor semantyczny niezależny od akcentu.

3. Dodaj SystemTray z poprawną aktywacją, secondary activation i menu tam, gdzie dostarcza je aplikacja. Korzystaj z natywnego modelu i DBusMenu według dokumentacji wersji.

4. Przyciski traya muszą być dostępne klawiaturą, mieć nazwy i prawdziwe tooltipy. Menu otwiera się na monitorze właściwego przycisku i mieści się na ekranie. Menu i overflow traya uczestniczą w regule jednej interaktywnej powierzchni: otwarcie zamyka Quick Settings/inny panel, a podmenu pozostaje częścią tej samej rodziny menu.

5. Ogranicz szerokość traya i dodaj czytelne wejście do nadmiarowych ikon. Nie pozwól, żeby wiele aplikacji wypchnęło workspace, zegar lub Quick Settings poza ekran.

6. W Quick Settings wystarczy krótki stan baterii. Profile zasilania, szczegółowe wykresy, szacunki własnym algorytmem i rozbudowane okno baterii nie należą do tego etapu.

## Odbiór

- Bateria absent/charging/discharging/full/unknown i urządzenia peryferyjne; brak UPower i powrót usługi.
- Fikcyjny klient traya na prywatnym D-Bus: aktywacja, menu/podmenu, zastąpienie Quick Settings, usunięcie elementu z fokusem, brak ikony i kilkanaście pozycji.
- Wąski ekran i duża skala: główne funkcje paska nadal dostępne; zmiana akcentu nie odbiera znaczenia ostrzeżeniu baterii.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Bateria i tray w docelowej kompozycji paska, testy ze sztucznymi modelami/klientem, zrzuty i opis ograniczeń.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
