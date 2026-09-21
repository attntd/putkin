# Etap 08 — Podstawowy Bluetooth

Aktualizacja zakresu wybrana przez użytkownika 2026-09-19:
Quick Menu ma tylko kafelki radia, a zarządzanie Wi-Fi/Bluetooth znajduje
się w osobnych modułach paska. DND przeniesiono do centrum powiadomień
z historią wyłącznie w pamięci sesji (do 100 rekordów, bez transient).
Obowiązuje [aktualny kontrakt](../design.md), który zastępuje poniższe
historyczne wymagania o listach i DND w Quick Settings oraz braku centrum.

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 08; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–03: Quick Settings i cykl życia sekcji; etap 07 daje wspólny wzorzec list i błędów.

**Cel:** Włączanie Bluetooth oraz wygodne połączenia z już sparowanymi urządzeniami.

## Materiały

Obraz (3). Kandydaci: services/BluetoothService.qml oraz moduły listy urządzeń poprzednika; nie importuj BluetoothNative w podstawowym adapterze.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Utwórz mały adapter Quickshell.Bluetooth do BlueZ: dostępność, wybrany adapter, radio, lista już sparowanych urządzeń, stan połączeń i błędy. Obsłuż więcej niż jeden adapter jasną regułą wyboru.

2. Zbuduj pionowy wiersz i rozwijaną listę w Quick Settings. Radio, connect/disconnect, nazwa urządzenia, czytelny stan oczekiwania i opcjonalna bateria urządzenia, jeśli dostępna.

3. Nie uruchamiaj discovery do samego wyświetlenia już sparowanych urządzeń. Jeśli implementacja wykorzystuje discovery, przyznaj własność widocznej liście i zwolnij ją przy każdym zamknięciu, błędzie i hot reload.

4. Dodaj jawny przycisk „Sparuj nowe urządzenie…” otwierający istniejący menedżer, jeśli jest dostępny. Opisz przejście do zewnętrznego programu; brak programu jest obsłużonym stanem. W tym etapie nie implementuj własnego agenta PIN/passkey ani procedur usuwania kluczy.

5. Traktuj zmianę radia/połączenia jako żądanie do backendu; nie pokazuj sukcesu przed potwierdzeniem. Spóźniona odpowiedź starej akcji nie może zmienić nowego wyboru.

6. Zapewnij klawiaturę, etykiety, pełne nazwy w tooltipie i stabilny fokus podczas aktualizacji listy. Zachowaj wyraźny podział baterii peryferium i baterii systemowej.

## Odbiór

- Brak BlueZ, brak adaptera, radio off, kilka adapterów, lista pusta, połączenie odrzucone, utrata urządzenia i restart usługi.
- Na atrapach connect/disconnect i szybkie przełączanie nie produkują sprzecznego stanu ani stale aktywnego skanowania.
- Zewnętrzny menedżer dostępny/niedostępny, bez automatycznego instalowania pakietów. Testy nie parują rzeczywistych urządzeń.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Podstawowy Bluetooth w Quick Settings z testami i opisem przejścia do parowania. Pełne parowanie wewnątrz Putkin pozostaje świadomie odrębnym rozszerzeniem.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.

