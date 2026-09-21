# S08 — Reakcje, edycje, odpowiedzi i wskaźnik pisania

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

**Zależności:** S07: kompletna wiadomość z mediami; S06: raporty; S02: reducer i kolejka operacji.

**Rezultat:** Rozmowa obsługuje zmiany wiadomości i interakcje, także synchronizowane z telefonu.

## Zadanie

1. Dodaj reakcje emoji: wybór, zmiana, usunięcie własnej reakcji,
   prezentacja osób/liczby według modelu. Klucz to wiadomość i autor
   reakcji, nie sam emoji. Obsłuż Unicode z variation selectors/ZWJ.
2. Dodaj edycję własnej wiadomości przez rzeczywiste API i ograniczenia
   wybranej wersji. Edytor pokazuje stan edycji, pozwala anulować i
   nie nadpisuje zwykłego szkicu. Zachowaj mapę tożsamości wiadomości
   oraz wersji potrzebną do receipts, reakcji i późniejszego usuwania.
3. Przetwarzaj edycje od rozmówcy i sent sync edycji z telefonu.
   Zmiany przed wiadomością bazową są odkładane do uzgodnienia,
   duplikaty idempotentne, spóźniona stara wersja nie zastępuje nowej.
   Nie stosuj modelu „ostatni odebrany event zawsze wygrywa”.
4. Dodaj odpowiedź z cytatem z poprawnym autorem/identyfikatorem,
   przejście do oryginału, jeśli dostępny w lokalnej historii, oraz
   poprawny stan gdy oryginału sprzed parowania nie ma.
   Nie fabrykuj starej historii z cytatu.
5. Dodaj wzmianki w grupach i ich poprawne kodowanie, jeżeli API
   wybranej wersji to udostępnia. Sprawdź UTF-16 offsety dla emoji.
   Formatowanie tekstu mapuj na kontrolowane reprezentacje;
   nie renderuj dowolnego HTML otrzymanego od nadawcy.
6. Wskaźnik pisania wysyłaj tylko w aktywnym edytorze, z ograniczeniem
   częstotliwości i wygaśnięciem. Stop przy wysłaniu, opuszczeniu
   rozmowy, utracie fokusu/połączenia i blokadzie. Uwzględnij ustawienia.
   Odbierane wskaźniki mają timeout, nie tworzą historii ani unread.
7. Edycje/reakcje poprawiają modele i właściwe karty powiadomień.
   Własne zmiany z telefonu nie generują nowego toasta przychodzącego.
   Nie resetuj terminu wiadomości znikającej przez edycję.
8. Własność i dostępność akcji wyprowadzaj z protokołu/uprawnień.
   Błąd RPC cofa stan optymistyczny albo pokazuje prawdziwy wynik;
   nie utrwalaj lokalnego sukcesu, którego CLI nie potwierdził.

## Odbiór

- Dodanie/zmiana/usunięcie reakcji, edycja i cytat działają w 1:1 i grupie.
- Zdarzenia z telefonu, duplikaty, odwrotna kolejność i brak oryginału
  nie psują tożsamości, kolejności ani licznika.
- Unicode/ZWJ/wzmianki, anulowana edycja i błąd wysyłki są sprawdzone.
- Powiadomienie po edycji nie pokazuje starego podglądu.
- Pisanie nie powoduje ciągłego pollingu, zostaje zatrzymane na blur/lock
  i nie przechwytuje standardowych skrótów edytora.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S08/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
