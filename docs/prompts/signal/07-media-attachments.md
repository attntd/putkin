# S07 — Media i załączniki

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

**Zależności:** S06: statusy; S05: powiadomienia; S02: trwałe operacje i referencje plików.

**Rezultat:** Zdjęcia, filmy, audio i pliki działają w rozmowach z kontrolowanym przechowywaniem i interfejsem.

## Zadanie

1. Zaimplementuj wysyłanie jednego lub wielu plików przez zweryfikowane
   API signal-cli. Wybór z pliku, przeciągnięcie i wklejenie obrazu
   korzystają z tej samej ścieżki przygotowania/outboxu.
   Pokaż załączniki do usunięcia z kompozycji przed wysłaniem.
2. Utrwal źródło pliku w kontrolowanym stagingu, jeśli kolejka ma
   przetrwać restart lub oryginał może zniknąć. Obsłuż anulowanie,
   zmianę pliku, brak uprawnień, błąd uploadu, pełny dysk i resztki
   po awarii. Nie oznaczaj anulowania po wysłaniu jako pewnego cofnięcia.
3. Przy odbiorze mapuj ścieżki/identyfikatory CLI na magazyn załączników
   i wiadomości. Weryfikuj granice katalogu, nazwy, MIME i rozmiary;
   zdalna nazwa pliku nie steruje ścieżką zapisu ani poleceniem.
   Pobieranie/odczyt/render nie mogą blokować wątku UI.
4. Dodaj miniatury zdjęć, podgląd obrazu, odtwarzanie audio/wideo
   przez dostępne komponenty Qt i kartę dowolnego pliku.
   Jeśli dekoder nie obsługuje formatu, pokaż prawdziwy stan i możliwość
   zapisu/otwarcia po jawnej akcji, zamiast pustego „odtwarzacza”.
   Plik audio i natywna notatka głosowa to różne możliwości;
   nie oznaczaj pierwszego jako pełnego wsparcia nagrywania voice notes.
5. Zapewnij zapis wybranego załącznika i otwarcie przez system dopiero
   po akcji użytkownika. Bez automatycznego wykonywania plików,
   odczytu zdalnych URL z tekstu i generowania web preview.
6. Zastosuj limity pobierania/dekodowania/cache odpowiednie do API.
   Pokaż procent tylko przy rzeczywistych danych o postępie;
   w przeciwnym razie wystarczy stan pending/busy.
   Rozdziel oryginał, miniaturę, staging i kopię zapisaną przez użytkownika.
7. Powiadomienia obrazowe korzystają z tych samych ograniczeń i
   routingu. Odpowiedź quick reply pozostaje tekstowa.
   Zapewnij hook do usuwania wszystkich kontrolowanych kopii w S09.
   Do tego czasu view-once ma bezpieczną, jawną obsługę typu nieobsługiwanego,
   bez wyświetlania i zapisu poza zweryfikowaną polityką S00/S02.

## Odbiór

- Tekst z kilkoma załącznikami, obraz, film, audio i dokument przechodzą
  testowy przepływ obu kierunków oraz restart historii.
- Syntetyczne pliki o nietypowych nazwach/dużych wymiarach/zepsutym
  formacie nie wychodzą poza magazyn i nie blokują UI.
- Anulowanie, błąd, unknown send, utrata pliku oraz cleanup są sprawdzone.
- Podgląd ma poprawne proporcje, klawiaturę, fokus i żywe akcenty.
- Dostępność kodeków i różnica między audio a voice note są udokumentowane;
  nie deklaruj testu realnego transferu bez wykonania go z telefonem.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S07/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
