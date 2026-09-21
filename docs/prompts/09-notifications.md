# Etap 09 — Powiadomienia i DND

Aktualizacja zakresu wybrana przez użytkownika 2026-09-19:
Quick Menu ma tylko kafelki radia, a zarządzanie Wi-Fi/Bluetooth znajduje
się w osobnych modułach paska. DND przeniesiono do centrum powiadomień
z historią wyłącznie w pamięci sesji (do 100 rekordów, bez transient).
Obowiązuje [aktualny kontrakt](../design.md), który zastępuje poniższe
historyczne wymagania o listach i DND w Quick Settings oraz braku centrum.

## Kontekst

Pracujesz w repozytorium Putkin (`/home/attntd/projects/putkin` w środowisku audytu). Budujesz minimalistyczny shell **Quickshell/QML dla Hyprlanda**: pełny górny pasek, pusty środek, nieprzezroczyste Mocha, kwadratowe rogi i akcenty zmieniane w UI. Zaimplementuj etap 09; nie jest to prośba o kolejną roadmapę.

Przeczytaj istniejące `AGENTS.md`, `docs/design.md`, `docs/architecture.md` i `docs/status.md`. Dokumenty są częścią danych wejściowych tego promptu; historia rozmowy nie jest potrzebna. Zweryfikuj stan kodu, zamiast polegać wyłącznie na oznaczeniu etapu jako zakończonego.

**Zależności:** Etapy 00–03: Theme, kontrolki, izolowane testy i Quick Settings. Zalecana kolejność po 08.

**Cel:** Proste toasty zgodne z referencją i jeden prawidłowy serwer powiadomień.

## Materiały

Obrazy (2) i (3), powiadomienia. Kandydaci poprzednika: services/NotificationService.qml i modules/notifications; zachowaj protokół, nie kopiuj trwałej historii ani inline replies.

Poprzedni projekt `../putpuccin` jest opcjonalnym źródłem do odczytu. Jeśli jest niedostępny, korzystaj z audytu i API; nie uzależniaj nowego kodu od obecności tego katalogu. Historyczne wymagania poprzednika nie rozszerzają zakresu Putkin.

## Zadanie

1. Zaimplementuj pojedynczy NotificationServer i adapter oddzielony od widoków per monitor. W trybie testowym korzystaj z prywatnego D-Bus; przed rzeczywistą aktywacją wykrywaj istniejącego właściciela org.freedesktop.Notifications.

2. Toast: nieprzezroczysty prostokąt, ikona, aplikacja, tytuł, treść, czas i zamknięcie, cienka ramka akcentu. Górny prawy róg poniżej paska. Długi tekst i obrazy ograniczaj do rozmiaru ekranu; nie renderuj dowolnego HTML z nadawcy.

3. Obsłuż wymagane życie obiektów Notification, zastąpienie po ID, akcje, odróżnienie expire/dismiss, resident/transient, domyślny timeout i timeout wymagający pozostawienia. Ogłaszaj tylko faktycznie zaimplementowane capabilities.

4. Ustal jeden monitor odbioru nowego toasta, np. monitor skupiony w momencie nadejścia. Nie duplikuj wszystkich powiadomień na wszystkich ekranach; po hotplug przekieruj/zamknij widok według opisanej reguły.

5. Dodaj przełącznik DND w Quick Settings: zwykłe toasty wyciszone, krytyczne zgodnie z jasno opisaną regułą. Brak historii w pierwszej wersji oznacza też brak późniejszego odtwarzania wyciszonej kolejki. Nie zapisuj treści na dysku.

6. Ustaw ograniczenia widocznych toastów i kolejki w pamięci oraz deterministyczną politykę przepełnienia i reloadu. Widoki nie przejmują fokusu przy nadejściu; akcje są osiągalne przez świadome wejście z klawiatury/IPC.

7. Przygotuj instrukcję późniejszej migracji/rollbacku serwera. Nie zatrzymuj działającego mako/dunst/SwayNC ani starego shella w ramach implementacji i testów.

## Odbiór

- Rzeczywisty klient protokołu na prywatnym busie: create/replace/actions/expire/dismiss, brakujące dane i powrót klienta.
- Timeout domyślny/0, resident, transient, DND, krytyczne, długa treść, duży obraz, zalew zdarzeń oraz reload.
- Żadnych zapisanych treści i konfliktu nazwy na busie hosta. Toast i jego zamknięcie nie gubią fokusu wcześniejszej aplikacji.

Uruchom `scripts/check` oraz testy odpowiednie do zmiany opisane w `docs/testing.md` (w 00 utwórz te narzędzia). Testy mają weryfikować zachowanie, nie tylko obecność tekstu w źródle. Nie uruchamiaj drugiego pełnego shella na magistralach aktywnego pulpitu. Korzystaj z atrap, prywatnych XDG i kontrolowanego Waylanda/D-Bus; nie dotykaj sprzętu ani PAM w testach bez takiej izolacji, jakiej one rzeczywiście wymagają. Przed użyciem API sprawdź oficjalną dokumentację pasującą do lokalnej wersji.

## Wynik sesji

Serwer, toasty, DND, testy protokołu/układu i opisana migracja w docs/notifications.md. Pełne centrum i trwała historia nie są częścią tego etapu.

Zaktualizuj `docs/status.md`: pliki, polecenia, rzeczywiste wyniki i niewykonane kryteria. W podsumowaniu podaj widoczny efekt, sposób sprawdzenia oraz istotne ograniczenia. Małe braki zależności uzupełnij w zakresie potrzebnym do etapu; nie zastępuj brakujących funkcji atrapami w produkcyjnym UI i nie oznaczaj niepełnego odbioru jako zakończony.

