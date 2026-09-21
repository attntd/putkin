# S02 — Historia, synchronizacja i kolejka wysyłania

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

**Zależności:** S01: transport, wyłączność procesu i kontrolowane uruchamianie; S00: model danych i API.

**Rezultat:** Trwały model rozmów z obu urządzeń, deduplikacja i jedna kolejka operacji dla przyszłego okna i quick reply.

## Zadanie

1. Utwórz magazyn SQLite z migracjami, transakcjami, indeksami i wersją
   schematu. Dane użytkownika żyją poza repo oraz katalogami wydań.
   Katalogi i pliki mają prywatne uprawnienia. Jeśli wybrano WAL,
   obejmij polityką retencji i kopii także WAL/SHM.
2. Modeluj konto, osoby, grupy/rozmowy, wiadomości, operacje wysyłania,
   szkice i referencje mediów. Rozmowa grupowa ma klucz grupy,
   nigdy klucz autora ostatniej wiadomości. Normalizuj sent sync jako
   własną wiadomość w rozmowie z odbiorcą, nie jako czat „ze sobą”.
3. Obsłuż teksty przychodzące, lokalnie wysyłane i wysłane z telefonu,
   zdjęcia/zdarzenia jako rozpoznane typy do późniejszych etapów.
   Deduplikuj według zweryfikowanej tożsamości protokołu, nie samej treści
   lub timestampu. Nie scalaj dwóch identycznych legalnych wiadomości.
4. Zapisuj odebrane zdarzenia przed aktualizacją widoków/powiadomień.
   Reducer ma znosić duplikaty, różną kolejność i opóźniony event celu.
   Nie utrwalaj bezterminowo całego surowego strumienia: późniejsze
   usunięcia muszą obejmować także dzienniki, edycje i payloady.
5. Zbuduj jeden outbox współdzielony przez okno i quick reply:
   identyfikator operacji, queued/sending/sent/failed/unknown,
   wynik per odbiorca tam, gdzie protokół go rozróżnia.
   Sukces RPC oznacza potwierdzony etap wysłania, nie dostarczenie/odczyt.
   Retry tylko tam, gdzie poprzednia próba na pewno nie wysłała;
   timeout po wysłaniu wymaga rekoncyliacji/świadomego ponowienia.
   Nie obiecuj idempotencji serwera na podstawie lokalnego UUID.
6. API dla QML: stronicowana lista rozmów i wiadomości, wysłanie tekstu,
   szkic, zmiany przyrostowe i status. Nie przenoś całej bazy w każdej
   odpowiedzi. Zachowaj stabilne klucze list i kolejność przy aktualizacji.
7. Wprowadź punkty podłączenia terminów wygaśnięcia i tombstones już teraz.
   Do S09 nie pokazuj ani nie przechowuj bez ograniczeń treści typów,
   dla których nie działa wymagana semantyka znikania/view-once.
8. Sprawdź pełny dysk, błędy transakcji i migracji. Przy braku możliwości
   zapisu zatrzymaj/przyhamuj odbiór według kontraktu zamiast konsumować
   kolejne wiadomości do nietrwałej pamięci. Opisz lukę transport → zapis,
   której sam SQLite nie eliminuje.

## Odbiór

- Sekwencja telefon → komputer → odpowiedź komputera na syntetycznym
  strumieniu daje jedną spójną historię i poprawne strony wiadomości.
- Restart zachowuje historię, szkice i znany wynik outboxu.
- Duplikaty i kolejność sent sync przed/po odpowiedzi RPC nie mnożą wpisów.
- Dwa konta/autorzy/grupy z podobnymi timestampami nie kolidują.
- Testy migracji, awarii podczas zapisu i niejednoznacznej wysyłki
  wykazują prawdziwy stan, bez automatycznych duplikatów.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S02/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
