# Signal w Putkinie — roadmapa wdrożenia

Przygotowano 2026-09-20 na podstawie rozmowy z użytkownikiem i odczytu
źródeł `/home/attntd/projects/putkin`. **S00–S11 ukończone lokalnie
2026-09-20–21 w checkoutcie `/home/attntd/projects/signal`. S12 wdrożony 2026-09-21; podstawowy odbiór telefonu PASS.**
Proces usługi, transport, SQLite, historia, wspólny outbox oraz parowanie
w ustawieniach oraz natywne okno wiadomości są zaimplementowane.
Wspólny interfejs jest oddzielony od adaptera Signala, z adresem rozmowy
uwzględniającym usługę i konto. Odbiór działa także po zamknięciu okna.
S05 dodaje własne powiadomienia, routing i quick reply również w centrum,
osobny trwały szkic, wyciszenie/DND/lock oraz SQLite v2. S06 dodaje
monotoniczne receipts, częściowe statusy grup, odczyt faktycznie widocznego
zakresu, read sync i wspólny unread/toasty; SQLite v3. Nieznana lista
odbiorców grupy wysłanej z telefonu pozostaje jawną granicą API.
S07 dodaje media, trwałe pliki szkicu/outboxu, miniatury i odtwarzacz Qt;
SQLite v4. Obowiązkowa polityka `putkin-media-1` dla CLI 0.14.8 ogranicza
pobieranie/cache i pomija view-once/expiring przed zapisem. Produkcyjne
pakowanie tego builda oraz transfer z telefonem pozostają w S12.
S08 dodaje reakcje, edycje z trwałą mapą wersji, cytaty, wzmianki UTF-16
i wskaźnik pisania; SQLite v5, ten sam pin CLI. Pisanie ma osobne lokalne
ustawienie, domyślnie wyłączone, ponieważ API nie eksportuje ustawienia
telefonu. S09 dodaje usuwanie lokalne/remoteDelete, trwałe znikanie od
odczytu/wysłania i czyszczenie kontrolowanych kopii; SQLite v6 i nowy pin
CLI putkin-retention-2 eksportujący początek oraz rzeczywisty czas trwania.
View-once pozostaje niedostępny; resend log CLI jest wyłączony.
S10 dodaje profile/kontakty, tworzenie i administrację grup, zaproszenia,
rekoncyliację unknown, akceptację próśb, blokadę oraz lokalne mute/hidden.
SQLite v7; pin CLI bez zmian. Członkostwo steruje composerem i quick reply.
S11 domyka [macierz odbioru](ACCEPTANCE.md), fault injection, prywatny
Wayland i pomiary 10 000 wiadomości / 60 s idle / 20 cykli okna. Pełna
regresja: 202 Python, 667 Qt i 23 integracje PASS; JVM mierzony osobno.
S12 dodał przypięty pakiet CLI/JRE, zgodność migracji/rollbacku oraz aktywację
`20260921-091350-39f9ddda75b4`. Kontrola lifecycle na pulpicie PASS.
Telefon sparowany. Naprawiono odbiór `STARTED`/`STOPPED`; konto gotowe.
Tekst w Notatce działa w obie strony; reakcje/załączniki z drugą osobą
potwierdzone. Edycja, oba działania powiadomienia, status odczytu, usuwanie
wiadomości i rozmowy grupowe także potwierdzone. Podstawowy odbiór live PASS;
rozszerzona macierz pozostaje otwarta.
[Bieżący status i dowody](STATUS.md).

## Jak uruchamiać kolejne sesje

1. Ustaw katalog pracy na checkout zawierający tę roadmapę (obecnie
   `/home/attntd/projects/signal`; prompty historycznie wskazują `putkin`).
2. Otwórz plik następnego promptu z tabeli i wklej **całą treść**
   do nowej sesji. Jeden prompt odpowiada jednemu etapowi.
3. Realizuj liniowo S00 → S01 → … → S12. Sprawdź wynik poprzedniego etapu
   w STATUS.md; samo zaznaczenie wykonania nie zastępuje kodu i dowodów.
4. Prompty powtarzają kontekst i decyzje produktowe, wskazują zależności,
   pliki wejściowe, zakres, kryteria odbioru i przekazanie stanu.
   Nie wymagają historii rozmowy. Współdzielone dokumenty i kod w tym
   katalogu stanowią trwały kontekst między sesjami.
5. Przy przerwaniu sesji uruchom ponownie ten sam prompt. Agent ma
   kontynuować istniejącą implementację, zamiast zaczynać od nowa.
