# S01 — Proces usługi i transport

## Kontekst i stałe wymagania

Pracujesz nad **Putkin**, istniejącym shellem Quickshell/QML dla Hyprlanda, w
`/home/attntd/projects/putkin`. Wykonaj wskazany etap integracji Signala;
to zadanie implementacyjne, nie prośba o nowy plan. Nie potrzebujesz historii
rozmowy. Czytaj `AGENTS.md`, aktualne `docs/design.md`,
`docs/architecture.md`, `docs/development.md`, `docs/testing.md`
oraz `docs/signal/ROADMAP.md` i `docs/signal/STATUS.md`.
Po S00 czytaj także `docs/signal/CONTRACTS.md`, `docs/signal/API.md`
oraz `docs/signal/TESTING.md`.
Dokumenty są wejściem do tego samowystarczalnego promptu; sprawdź też kod.
Nie odtwarzaj wcześniejszych etapów tylko dlatego, że sesja jest nowa.

Użytkownik chce rozmów w natywnym interfejsie shella, opartych na
**signal-cli jako urządzeniu połączonym z telefonem**. Nowe wiadomości
synchronizują się telefon ↔ komputer od sparowania; import wcześniejszej
historii nie jest wymagany. Telefon pozostaje urządzeniem głównym.
Historia, szkice i stan wysyłania są własnością lokalnej usługi Putkina.

Obowiązujące decyzje produktowe:
- **Catppuccin Mocha**, istniejące `Theme`/`Metrics` i żywa reakcja na
  podgląd, zapis oraz anulowanie zmiany obu akcentów w ustawieniach shella.
  Zachowaj wspólny gradient powierzchni, kwadratowe rogi, Material Symbols,
  fokus klawiatury i fade z aktualnego kontraktu. Bez osobnej palety Signala.
- **Usługa działa razem z shellem**: start i stop należą do Putkina.
  Zamknięcie okna rozmów nie zatrzymuje odbioru; zatrzymanie shella kończy
  jego bridge i proces signal-cli. Dane przetrwają restart. Reload nie może
  tworzyć drugiego odbiorcy. Usypianie i blokada nie oznaczają wyłączenia konta.
- Powiadomienie Signala pozwala **otworzyć okno właściwej rozmowy**
  i **odpowiedzieć wewnątrz powiadomienia**. Korzystaj z istniejącego
  `NotificationService`; nie uruchamiaj drugiego serwera powiadomień.
  Odczyt centrum powiadomień nie jest odczytem rozmowy.

Widoki nie uruchamiają poleceń. Przekazuj usługi jawnie, nie rozbudowuj
`shell.qml` o logikę domenową. W polach tekstowych hjkl pozostają literami.
Nie dodawaj tooltipów ani tekstów instruktażowych. Nowe wymagania Signala
zastępują wcześniejszy zakaz inline reply dla tej integracji.

Edytuj źródła, nie `~/.config/quickshell` ani opublikowane wydania.
Do S11 pracuj bez aktywowania zmian na pulpicie; S12 obejmuje wdrożenie.
Testy korzystają z syntetycznych danych, prywatnych XDG/D-Bus i atrap,
a UI z izolacji opisanej w repo. Nie wysyłaj prób do rzeczywistych kontaktów.
Sprawdzaj dokumentację zgodną z wybraną wersją API. Małe brakujące zależności
poprzedniego etapu uzupełnij; istotne braki opisz bez udawania gotowości.

## Etap tej sesji

**Zależności:** S00: wybrana wersja, transport, protokół i reguły własności procesów.

**Rezultat:** Jedna nadzorowana usługa powiązana z życiem Putkina, z testowym transportem i poprawnym sprzątaniem.

## Zadanie

1. Zaimplementuj adapter QML i pomocnik według kontraktu S00. Pomocnik
   jest właścicielem połączenia z signal-cli i nie zależy od widoczności okna.
   Konfiguracja niesparowana uruchamia lekki stan usługi; nie generuje
   nieskończonej pętli startów CLI ani błędów na każdym reloadzie.
2. Odbieraj strumień asynchronicznie. Koreluj request/response, oddziel
   zdarzenia od odpowiedzi, obsłuż częściowe ramki, Unicode, timeout,
   anulowanie, spóźnione odpowiedzi i restart generacji.
   Nie zapisuj surowego stdout/stderr z prywatnymi payloadami do journalu.
3. Dodaj stan gotowości, wersję protokołu i wykrywanie możliwości.
   Brak binarki, niezgodna wersja, utrata procesu i uszkodzona odpowiedź
   mają skończone, zrozumiałe stany oraz ograniczony backoff.
4. Powiąż życie bridge i CLI z właścicielem shella: normalne zamknięcie,
   twardy restart, awaria, EOF oraz SIGTERM. Samo
   `Component.onDestruction` nie jest dowodem sprzątania po SIGKILL.
   Wykorzystaj sprawdzoną własność deskryptorów/procesów i cgroup tam,
   gdzie jest dostępna; testuj też uruchomienie bez UWSM.
5. Zapewnij wyłączność odbiorcy i magazynu dla tego konta: blokada procesu
   powiązana z życiem właściciela, odporna na pozostałe pliki/PID reuse.
   Reload może kontrolowanie odtworzyć transport, ale nie uruchamia
   równoległych odbiorców i nie usuwa danych. Brak `pkill signal-cli`
   i zabijania cudzych instancji.
6. Dodaj izolowany fake signal-cli z identycznym framingiem, konfiguracją
   błędów i kontrolą liczby procesów. Produkcja nie przełącza się na niego
   automatycznie. Nie dodawaj niezależnego autostartu ani linger.
7. Przygotuj jawny punkt wstrzyknięcia SignalService/Backend do korzenia
   i testowego harnessu. Do kolejnego etapu dane są efemeryczne; nie
   rozpoczynaj prawdziwego odbioru konta przed gotowym zapisem z S02.

## Odbiór

- Dwa równoczesne starty dają najwyżej jednego odbiorcę; druga instancja
  ma kontrolowany wynik. Reload nie mnoży procesów ani subskrypcji.
- Zamknięcie testowego okna nie kończy usługi. Koniec właściciela kończy
  bridge i CLI, także po awarii; test potwierdza brak osieroconych procesów.
- Uszkodzona/za duża ramka, timeout, powrót CLI i kolejność odpowiedzi
  są sprawdzone testami zachowania bez blokowania QML.
- Zatrzymanie w trakcie RPC nie zgłasza fikcyjnego sukcesu.
- Spoczynek nie uruchamia cyklicznych procesów ani odpytywania historii.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S01/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
