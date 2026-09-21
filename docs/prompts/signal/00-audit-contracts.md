# S00 — Audyt integracji i kontrakty

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

**Zależności:** Brak zależności od nowych etapów Signala. Zastany Putkin musi być odczytany i rozpoznany.

**Rezultat:** Zweryfikowany zakres, wersja signal-cli i kontrakty pozwalające implementować kolejne etapy bez zgadywania.

## Zadanie

1. Sprawdź istniejące punkty integracji: `core/Theme.qml`, `Settings.qml`,
   `ActionController.qml`, `NotificationFocus.qml`, `services/Notification*.qml`,
   `LocalNotification.qml`, `SignalTrayState.qml`, okna ustawień,
   `scripts/qs`, `scripts/install` i `_install.py`.
   Obecny `inlineReplySupported: false` i filtrowanie `inline-reply`
   są znaną luką do usunięcia w S05. Istniejący SignalTrayState dotyczy
   zewnętrznego Signal Desktop; nie stanowi backendu naszego klienta.
2. Sprawdź dostępność i wersje Quickshell, Qt, Pythona i signal-cli.
   W chwili planowania signal-cli nie było w PATH. Jeśli go brak, przygotuj
   zweryfikowane, izolowane środowisko narzędzia według dokumentacji projektu,
   bez masowej aktualizacji systemu. Wybierz konkretną wersję wydania
   i zapisz pochodzenie oraz wymagania runtime. Nie opieraj kontraktu na
   przypadkowym HEAD bez określenia wersji.
3. Zweryfikuj CLI/JSON-RPC: link, odbiór/subskrypcje, send, kontakty/grupy,
   attachments, reakcje, edycje, remoteDelete, receipts, sent/read sync.
   Zapisz rzeczywiste przykłady żądań i syntetycznych odpowiedzi/zdarzeń.
   Rozróżnij wsparcie biblioteki, dostępność w JSON-RPC i działanie
   jako urządzenie połączone. Nie wymyślaj pól API ani limitów.
4. Ustal docelowy podział: cienki adapter QML, lokalny pomocnik Python
   zgodny z repo, SQLite i osobny proces signal-cli. Preferuj JSON-RPC
   przez stdin/stdout lub prywatny UNIX socket. Bez serwera HTTP/TCP
   i dodatkowej infrastruktury, jeśli nie ma konkretnej potrzeby.
   Wybierz jeden transport i opisz protokół QML ↔ pomocnik.
5. Zdefiniuj stany konta, usługi i wysyłania, identyfikatory konta/rozmowy/
   wiadomości, wersjonowanie IPC/bazy, paginację i routing okna.
   Lokalny identyfikator operacji oddziel od timestampu wiadomości Signal.
   Zachowaj jednostki ms bez 32-bitowego obcięcia. Numer/nazwa profilu
   nie mogą być jedynym trwałym kluczem osoby.
6. Zapisz semantykę: jedna baza i konto na integrację; start/stop z shellem;
   jedno leniwie tworzone okno z listą rozmów; trwałe szkice; dwa rodzaje
   odczytu; osobna historia komunikatora i sesyjna historia powiadomień.
   Domyślny kierunek przechowywania to prywatny SQLite i prywatne pliki
   konta/mediów poza wydaniami. Ujawnij w dokumentacji, czy magazyn jest
   szyfrowany na dysku; E2EE transportu nie dowodzi szyfrowania plików.
7. Zbadaj granice niezawodności: signal-cli nie jest archiwum z replay API.
   Sprawdź moment odbioru/ack względem zapisu w bridge. Nie obiecuj
   bezstratności po dowolnej awarii ani dokładnie jednokrotnego wysłania.
   Zaprojektuj stan „wynik nieznany”, rekoncyliację i kontrolę przeciążenia.
   Rozróżnij przerwę odbioru przy wyłączonym shellu od utraty połączenia
   urządzenia; nie obiecuj nieograniczonego nadrabiania kolejki serwera.
8. Spisz mapę funkcji i ograniczeń oraz przygotuj minimalny szkielet
   testowego transportu/fixtures, bez produkcyjnego klienta.
   Kontrakt testów ma obejmować media, wiadomości znikające, view-once,
   nieznane zdarzenia, grupy, read sync, utratę procesu i granice uprawnień.

## Odbiór

- Powstały `docs/signal/CONTRACTS.md`, `API.md` i `TESTING.md`.
- API.md zawiera wersję, linki do pierwotnej dokumentacji i tabelę
  funkcja → metoda/zdarzenie → ograniczenia → przyszły test.
- Wybrano transport, miejsca danych oraz sposób sprzątania procesów
  przy stop/reload/awarii shella, także uruchomionego poza UWSM.
- Syntetyczny przykład obejmuje wiadomość przychodzącą, sent sync,
  edycję, reakcję, usunięcie, receipt i grupę. Fixture nie jest dowodem
  rzeczywistej synchronizacji: oznacz przyszłe próby z telefonem.
- Zaktualizowano szczegóły planu, jeżeli audyt wykazał lukę API.
  Nie usuwaj po cichu wymaganej funkcji i nie dopisuj jej jako „działa”.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S00/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