6. S12 jawnie obejmuje aktywację przygotowanego wydania. Skan QR i
   odpowiedź z telefonu wymagają udziału użytkownika. Próby z innym
   rozmówcą/grupą wymagają wskazanego środowiska testowego.
   Pozostałe etapy można wykonać na danych syntetycznych.

Prefiks **S** odróżnia te etapy od starej roadmapy budowy całego shella.
Nie rozpoczynamy ponownie jej etapów 00–13. Ten dokument rozszerza
[roadmapę główną](../../ROADMAP.md).

## Obowiązujące decyzje użytkownika

- **Okno jako przyszły hub wiadomości (S04).** Wspólny interfejs i routing
  są oddzielone od logiki Signala. Pełny adres zawiera usługę, konto i
  rozmowę, również dla przyszłych akcji powiadomień. Obecnie działa tylko
  Signal. BlueFerry będzie osobnym adapterem do tego samego okna;
  bez implementowania teraz drugiej usługi lub systemu wtyczek.

- **Mocha i akcenty shella.** Cały interfejs Signala, w tym quick reply,
  używa Catppuccin Mocha i wspólnego Theme. Oba akcenty/gradient zmieniają
  się na żywo wraz z podglądem, zapisem i anulowaniem ustawień Putkina.
- **Usługa razem z shellem.** Gdy skonfigurowany Putkin działa, działa
  odbiór. Zamknięcie okna rozmów go nie zatrzymuje. Zatrzymanie lub awaria
  shella kończy należące do niego procesy Signal. Historia pozostaje.
  Nie dokładamy autonomicznego autostartu daemona ani linger.
- **Dwie akcje powiadomienia.** Otwórz właściwą rozmowę w oknie oraz
  odpowiedz bezpośrednio w karcie powiadomienia. Obie drogi korzystają
  z tej samej usługi, tożsamości rozmowy i kolejki wysyłania.
- **Synchronizacja od sparowania.** Telefon pozostaje urządzeniem
  głównym, signal-cli jest urządzeniem połączonym. Nowe wiadomości
  telefon ↔ komputer trafiają do lokalnej historii. Import dawnych
  rozmów sprzed sparowania nie jest wymagany.
- **Zakres komunikatora.** Tekst, nowa rozmowa, media/załączniki,
  reakcje, edycje, usuwanie, raporty dostarczenia/odczytu i grupy.

Przyjmujemy doświadczenie wiadomości od połączenia, a nie obietnicę
identyczności każdego ustawienia czy wszystkich metadanych obu aplikacji.
Rzeczywiste wsparcie read sync, receipt i usunięć w wybranej wersji
jest sprawdzane w S00 i odbierane w S12.

## Etapy — gotowe prompty

| Etap | Prompt do osobnej sesji | Wynik |
| --- | --- | --- |
| S00 | [Audyt integracji i kontrakty](../prompts/signal/00-audit-contracts.md) | Zweryfikowany zakres, wersja signal-cli i kontrakty pozwalające implementować kolejne etapy bez zgadywania. |
| S01 | [Proces usługi i transport](../prompts/signal/01-process-lifecycle.md) | Jedna nadzorowana usługa powiązana z życiem Putkina, z testowym transportem i poprawnym sprzątaniem. |
| S02 | [Historia, synchronizacja i kolejka wysyłania](../prompts/signal/02-history-sync-outbox.md) | Trwały model rozmów z obu urządzeń, deduplikacja i jedna kolejka operacji dla przyszłego okna i quick reply. |
| S03 | [Parowanie konta i ustawienia](../prompts/signal/03-pairing-settings.md) | Natywny ekran połączenia z telefonem, gotowy przepływ QR i kontrolowany stan konta. |
| S04 | [Okno rozmów, tekst i nowa rozmowa](../prompts/signal/04-conversations-window.md) | Użyteczny komunikator tekstowy w osobnym natywnym oknie, z historią od połączenia i routingiem do konkretnej rozmowy. |
| S05 | [Powiadomienia: otwórz rozmowę i quick reply](../prompts/signal/05-notifications-quick-reply.md) | Powiadomienia Signala z niezawodnym otwieraniem właściwej rozmowy i odpowiedzią bez opuszczania powiadomienia. |
| S06 | [Dostarczenie, odczyt i stan między urządzeniami](../prompts/signal/06-receipts-read-state.md) | Rzetelne statusy wysłania/dostarczenia/odczytu oraz spójne nieprzeczytane wiadomości przy zmianie urządzenia. |
| S07 | [Media i załączniki](../prompts/signal/07-media-attachments.md) | Zdjęcia, filmy, audio i pliki działają w rozmowach z kontrolowanym przechowywaniem i interfejsem. |
| S08 | [Reakcje, edycje, odpowiedzi i wskaźnik pisania](../prompts/signal/08-reactions-edits-quotes.md) | Rozmowa obsługuje zmiany wiadomości i interakcje, także synchronizowane z telefonu. |
| S09 | [Usuwanie i wiadomości znikające](../prompts/signal/09-deletion-expiration.md) | Usunięcia i wygaśnięcia są konsekwentnie stosowane w historii, mediach, cache oraz powiadomieniach. |
| S10 | [Grupy, kontakty i pełne rozpoczynanie rozmów](../prompts/signal/10-groups-contacts.md) | Codzienna obsługa grup i kontaktów bez wychodzenia z interfejsu Putkina. |
| S11 | [Odporność, pełny odbiór i wydajność](../prompts/signal/11-reliability-acceptance.md) | Sprawdzony kandydat wydania z naprawionymi regresjami i jawnymi granicami niezawodności. |
| S12 | [Instalacja, aktywacja i odbiór z telefonem](../prompts/signal/12-release-activation.md) | Wdrożona integracja albo kompletny gotowy pakiet z dokładnie wskazanym brakującym krokiem użytkownika; wyniki lokalne i live rozdzielone. |

