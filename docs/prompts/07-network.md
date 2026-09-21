# Etap 07 — Sieć i zwykłe Wi-Fi

Aktualizacja zakresu wybrana przez użytkownika 2026-09-19:
Quick Menu ma tylko kafelki radia, a zarządzanie Wi-Fi/Bluetooth znajduje
się w osobnych modułach paska. DND przeniesiono do centrum powiadomień
z historią wyłącznie w pamięci sesji (do 100 rekordów, bez transient).
Obowiązuje [aktualny kontrakt](../design.md), który zastępuje poniższe
historyczne wymagania o listach i DND w Quick Settings oraz braku centrum.

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 07; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–03: współdzielone usługi, Quick Settings i ustawienia. Zalecana kolejność po 06.

**Cel:** Status połączenia oraz podstawowa obsługa Wi-Fi bez własnego edytora sieci i pluginu C++.

## Materiały

Obraz (3), pionowy wiersz Wi-Fi. Ze starego repo wybierz wyłącznie potrzebne części services/NetworkService.qml i modules/network/NetworkNearby.qml; pomiń NetworkManagerNative.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Utwórz adapter Quickshell.Networking: urządzenia, Ethernet, stan Wi-Fi, hardware block, połączenie aktywne, dostępność sieci/internetu i błąd akcji. Nie zakładaj, że połączenie z AP oznacza dostęp do internetu.

2. Pasek konsumuje ten sam model co wiersz Wi-Fi w Quick Settings. Dodaj przełącznik radia i jawną metodę adaptera włącz/wyłącz Wi-Fi, z potwierdzeniem rzeczywistego stanu backendu. Rozwinięcie pokazuje dostępne sieci, siłę sygnału, zabezpieczenie i stan łączenia; etykiety SSID traktuj jako tekst.

3. Uruchamiaj żądania skanowania tylko dla widocznej listy. Zamknięcie panelu, wyłączenie radia, utrata adaptera i zniszczenie widoku zwalniają własne żądanie; pasek nie skanuje sieci.

4. Obsłuż połączenie otwarte/zapisane, rozłączenie oraz nowe zwykłe Wi-Fi PSK. W wersji 0.3.1 istnieje WifiNetwork.connectWithPsk dla odpowiednich typów zabezpieczeń; potwierdź sygnatury wersji zainstalowanej przed użyciem. Najpierw wykorzystaj zapisane połączenie, pytaj o hasło gdy potrzebne.

5. Hasło żyje tylko w polu/operacji i trafia do natywnego backendu, nie argv, logów ani settings.json. Czyść je po anulowaniu/końcu; odrzucaj wyniki starej operacji po zmianie sieci.

6. VPN, enterprise i edycję profili obsłuż jawnym wejściem do opcjonalnego istniejącego edytora. Brak takiego programu pokaż czytelnie. Nie emuluj tych funkcji pustymi przyciskami i nie przenoś całego okna NetworkSettings.

## Odbiór

- Brak NetworkManager, brak Wi-Fi, radio off → włączenie → lista sieci, wyłączenie podczas skanowania, hardware rfkill bez pozornego sukcesu, Ethernet+Wi-Fi, captive portal/nieznany internet, pusta lista, duplikaty/nietypowy SSID.
- Otwarte/zapisane/PSK, błędne hasło, timeout, anulowanie i przełączenie celu; brak sekretów w plikach i logach.
- Na atrapach potwierdź zwolnienie skanowania po każdym sposobie zamknięcia. Rzeczywiste łączenie Wi-Fi raportuj oddzielnie od testów UI.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Cienki adapter sieci, wskaźnik, sekcja Wi-Fi z hasłem PSK, testy i opis granic funkcji. Sam pasek nie może wymagać własnej biblioteki NetworkManagerNative.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
