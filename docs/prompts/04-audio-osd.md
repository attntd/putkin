# Etap 04 — Audio i OSD głośności

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 04; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–03: pasek, Quick Settings, adaptery przez jawne właściwości, konfigurowalny Theme.

**Cel:** Regulacja wyjścia audio z paska, panelu i skrótów korzysta z tego samego stanu.

## Materiały

Obrazy (2) OSD i (3) Quick Settings. Kandydaci: services/AudioService.qml, services/OsdService.qml, modules/osd/LevelOsd.qml; nie kopiuj dużego miksera.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Utwórz jeden adapter do Quickshell.Services.Pipewire, z wymaganym śledzeniem obiektów audio według wersji API. Stan: dostępność, domyślne wyjście, poziom, mute, lista wyjść i błąd operacji.

2. Dodaj ikonę audio na pasku, pionową sekcję Quick Settings z suwakiem 0–100%, mute i prostym wyborem wyjścia. Wywołania to metody adaptera; nie ustawiaj sprzętu bezpośrednio z kontrolek.

3. Dodaj IPC zmiany poziomu i mute oraz udokumentuj skróty jako przykład konfiguracji, bez zmieniania konfiguracji sesji użytkownika. Odczyt poziomu ma pochodzić z modelu, nie cyklicznego wpctl.

4. Zbuduj wspólny host OSD i widok poziomu: prostokąt, ikona, liczba i pasek w Theme.accent. Timeout odnawiany przy kolejnych zmianach, jedno aktualne OSD, bez fokusu i rezerwacji obszaru.

5. OSD pokazuj dla własnych komend użytkownika i ustalonego sygnału zmiany, bez komunikatu przy samym starcie usługi. Jeśli panel już pokazuje tę regulację, unikaj dublowania przeszkadzającego w interakcji. Zapisz politykę monitora i zdarzeń.

6. Zanik urządzenia, zmiana domyślnego wyjścia i restart backendu muszą aktualizować panel oraz pasek. Stan sprzętu jest źródłem prawdy; nie utrzymuj fikcyjnego sukcesu po błędzie. Zachowaj hot reload i zamykanie loadera OSD.

## Odbiór

- Zatrzymany/nieobecny PipeWire, brak sinka, zmiana sinka, mute, 0/100%, serie zmian i aktualizacja poziomu spoza widoku.
- Na atrapach udowodnij wspólność stanu paska/panelu/OSD i odrzucanie niepoprawnych wartości.
- OSD nie zabiera fokusu aplikacji, znika po timeout i zmienia barwę razem z ustawieniami. Realnego audio nie zmieniaj testem bez odpowiedniego środowiska.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Adapter audio, sekcja panelu, wskaźnik paska, OSD, IPC i testy. Pomiar po dodaniu stale działającej usługi w tych samych warunkach co baza.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.