## Kamienie milowe

| Po etapie | Co jest gotowe do oceny w izolowanym środowisku |
| --- | --- |
| S03 | Usługa, trwały model i gotowy przepływ parowania. |
| S05 | Rozmowy tekstowe, nowa rozmowa, otwieranie z powiadomienia i quick reply. |
| S09 | Media, statusy, reakcje, edycje, cytaty, usuwanie i znikanie. |
| S10 | Pełniejsza obsługa kontaktów/grup, zaproszeń i uprawnień. |
| S11 | Zweryfikowany kandydat wydania. |
| S12 | Instalacja i rzeczywisty odbiór telefonu ↔ komputer. |

Nie planujemy wdrażania niekompletnego S05 do codziennego konta przed
obsługą retencji wiadomości i pełnym odbiorem. S03 przygotowuje parowanie;
rzeczywiste podłączenie w proponowanej kolejności odbywa się w S12.

## Ustalenia implementacyjne po S00

Kontrakty: [CONTRACTS.md](CONTRACTS.md), [API.md](API.md),
[TESTING.md](TESTING.md). To decyzje techniczne, nie nowe funkcje produktu:

- Cienkie adaptery QML i pomocnik Python zgodny z obecnymi backendami,
  SQLite oraz signal-cli. QML nie wykonuje bezpośrednio poleceń.
- JSON-RPC lokalnie przez stdin/stdout, `jsonRpc --receive-mode manual`,
  jedna jawna subskrypcja po otwarciu bazy. Bez HTTP/TCP i UNIX socketu.
- signal-cli **0.14.8 JVM** z JRE ≥25; izolowany odbiór na Temurin
  25.0.4.1+1. Wariant native nie przeszedł lokalnego zakończenia po EOF.
- Jedno konto i jedno leniwie tworzone natywne okno z listą rozmów;
  na małej szerokości osobny widok listy i rozmowy.
- Prywatne dane w katalogach XDG Putkina, poza katalogami wydania.
  CLI zarządza własnymi kluczami; nie podłączamy się do bazy Signal Desktop.
  Nie utożsamiamy szyfrowania transmisji z szyfrowaniem plików SQLite.
- Wewnętrzne powiadomienia Signala współdzielą istniejące karty/centrum.
  Funkcja nie zależy od tego, czy Signal Desktop obsługuje inline reply.
- Enter wysyła, Shift+Enter dodaje linię; IME i wpisywanie hjkl
  zachowują standardowe działanie pola tekstowego.
- Read oznacza faktycznie widoczną wiadomość w aktywnej rozmowie,
  a nie otwarcie centrum powiadomień.
- Nie wyłączamy Signal Desktop i jego powiadomień automatycznie.
  Współistnienie urządzeń jest opisane przy wdrożeniu.

## Rzeczywisty punkt startowy

Odczytano istniejące źródła i kontrakty:

