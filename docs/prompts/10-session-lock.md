# Etap 10 — Menu sesji, natywna blokada i bezczynność

## Aktualny zakres wybrany przez użytkownika — 2026-09-20

Zastąpić Hyprlock i Hypridle w jednym procesie Quickshell: WlSessionLock,
PamContext (hasło i odcisk), IdleMonitor, logind, blokada przed snem,
inhibitory aplikacji i Caffeinate. Zachować progi 180/300/360/900 s i
wygląd blokady. Pełny restart odraczać do odblokowania. Sprawdzić błędne
uwierzytelnianie, brak usług, hotplug, reload, potwierdzenie secure przed
suspend i zachowanie inhibitorów. Testy używają atrap i prywatnego
Waylanda/D-Bus oraz izolowanego PAM; nie uwierzytelniają hosta.
Automatyczny sen zachowuje SuspendThenHibernate z dotychczasowej konfiguracji.

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 10; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–05: koordynator, ustawienia, panel oraz refresh() adaptera jasności. Zalecana kolejność po 09; PAM i logind są zależnościami środowiska.

**Cel:** Menu Power, blokada i bezczynność w jednej instancji Quickshell.

## Materiały

Obraz (3), pola Lock Screen i Power Menu. W poprzedniku przeczytaj services/SystemActions.qml i scripts/lock-screen dla zrozumienia potwierdzenia blokady, bez uzależniania Putkin od jego kodu.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Dodaj w Quick Settings akcje Blokada, Ustawienia i Zasilanie. Power menu: Wyloguj, Uruchom ponownie, Wyłącz, Uśpij, z nazwami/ikonami, klawiaturą i osobnym potwierdzeniem działań kończących pracę.

2. Adapter sesji wykrywa dostępne możliwości i obsługuje odmowę/timeout. Działania wywołuje przez sprawdzony interfejs sesji/logind z listami argumentów; uwzględnij rzeczywistą konfigurację Hyprland/uwsm, nie zgaduj komendy wylogowania. Jest również właścicielem zweryfikowanego zdarzenia wznowienia; podłącz do niego refresh() adaptera jasności z etapu 05.

3. Blokadę zapewnia WlSessionLock z powierzchnią na każdym ekranie, polem Qt i PamContext hasła/odcisku. Nie używaj PanelWindow jako blokady. Wynik PAM obowiązuje tylko w bieżącym cyklu przy secure; hasło nie trafia do IPC, dysku ani logów.

4. Zdefiniuj integrację lock-before-suspend zgodną z wersjami Quickshell/logind. Gotowość blokady musi wynikać z udokumentowanego potwierdzenia protokołu/integracji, nie z PID, exit 0 IPC ani stałego opóźnienia. Nie twórz własnego obserwatora C++ zanim sprawdzisz istniejącą drogę backendu.

5. Jeśli nie można potwierdzić bezpiecznej kolejności, nie włączaj w produkcie pozornie bezpiecznego sleep; pokaż konkretny brak konfiguracji i zakończ pozostałą implementację. Brak uprawnień do operacji ma być widoczny przy akcji.

6. Zachowaj wygląd blokady: ostre rogi, Mocha, przyciemniona tapeta, zegar, data i pole hasła z glifem odcisku. Dodaj IdleMonitor z progami 180/300/360/900 s i obsługą inhibitorów. Automatyczny reload wyłącz podczas blokady, pełny restart dopuszczaj po odblokowaniu. Przy przełączeniu wyłącz Hypridle, zachowując odwracalną kopię konfiguracji.

7. Udokumentuj IPC i szablon skrótów; operacje sesji testuj na atrapach z rejestrem wywołań, bez wylogowania, uśpienia i rozmowy z hostowym PAM.

## Odbiór

- Anulowanie potwierdzenia nie wykonuje akcji; sukces/błąd/timeout mają jednoznaczny wynik i brak podwójnego wywołania.
- Fake backend: lock requested → lock confirmed → suspend. Brak potwierdzenia i opóźniony wynik nie uruchamiają suspend. Zdarzenie wznowienia odświeża jasność przez istniejący adapter.
- Menu obsługiwane klawiaturą, powrót fokusu i hotplug. Rzeczywisty test blokady tylko w świadomie wybranej sesji testowej; sam prywatny D-Bus/Wayland nie izoluje PAM.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Menu sesji, natywna blokada/PAM/idle, adapter logind, testy Qt/D-Bus/Waylanda i docs/session.md. Odróżnij gotowość kodu od niewykonanej walidacji na rzeczywistej sesji.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.
