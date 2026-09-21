# S10 — Grupy, kontakty i pełne rozpoczynanie rozmów

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

**Zależności:** S09: kompletne zachowanie wiadomości; S03/S04: kontakty, parowanie i nowa rozmowa.

**Rezultat:** Codzienna obsługa grup i kontaktów bez wychodzenia z interfejsu Putkina.

## Zadanie

1. Rozwiń ekran nowej rozmowy o profile/kontakty, odświeżanie dostępnych
   danych i obsługę numerów/nazw użytkownika. Cache nie może zmieniać
   tożsamości rozmowy po zmianie nazwy lub numeru.
   Nie wysyłaj tekstu testowego, żeby sprawdzić istnienie użytkownika.
2. Zbuduj tworzenie grupy: nazwa, wybór członków, opcjonalny avatar,
   walidacja i potwierdzony wynik API. Po utworzeniu otwórz właściwą grupę.
   Awaria/timeout po create ma wynik unknown i rekoncyliację;
   nie twórz automatycznie drugiej grupy.
3. Dodaj szczegóły grupy: członkowie, role, nazwa/opis/avatar,
   dodanie/usunięcie członka, nadanie/odebranie administratora,
   dostępne uprawnienia, link zaproszenia i opuszczenie.
   Pokazuj tylko operacje dozwolone przez aktualny stan/uprawnienia.
   Znaczne operacje destrukcyjne mają jasny cel i potwierdzenie w UI.
4. Obsłuż zaproszenia i dołączenie przez link, oczekiwanie na akceptację,
   odmowę/brak uprawnień oraz aktualizacje członkostwa z telefonu.
   Osoba, która opuściła grupę, nie ma aktywnego composer/reply
   w otwartym oknie ani w starym powiadomieniu.
5. Wiadomości z grup pokazują rzeczywistego autora, reakcje, wzmianki,
   media i raporty per osoba. Zmiany nazwy/członkostwa mają zwięzłe
   zdarzenia systemowe w rozmowie, bez fikcyjnej wiadomości tekstowej.
6. Obsłuż message requests i blokowanie w zakresie potwierdzonym
   dla linked device. Przy nieznanym nadawcy nie wysyłaj automatycznie
   read ani odpowiedzi przed dozwolonym stanem akceptacji.
   Oddziel lokalne ukrycie/wyciszenie rozmowy od synchronizowanych
   ustawień konta; nie deklaruj sync bez API.
7. Dodaj lokalne wyciszenie rozmowy używane przez S05, jeśli jeszcze
   go nie ma. Wyciszenie nie zatrzymuje odbioru, zapisu ani unread.
   Nie zmieniaj globalnego DND i nie wyłączaj cudzych powiadomień.
8. Odświeżane profile/avatar/grupy aktualizuj przyrostowo, bez
   gubienia wyboru/fokusu. UI respektuje wspólne tokeny, akcenty
   i aktualne reguły krótkich etykiet/błędów Putkina.

## Odbiór

- Nowa rozmowa po numerze/nazwie, utworzenie grupy i dołączenie
  przez link działają w izolowanym API.
- Role/uprawnienia, utrata członkostwa, częściowy błąd i unknown create
  nie powodują niedozwolonych akcji ani podwójnych grup.
- Nazwa/numery/avatar aktualizują się bez duplikacji historii.
- Group quick reply wysyła do grupy, nigdy prywatnie do ostatniego autora.
- Testy obejmują akceptację message request, wyciszenie oraz wszystkie
  wcześniejsze typy wiadomości w kontekście grupowym.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S10/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