- `core/Theme.qml` już zawiera Mocha, `accent` i `accentSecondary`.
  `shell.qml` wiąże motyw z `settings.effective`.
  Wspólne komponenty implementują gradient i nawigację.
- `NotificationBackend.qml` wyłącza inline reply,
  a `NotificationService.qml` i `NotificationEntry.qml` filtrują tę akcję.
  S05 rozszerza ten kontrakt zgodnie z nowym wymaganiem użytkownika.
- `LocalNotification.qml` jest istniejącą drogą wewnętrznych kart.
  Nie zakładamy, że jego obecny model akcji już spełnia wymagania Signala.
- Centrum ma sesyjną historię do 100 wpisów. Trwała historia Signala
  jest innym magazynem. Otwarcie centrum zmienia jego własne unread.
- `SignalTrayState.qml` dotyczy ikony zewnętrznego Signal Desktop,
  a nie odbioru wiadomości. Nowa integracja nie opiera na nim historii.
- `scripts/qs` i instalator używają UWSM, `putkin.service`,
  katalogów wydań i dowiązania `current`. Nie edytujemy opublikowanej kopii.
- S00 potwierdził Quickshell 0.3.1 / Qt 6.11.2 / Python 3.14.7.
  Przy braku CLI i Javy w PATH przygotowano prywatne narzędzia w
  `artifacts/signal-s00/tool/`, bez pakietów systemowych.
- S00 pracuje w repozytorium Git, gałąź `signal`, baza `f168407`.
  Prompty są celowo ignorowane przez Git; przywrócono ich lokalne kopie
  z katalogu źródłowego. Nie zmieniono reguł wykluczenia materiałów AI.

## Luki API wykryte w S00

- JSON-RPC nie eksportuje `expirationStartTimestamp` z sent sync.
  **S09 musi najpierw uzupełnić tę lukę w sprawdzonym wydaniu/adapterze
  i zaktualizować pin API.** Nie wolno uznać timera od odebrania za
  równoważny timerowi Signala ani odebrać S09/S12 bez rozwiązania.
- View-once-open i viewed sync istnieją w modelu biblioteki, lecz nie
  w serializerze JSON. View-once pozostaje jawnie niedostępne zgodnie
  z S09. S07 zweryfikował pominięcie pobierania takich plików w poprawionym
  CLI; pełna obsługa i retencja nadal należą do S09.
- „Usuń u mnie” jest lokalne; nie potwierdzono delete-for-me sync.
  Remote delete oraz jego sent sync pozostają wymagane.
- CLI pobiera media przed JSON; `getAttachment` czyta już lokalny plik.
  S07 używa przypiętej polityki pobierania przed JSON; nie obiecuje
  pobierania na żądanie przy `--ignore-attachments`.
- Cache/ACK CLI nie czeka na commit bridge. Zachowujemy unknown i jawną
  granicę utraty; brak obietnicy bezstratnego replay/exactly-once.

Nie usunięto z zakresu wiadomości znikających ani mediów. Konkretny
problem i warunki domknięcia zapisano w [API.md](API.md).

## Pliki przekazywane między sesjami

| Plik | Właściciel i zawartość |
| --- | --- |
| `docs/signal/ROADMAP.md` | Ten plan i odnośniki do promptów. |
| `docs/signal/STATUS.md` | Każdy etap: faktycznie wykonane prace, wyniki i następny krok. |
| `docs/signal/CONTRACTS.md` | Utworzony w S00; kolejne etapy aktualizują model, lifecycle, UI, retencję i decyzje. |
| `docs/signal/API.md` | Utworzony w S00; konkretna wersja, transport, API i schematy eventów. |
| `docs/signal/TESTING.md` | Utworzony w S00; testy, komendy, fixtures i wymagania izolacji. |
| `docs/signal/ACCEPTANCE.md` | S11 tworzy; macierz wymagań i dowodów, S12 dodaje wyniki live. |
| `docs/signal/OPERATIONS.md` | S12 tworzy; zależności, start/stop, wdrożenie, aktualizacja, rollback. |
| `docs/evidence/signal/SXX/` | Faktycznie uruchomione testy i syntetyczne zrzuty; bez danych konta. |
| `docs/status.md` | Krótki wpis każdej sesji z odnośnikiem do statusu integracji. |

ACCEPTANCE.md powstał w S11 i zawiera macierz S12. [OPERATIONS.md](OPERATIONS.md)
opisuje wdrożony pakiet, zależności, start/stop i zgodny rollback.
Każdy prompt ma własne kryteria
odbioru; konkretne API i wersje są utrwalane w repo, żeby następna sesja
nie odtwarzała decyzji z pamięci rozmowy.

