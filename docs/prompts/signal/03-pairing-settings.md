# S03 — Parowanie konta i ustawienia

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

**Zależności:** S02: trwały magazyn i odbiór; S01: cykl życia procesu; S00: API link.

**Rezultat:** Natywny ekran połączenia z telefonem, gotowy przepływ QR i kontrolowany stan konta.

## Zadanie

1. Dodaj sekcję Signal do istniejącego okna ustawień. Wykorzystaj wspólne
   kontrolki i routing, nie twórz osobnego frameworka ustawień.
   Stany: brak narzędzia, niepołączony, parowanie, połączony, offline,
   cofnięte powiązanie, błąd wymagający działania.
2. Zaimplementuj `link` jako dodatkowe urządzenie. Pokaż prawidłowy QR
   z URI dostarczonego przez CLI, nazwę urządzenia oraz minimalne akcje
   rozpoczęcia/anulowania/odnowienia. Telefon pozostaje kontem głównym:
   nie używaj `register` do tej funkcji.
3. Życie URI parowania jest ograniczone do próby; nie loguj go i nie
   zapisuj w historii powiadomień, fixture, repo ani zrzutach odbiorowych.
   Anulowanie/timeout usuwa zasoby próby. Powtórne kliknięcie nie tworzy
   dwóch procesów link. Odbiór zaczyna się dopiero z gotowym magazynem.
4. Po sukcesie zapisz identyfikację konta, zsynchronizuj dostępne kontakty,
   profile i grupy, rozpocznij normalny odbiór. Rozmowy istniejące tylko
   w telefonicznej historii mogą pozostać puste do nowych wiadomości;
   nie generuj fikcyjnych wpisów ani nie obiecuj importu starej historii.
5. Ustal odłączenie integracji zgodne z możliwościami linked device:
   zatrzymanie lokalnego odbioru, utrata upoważnienia po odłączeniu
   z telefonu i opcjonalne świadome usunięcie lokalnej historii.
   Nie wyrejestrowuj całego konta ani nie kasuj cudzej bazy Signal Desktop.
   Destrukcyjne czyszczenie lokalnej historii ma osobną wyraźną akcję.
6. Połącz konfigurację z adapterem uruchamianym razem z shellem.
   Brak sparowania jest poprawnym stanem. Konto nie wymaga parowania
   po zwykłym restarcie ani zamknięciu okna.
7. Dodaj podgląd ekranu parowania na atrapach. Rzeczywisty skan QR
   wymaga telefonu użytkownika i należy do odbioru S12; jego brak
   nie blokuje implementacji i nie jest podstawą do deklarowania live PASS.

## Odbiór

- QR z syntetycznym URI dekoduje się do dokładnie tej samej wartości.
- Sukces, anulowanie, timeout, restart, cofnięte powiązanie i brak
  zależności działają w izolowanym przepływie.
- Akcenty reagują na podgląd/zapis/anulowanie ustawień bez restartu.
- Klawiatura, fokus i zwalnianie zasobów odpowiadają kontraktowi Putkina.
- Zapis statusu odróżnia kompletny przepływ testowy od niesprawdzonego
  jeszcze parowania z rzeczywistym telefonem.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S03/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
