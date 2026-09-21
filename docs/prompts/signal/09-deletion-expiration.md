# S09 — Usuwanie i wiadomości znikające

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

**Zależności:** S08: wersje/reakcje/cytaty; S07: kopie mediów; S05: kopie w powiadomieniach; S02: magazyn.

**Rezultat:** Usunięcia i wygaśnięcia są konsekwentnie stosowane w historii, mediach, cache oraz powiadomieniach.

## Zadanie

1. Dodaj „Usuń u mnie” jako lokalną operację oraz „Usuń u wszystkich”
   przez remoteDelete, dostępne według autorstwa i aktualnych limitów
   Signala. Nie przedstawiaj żądania remoteDelete jako gwarancji
   fizycznego usunięcia na wszystkich cudzych urządzeniach.
2. Przetwarzaj usunięcia od rozmówcy i synchronizowane z telefonu.
   Event przed wiadomością tworzy minimalny tombstone bez treści,
   tak aby spóźniony message/edit/retry nie odtworzył usuniętego tekstu.
   Lokalny delete nie wysyła remoteDelete.
3. Usuń kontrolowane kopie treści: rekordy/wersje edycji, payloady
   przetwarzania, indeks wyszukiwania, podglądy cytatów tam gdzie
   kontroluje je nasza baza, miniatury, cache, staging, pliki CLI
   należące do tej integracji oraz karty i historię powiadomień.
   Współdzielone pliki usuwaj dopiero bez aktywnych referencji.
   Nie deklaruj kasowania zewnętrznych kopii zapisanych przez użytkownika.
4. Wprowadź wiadomości znikające zgodnie z Signal: poprawny punkt startu
   timera dla wysłanych/odebranych, odczyt i sync z telefonu, aktualizacja
   ustawień rozmowy. Zmiana ustawienia/edycja/replay nie przedłuża
   istniejącej wiadomości ani nie zmienia dowolnie dawnych wiadomości.
5. Terminy przechowuj trwale. Gdy shell nie działa, usługa też nie
   działa: zaległe wygaśnięcia wykonaj na starcie przed udostępnieniem
   historii/UI. Nie dodawaj niezależnego daemona tylko do czyszczenia.
   Udokumentuj tę granicę; nie obiecuj usunięcia plików dokładnie o
   terminie na wyłączonym komputerze. Obsłuż suspend/resume i skoki zegara.
6. Użyj harmonogramu najbliższego terminu, nie timera per wiadomość
   ani przebudowy całej bazy co sekundę. Cleanup jest wznawialny po awarii.
   Określ retencję WAL, kontrolowanych kopii zapasowych i usuniętych danych;
   nie obiecuj forensic secure erase na SSD przez samo DELETE.
7. Zweryfikuj wsparcie view-once wybranej wersji. Implementuj je tylko
   z prawidłowym jednorazowym odczytem, cleanup i sync obejrzenia.
   Jeśli nie da się dotrzymać semantyki, zachowaj typ jako niedostępny,
   bez automatycznego podglądu/pobierania poza koniecznym zakresem;
   jawnie wpisz ograniczenie. Nie traktuj go jako zwykłego obrazka.
8. Synchronizację „usuń dla mnie” między własnymi urządzeniami
   odróżnij od remoteDelete: zaimplementuj tylko potwierdzony interfejs,
   w przeciwnym razie nazwij lokalny zakres w kontrakcie i odbiorze.
   Nie rozszerzaj etapu o niszczenie całego konta lub historii telefonu.

## Odbiór

- Remote delete przed/po wiadomości, retry i późna edycja nie wskrzeszają treści.
- Wygaśnięcie usuwa kontrolowane kopie i podglądy w centrum powiadomień.
- Restart po terminie, suspend/resume, błąd cleanup i zmiana zegara
  są testowane z kontrolowanym zegarem.
- Lokalne usunięcie nie staje się nieumyślnie usunięciem dla wszystkich.
- Polityka view-once i ograniczenia fizycznego usuwania są uczciwie opisane.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S09/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
