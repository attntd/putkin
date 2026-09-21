# S04 — Okno rozmów, tekst i nowa rozmowa

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

**Zależności:** S03: stan konta; S02: historia/outbox/szkice; S01: usługa działająca bez okna.

**Rezultat:** Użyteczny komunikator tekstowy w osobnym natywnym oknie, z historią od połączenia i routingiem do konkretnej rozmowy.

## Zadanie

1. Zbuduj leniwie tworzone natywne okno Quickshell: lista rozmów,
   historia wybranej rozmowy i edytor. Wąska szerokość przełącza
   listę/szczegóły zamiast ściskać obie kolumny poza użyteczność.
   Jedna instancja okna na integrację; zamknięcie nie kończy usługi.
2. Dodaj wejście z paska, katalogu akcji i launchera/IPC zgodnie z repo.
   Nie narzucaj globalnego skrótu kolidującego z istniejącym.
   Przycisk korzysta z Material Symbols i wspólnego zachowania ikon.
   Licznik/stany nieprzeczytania wywodzą się z modelu rozmów, nie z
   odczytu bitmapy Signal Desktop.
3. Udostępnij stabilną akcję `openConversation(conversationId)`:
   przywołuje istniejące lub otwiera nowe okno, wybiera rozmowę,
   respektuje monitor i fokus. Jest kontraktem dla S05.
   Nie parsuj odbiorcy z tytułu powiadomienia ani komendy shellowej.
4. Zaimplementuj listę z wyszukiwaniem nazw/kontaktów, paginowaną historię,
   separatory dni, treść, czas i własny/przychodzący kierunek.
   Nowa wiadomość nie przewija do końca, gdy użytkownik czyta starsze;
   doładowanie poprzednich stron zachowuje kotwicę przewijania.
5. Wysyłanie tekstu korzysta z outboxu. Enter wysyła, Shift+Enter
   dodaje nowy wiersz; nie wysyłaj podczas zatwierdzania IME.
   Pusty tekst nie jest wiadomością. Szkic per rozmowa przetrwa
   zamknięcie okna i restart. Nie pokazuj „dostarczono” po samym RPC.
6. Dodaj „Nowa rozmowa”: wybór znanego kontaktu lub wpisanie numeru/
   nazwy użytkownika, zgodnie z API. Walidacja/rozwiązanie tożsamości
   nie wysyła próbnej wiadomości. Widok pustej rozmowy jest gotowy
   przed pierwszym wysłaniem. Brak konta/uprawnień blokuje send.
7. Wzorce grup przychodzących z S02 pokazuj już jako rozmowy z nazwą
   grupy i autorami. Rozbudowane zarządzanie grupami należy do S10.
8. Nie dodawaj własnych potwierdzeń odczytania przed S06; nie markuj
   automatycznie wszystkiego po otwarciu okna. Powiadomienia należą do S05.
   Widoki bez logiki systemowej, standardowe wejście Qt, pomocnicze
   `ControlInput`/`FocusIndicator` i jeden gradient na powierzchnię.

## Odbiór

- Klawiatura hjkl/Enter działa w listach, a zwykłe pisanie/IME w edytorze.
- Dwie różne drogi wejścia otwierają tę samą właściwą rozmowę.
- Zamknięcie okna + nowe syntetyczne wiadomości + ponowne otwarcie
  pokazują kompletny zapis; powtórne uruchomienie nie powiela usługi.
- Mały ekran, długa treść, Unicode, duża historia, zmiana akcentów,
  przewijanie oraz wielomonitorowy fokus są sprawdzone w izolacji.
- Nowa rozmowa i wysłanie na atrapie nie wymagają istniejącego czatu.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S04/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
