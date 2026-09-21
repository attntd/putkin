# S05 — Powiadomienia: otwórz rozmowę i quick reply

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

**Zależności:** S04: stabilny routing okna; S02: wspólny outbox i klucze; istniejący NotificationService.

**Rezultat:** Powiadomienia Signala z niezawodnym otwieraniem właściwej rozmowy i odpowiedzią bez opuszczania powiadomienia.

## Zadanie

1. Rozszerz istniejącą drogę lokalnych powiadomień (`LocalNotification`,
   `NotificationService`, `NotificationEntry`, karty/centrum).
   Wewnętrzna karta Signala dostaje typowane, zaufane referencje
   account/conversation/message oraz akcje „Otwórz” i „Odpowiedz”.
   Nie polegaj na możliwościach powiadomień zewnętrznego Signal Desktop.
2. „Otwórz” wywołuje routing S04. „Odpowiedz” rozwija edytor w tej
   samej karcie, także gdy okno komunikatora jest zamknięte.
   Enter wysyła, Shift+Enter dodaje linię, IME nie wysyła przypadkowo.
   Tekst i odbiorca przechodzą jako dane do tego samego outboxu co okno.
3. Nadaj szkicowi odpowiedzi stabilną tożsamość rozmowy i osobny
   kontekst od szkicu pełnego edytora. Nowa wiadomość/zastąpienie karty
   nie zmienia odbiorcy rozpoczętej odpowiedzi i nie kasuje jej treści.
   Wstrzymaj timeout podczas świadomej edycji/wysyłki. Po niepowodzeniu
   zachowaj tekst; stan unknown nie uruchamia automatycznego resend.
   Blokuj podwójne wysłanie Enter + kliknięcie.
4. Zdefiniuj politykę grupowania i historii: jeden toast na rozmowę,
   aktualizacja dla kolejnych wiadomości, bez zalewu przy nadrabianiu
   kolejki. Nadejście nie kradnie fokusu; dopiero akcja użytkownika
   uruchamia klawiaturę. Uwzględnij DND, wyciszenie rozmowy i blokadę.
   Normalny Signal nie jest powiadomieniem krytycznym omijającym DND.
5. Dla własnych kart zachowaj bezpieczny deskryptor routingu także
   w sesyjnym centrum po wygaśnięciu toasta; rozwiązuj go ponownie przez
   aktywną usługę, nie przechowuj martwych obiektów/closure.
   Akcje są niedostępne po odłączeniu konta/usunięciu rozmowy.
   Zewnętrzne archiwalne powiadomienia zachowują istniejący kontrakt.
6. Rozdziel odczyt powiadomienia i odczyt wiadomości. Zamknięcie toasta,
   otwarcie centrum, „Wyczyść” lub sam początek odpowiedzi nie wysyłają
   receipts. S06 określi odczyt widocznej rozmowy. Kopie własnych
   wiadomości z telefonu i zdarzenia techniczne nie tworzą toastów.
7. W czasie blokady ukryj treść i wyłącz reply/open do odblokowania,
   zachowując odbiór usługi. Zmiana/delecja/wygaśnięcie wiadomości
   musi później aktualizować również jej kopie w kartach i historii.
8. API Quickshell 0.3.1 ma inline reply, ale samo ustawienie capability
   nie implementuje tej funkcji. Wybierz wewnętrzną drogę dla Signala.
   Ogłaszaj globalne `inlineReplySupported` dla zewnętrznych klientów
   tylko jeśli rzeczywiście zaimplementujesz i przetestujesz ich protokół;
   nie jest to wymagane do własnych powiadomień.
9. Zachowaj testy obecnych błędów/powiadomień. Opisz współistnienie
   z Signal Desktop: deduplikuj tylko własne eventy po kluczach protokołu,
   nie po podobnej treści obcych toastów. Nie wyłączaj samodzielnie
   powiadomień ani autostartu Signal Desktop.

## Odbiór

- Przychodzący tekst → toast → Otwórz → właściwa rozmowa.
- Zamknięte okno → reply w toastcie → jedna wiadomość w outboxie/historii.
- W centrum sesji też działa właściwy routing/reply przy aktywnym koncie.
- Nowy toast podczas pisania, replacement, timeout, DND, błąd, unknown,
  blokada, hotplug i reload nie mylą odbiorcy ani nie mnożą wysyłek.
- Podgląd/zapis/anulowanie akcentów aktualizują kartę i edytor na żywo.
- Obecne obce powiadomienia/akcje/timeouty nie mają regresji.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S05/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
