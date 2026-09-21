# Etap 01 — Pasek, workspace i zegar

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 01; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etap 00: działający szkielet, Theme/Metrics, kontrolki, scripts/check i tryb atrap.

**Cel:** Pierwszy użyteczny pasek zgodny z kompozycją referencji.

## Materiały

Obrazy (1) i (2). Kandydaci ze starego repo: modules/statusbar/WorkspacesModule.qml, ClockModule.qml i services/HyprlandService.qml; wykorzystuj tylko potrzebne zachowania.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Zbuduj modules/bar jako jedną pełnoszeroką powierzchnię na górze każdego monitora. Wysokość startowa 32 logiczne px, bez marginesu zewnętrznego i zaokrągleń, z właściwą rezerwacją obszaru przez layer-shell. Środek pozostaje pusty.

2. Utwórz jeden współdzielony adapter Hyprlanda oparty na natywnym modelu zdarzeń. Widoki na wielu monitorach nie tworzą osobnych watcherów ani cyklicznych hyprctl.

3. Po lewej pokaż numery 1–5 oraz udostępnij dodatkowe aktywne/zajęte workspace spoza tego zakresu. Strefa workspace ma ograniczoną szerokość; aktywny numer pozostaje widoczny, a nadmiarowe pozycje są osiągalne przewijaniem lub osobnym wejściem, także klawiaturą. Przyjmij globalną listę numerów, ale aktywność wyróżniaj dla monitora danego paska; osobno pokaż, że workspace jest widoczny na innym monitorze. Kliknięcie wywołuje udokumentowaną akcję kompozytora z kontekstem monitora. Wyjaśnij zachowanie jego przenoszenia zamiast zakładać kopiowanie pulpitu.

4. Rozróżnij stan aktywny, zajęty i pilny także znacznikiem/tekstem. Po prawej umieść zegar i datę według locale; pełna data dostępna w tooltipie. Aktualizacja raz na minutę wystarczy przy braku sekund.

5. Dodaj dostęp z klawiatury i IPC do skupienia paska. Nawigacja jest vimowa: h/j/k/l = lewo/dół/góra/prawo, Enter potwierdza/aktywuje wybrany workspace; na poziomej liście użyj h/l. Zwykły pasek nie przechwytuje klawiatury aplikacji. Udokumentuj akcję w docs/ipc.md. Nie dodawaj martwych ikon przyszłych usług.

6. Zadbaj o wąski ekran: skracaj datę, zachowuj dostęp do workspace i czytelny fokus. Dodanie/usunięcie monitora tworzy/usuwa tylko odpowiadający mu widok.

## Odbiór

- Na atrapach: workspace 1–5, aktywny 9, zajęty 12, pilny, dwie różne aktywne przestrzenie na dwóch monitorach i 30 zajętych numerów. Nadmiar nie wypycha zegara ani miejsca na Quick Settings.
- Kliknięcie oraz nawigacja h/l z potwierdzeniem Enterem wywołują akcję z właściwym celem, także dla workspace w nadmiarze; utrata kompozytora daje stan niedostępny, nie błędny aktywny numer.
- Zrzuty 1920×1080 i 1366×768; test rzeczywistego layer-shell i hotplug w prywatnym compositorze, jeśli dostępny. Oddziel wyniki od scenariuszy niewykonanych.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Pasek i adapter Hyprlanda, dokumentacja reguł workspace/IPC, testy zachowania oraz zapis odbioru etapu 01. Pozostałe statusy przyjdą z własnymi usługami.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
