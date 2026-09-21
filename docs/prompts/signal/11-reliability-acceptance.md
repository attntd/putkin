# S11 — Odporność, pełny odbiór i wydajność

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

**Zależności:** S00–S10: implementacje i testy cząstkowe; żaden krytyczny brak nie może być ukryty za statusem PASS.

**Rezultat:** Sprawdzony kandydat wydania z naprawionymi regresjami i jawnymi granicami niezawodności.

## Zadanie

1. Zbuduj macierz wymagań → implementacja → test → wynik obejmującą
   oba kierunki sync, rodzaje wiadomości, powiadomienia, akcenty
   i życie procesów. Odróżnij testy domeny, integrację prawdziwego
   lokalnego API bez konta, natywne UI i przyszłe testy live.
2. Wykonaj scenariusz end-to-end na atrapach: rozmówca wysyła tekst/
   media do naszego konta → powiadomienie → quick reply → historia → reakcja →
   edycja → grupa → raporty → usunięcie/wygaśnięcie → restart.
   Osobno nasz telefon wysyła → sent sync → historia bez nowego toasta.
   Sprawdź również odwrotne kolejności eventów i brakujące oryginały.
3. Fault injection: offline/reconnect, awaria CLI/bridge/shella,
   reload podczas operacji, timeout po możliwym wysłaniu,
   odmowa tożsamości/zmieniony klucz, brak uprawnień, odłączenie konta,
   pełny dysk, uszkodzenie bazy, niezgodny schemat i nadmiar eventów.
   Brak API rekoncyliacji ma widoczny stan niepewności, nie fałszywy sukces.
4. Zweryfikuj brak treści/sekretów/URI parowania w logach i artefaktach.
   Sprawdź granice IPC, uprawnienia danych, path traversal w nazwach
   załączników, PlainText/bezpieczne formatowanie oraz zachowanie na lock.
   Bez automatycznego ufania zmienionym kluczom w celu zaliczenia testu.
5. Oceń natywne UI na prywatnym Waylandzie zgodnie z repo:
   małe i duże okno, skalowanie, dwa monitory/hotplug, klawiatura/IME,
   aktywna edycja quick reply, focus return oraz zmiany obu akcentów
   przez podgląd/zapis/anulowanie. Obejrzyj rzeczywiste syntetyczne zrzuty;
   sam lint nie zalicza renderowania i interakcji.
6. Zmierz spoczynek przez co najmniej 60 s z zamkniętym oknem,
   serię co najmniej 20 otwarć/zamknięć i pracę z dużą historią
   (np. 10 000 syntetycznych wiadomości, różne media).
   Zapisz CPU/RSS i liczbę procesów/subskrypcji/pracujących timerów;
   uwzględnij pamięć signal-cli/JVM osobno od QML.
   Potwierdź paginację i brak liniowego wzrostu po powtarzaniu akcji.
7. Uruchom odpowiednią pełną regresję shella raz po końcowych poprawkach:
   `scripts/check`, `scripts/test`, dedykowane integracje Signal
   i wymagane testy natywnego UI. Kolejne przebiegi tylko po zmianach
   lub przy nowym uzasadnieniu. Napraw usterki w zakresie integracji.
8. Przygotuj `docs/signal/ACCEPTANCE.md` z rzeczywistymi wynikami,
   listą zależności i minimalnym scenariuszem live S12.
   Obsługa grup administracyjnych w live wymaga wskazanej grupy testowej;
   brak konta/grupy nie blokuje testów lokalnych ani przygotowania wydania.

## Odbiór

- Obowiązkowe automatyczne kryteria mają dowody, nie tylko listę nazw testów.
- Normalny stop i awaria właściciela nie zostawiają procesów odbioru.
- S05 działa bez otwierania okna; S06 nie utożsamia centrum z odczytem.
- Nie ma potwierdzonych nieusuniętych usterek krytycznych: zły odbiorca,
  zduplikowane wysyłanie, wyciek znikającej treści czy fikcyjny status.
- Znane granice transportu/ack, retencji serwera, metadanych między
  urządzeniami oraz niewykonane próby live są wymienione wprost.
- Kandydat gotowy do S12; ten etap nie przełącza aktywnego shella.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S11/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