## Granice i pułapki, których etapy mają pilnować

1. **Odbiór nie jest archiwum.** Sam signal-cli nie udostępnia gotowej
   historii rozmów. Trwały odbiór/outbox i semantyka zdarzeń są częścią
   naszej usługi. Nawet trwała baza nie gwarantuje braku utraty między
   odbiorem transportu a zapisem po dowolnej awarii.
2. **Timeout nie dowodzi niewysłania.** Stan unknown i rekoncyliacja
   zapobiegają bezmyślnemu ponawianiu wiadomości i tworzenia grup.
3. **Wyłączony shell nie odbiera.** Serwer może przechować oczekujące
   wiadomości w swoich granicach. Nie obiecujemy bezterminowego replay
   ani odtworzenia luk ze starej historii telefonu.
4. **Znikanie dotyczy wszystkich naszych kopii.** Baza, cache mediów,
   wersje edycji i teksty w powiadomieniach podlegają tej samej retencji.
   Przy niepracującej usłudze zaległe usunięcia następują przed pokazaniem
   historii po starcie. View-once wymaga własnego potwierdzonego kontraktu.
5. **Dane protokołu nie są buildem.** Powrót do starego kodu nie uprawnia
   do cofania kluczy/sesji CLI ani wskrzeszania wygasłych wiadomości.
6. **Atrapa nie dowodzi synchronizacji z telefonem.** Jej testy mają
   umożliwić niezależną pracę, a rzeczywista próba ma własny wynik w S12.
7. **Własna Notatka nie zastępuje drugiego rozmówcy.** Raporty zewnętrzne,
   powiadomienia o wiadomościach przychodzących i operacje grupowe
   trzeba odebrać na wskazanej rozmowie testowej. Własne wiadomości
   wysłane z telefonu są sent sync i nie generują toasta.

Te warunki są wymaganiami projektu, a nie twierdzeniem, że obecny kod
już je spełnia. S00 ma zweryfikować możliwości wybranej wersji.

Poza obowiązkową wersją: import starej historii, wiele kont, rozmowy
głosowe/wideo, nagrywanie voice notes, Stories, płatności i pełne
odtworzenie wszystkich ustawień oficjalnego klienta. Przesyłanie plików
audio/wideo jest częścią S07. Cytaty, wzmianki i wskaźnik pisania
są uwzględnione w S08. Brak pełnego wsparcia view-once ma być jawny.

## Źródła API

S00 przypiął źródła i zweryfikowane przykłady do **v0.14.8** w
[API.md](API.md). Linki `master` z pierwotnego planu poniżej służą
odszukaniu upstreamu, nie są podstawą kontraktu wersji.

- [signal-cli — polecenia](https://github.com/AsamK/signal-cli/blob/master/man/signal-cli.1.adoc):
  link, wiadomości, załączniki, grupy, reakcje, edycje i usuwanie.
- [signal-cli — JSON-RPC](https://github.com/AsamK/signal-cli/blob/master/man/signal-cli-jsonrpc.5.adoc):
  transport i subskrypcje. W S00 przypnij odnośniki do wybranej wersji.
- [Format wiadomości](https://github.com/AsamK/signal-cli/blob/master/src/main/java/org/asamk/signal/json/JsonDataMessage.java),
  [kopie wiadomości wysłanych](https://github.com/AsamK/signal-cli/blob/master/src/main/java/org/asamk/signal/json/JsonSyncDataMessage.java)
  i [read sync](https://github.com/AsamK/signal-cli/blob/master/src/main/java/org/asamk/signal/json/JsonSyncMessage.java).
- [Quickshell 0.3.1 NotificationServer](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationServer/)
  i [Notification](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/Notification/):
  możliwości serwera i obiektów, w tym inline reply.
- [Signal — urządzenia połączone](https://support.signal.org/hc/en-us/articles/360007320551-Linked-Devices),
  [raporty odczytu](https://support.signal.org/hc/en-us/articles/360007059812-Read-Receipts),
  [edycje](https://support.signal.org/hc/en-us/articles/6255134251546-Edit-Message)
  i [usuwanie dla wszystkich](https://support.signal.org/hc/en-us/articles/360050426432-Delete-for-everyone).

Dokumentacja projektu jest punktem wyjścia, a nie dowodem ukończenia
integracji. Wersje oraz realne zachowanie muszą być potwierdzone w etapach.
