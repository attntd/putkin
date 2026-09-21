# S12 — Instalacja, aktywacja i odbiór z telefonem

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

**Zależności:** S11: zweryfikowany kandydat; istniejący instalator Putkina; telefon do parowania i wskazana rozmowa testowa do prób wieloosobowych.

**Rezultat:** Wdrożona integracja albo kompletny gotowy pakiet z dokładnie wskazanym brakującym krokiem użytkownika; wyniki lokalne i live rozdzielone.

## Zadanie

1. Sprawdź wyniki S11 i bieżący stan źródeł. Rozszerz istniejący
   instalator/manifest zależności tak, by wydanie zawierało adapter,
   helper i widoki, a dane konta, baza, media i szkice pozostały
   w katalogach użytkownika poza buildem.
   Nie dołączaj prywatnego konta ani testowego fake backendu do produkcji.
2. Ustal instalację konkretnej zgodnej wersji signal-cli i jej runtime
   z potwierdzonego źródła; preferuj istniejące mechanizmy projektu.
   Brak narzędzia ma czytelny wynik preflight. Nie pobieraj niezweryfikowanych
   „latest” przy każdym starcie shella.
3. Zaimplementuj aktualizację i rollback na kopii syntetycznych danych:
   wersja kodu, CLI i schematu muszą być zgodne.
   Rollback samego kodu nie cofa automatycznie zmigrowanej bazy,
   a odtworzenie starego stanu kryptograficznego po wysyłkach jest
   niedopuszczalnym skrótem. Nie cofaj danych protokołu.
   Nie przywracaj przez rollback treści już usuniętych/znikłych.
   Niekompatybilny downgrade ma być zatrzymany z konkretnym powodem.
4. Przetestuj instalację do prywatnego `--destination` i dry-run,
   zachowanie pięciu buildów, aktualizację, kontrolowany start/stop,
   brak konta, zachowanie danych i poprawny punkt powrotu.
   Przygotuj dokumentację `docs/signal/OPERATIONS.md`.
5. **Wykonanie tego promptu obejmuje instalację i aktywację gotowej
   integracji w Putkinie.** Korzystaj z istniejącej ścieżki
   `scripts/install --activate` po wymaganych kontrolach.
   Nie przełączaj przy zablokowanej sesji ani operacji lock/suspend.
   Zachowaj stan Caffeinate i obecny kontrakt UWSM; bez niezależnego
   autostartu daemona Signal.
6. Jeśli konto nie jest sparowane, doprowadź działający ekran do QR
   i poproś użytkownika wyłącznie o skan w Signal → Połączone urządzenia.
   Skan telefonu jest rzeczywistą zależnością, której agent nie zastąpi.
   W tym czasie wykonaj wszystkie niezależne kontrole.
   Zwykły stop/restart nie może wymagać ponownego skanu.
7. Do odbioru podstawowego użyj własnej „Notatki do siebie”:
   ten prompt zleca wysłanie tam jawnie testowego tekstu i małego
   syntetycznego pliku oraz sprawdzenie na telefonie. Poproś użytkownika
   o odpowiedź z telefonu, reakcję, edycję i potwierdzenie widoczności.
   Prawdziwe raporty od innego rozmówcy i role grupowe wymagają
   wskazanego przez użytkownika odbiorcy/grupy testowej; nie wybieraj
   przypadkowych kontaktów i nie uznawaj Notatki za dowód tych funkcji
   ani powiadomień o wiadomościach przychodzących. Własny sent sync
   z telefonu nie ma generować toasta.
8. W rozmowie testowej z drugim uczestnikiem sprawdź: wiadomość od
   rozmówcy → toast → Otwórz właściwą rozmowę; kolejna wiadomość
   rozmówcy → quick reply bez okna → odpowiedź widoczna na telefonie.
   Osobno nasz telefon wysyła → komputer pokazuje sent sync bez toasta.
   Odbierz media, read sync, edycję, reakcję, usunięcie i znikanie,
   a także grupy/receipts, jeśli wskazana jest odpowiednia rozmowa.
   Nie zapisuj prywatnej treści do screenshotów/logów jako dowodu.
9. Zweryfikuj start ze shellem, zamknięcie okna, restart, kontrolowany
   stop shella i brak jego procesów Signal po stopie, a następnie
   poprawny powrót. Nie destabilizuj aktywnej blokady.
   Sprawdź dynamiczne akcenty także w żywym quick reply.
10. Signal Desktop może pozostać połączony jako odrębne urządzenie.
    Ewentualne wyłączenie jego autostartu/powiadomień wykonaj tylko
    zgodnie z wyraźnym życzeniem użytkownika; nie kasuj jego historii.
    Powielone powiadomienia dwóch klientów opisz jako konfigurację
    współistnienia, nie naprawiaj porównywaniem treści rozmów.

## Odbiór

- Wydanie i kontrola zależności są powtarzalne, dane poza katalogami buildu,
  update/rollback sprawdzone bez cofania kryptograficznego stanu konta.
- Aktywacja i status procesów mają rzeczywisty dowód.
- Dwa działania powiadomienia, akcenty i życie usługi odebrane na pulpicie.
- Macierz live ma wyniki PASS albo konkretne niewykonane kryteria;
  test Notatki do siebie nie zalicza powiadomień przychodzących,
  grup ani cudzych read receipts.
- Jeśli skan/odpowiedź/testowa grupa są niedostępne, pozostaw ukończone
  prace i precyzyjny krok do kontynuacji. Nie ogłaszaj pełnego odbioru live.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S12/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
