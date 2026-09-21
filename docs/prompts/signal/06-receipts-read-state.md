# S06 — Dostarczenie, odczyt i stan między urządzeniami

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

**Zależności:** S05: powiadomienia i quick reply; S04: widoczność/fokus rozmowy; S02: eventy i stabilne klucze.

**Rezultat:** Rzetelne statusy wysłania/dostarczenia/odczytu oraz spójne nieprzeczytane wiadomości przy zmianie urządzenia.

## Zadanie

1. Zaimplementuj reducer raportów dostarczenia/read/viewed z API.md.
   Receipt może dotyczyć wielu timestampów i przyjść przed wiadomością
   lub odpowiedzią RPC. Zachowaj odpowiedni klucz autora, odbiorcy,
   konta i kierunku. Statusy nie cofają się przez spóźnione eventy.
2. Rozróżnij własne markery odczytu i raport od rozmówcy. Odczyt na
   drugim naszym urządzeniu oznacza aktualizację lokalnych unread,
   a nie potwierdzenie, że rozmówca przeczytał naszą wysyłkę.
   Stan grup agreguj z potwierdzeń poszczególnych odbiorców;
   nie uznawaj pierwszego receipt za „wszyscy”.
3. Przetwarzaj read sync z telefonu i wygaszaj odpowiednie unread/toasty
   bez zmiany treści historii. Sprawdź API wysyłania read sync
   komputer → telefon, także przy wyłączonych raportach do rozmówcy.
   Nie zakładaj, że sendReceipt załatwia oba kanały w każdej wersji;
   weryfikuj kod/dokumentację, a wynik live pozostaw do S12.
4. Zdefiniuj potwierdzenie odczytu: odblokowana sesja, aktywne widoczne
   okno właściwej rozmowy i faktycznie widoczne wiadomości. Sam wybór
   rozmowy za innym oknem, przewinięcie poza wiadomość, centrum
   powiadomień lub przychodzący toast nie wystarcza.
   Grupuj potwierdzenia; nie generuj RPC na każdą klatkę.
5. Uwzględnij ustawienia raportów konta/rozmówcy. Nie zmieniaj ustawień
   prywatności na telefonie, aby „naprawić” brak receipt.
   Brak informacji jest brakiem informacji, a nie „nie przeczytał”.
   Nie włączaj daemon --send-read-receipts jako zamiennika widoczności.
6. Wyświetl status w wierszu/szczegółach wiadomości; dodaj dostępne nazwy
   dla czytnika ekranu, zachowaj Material Symbols i tokeny.
   Pending/failed/unknown pozostają odróżnione od potwierdzonego sent.
7. Współdziel unread z paskiem, listą rozmów i powiadomieniami.
   Zapisz markery trwale. Otwarcie centrum powiadomień nadal zmienia
   wyłącznie sesyjny stan NotificationService, bez efektu w komunikatorze.
8. Zapisz ograniczenia dotyczące raportów dla wiadomości wysłanych
   na innym urządzeniu: nie deklaruj pełnej identyczności statusów,
   jeśli wybrana wersja nie przekazuje potrzebnych zdarzeń.

## Odbiór

- Wysłane → dostarczone → przeczytane działa na modelu bez regresji.
- Duplikat, receipt przed message, kilka timestampów i grupa z częścią
  odczytów dają właściwy wynik.
- Telefoniczny read sync usuwa lokalne unread; test oddziela go od
  zewnętrznego potwierdzenia odczytu.
- Minimalizacja, brak fokusu, blokada i centrum powiadomień nie
  wysyłają read. Widoczny zakres robi to tylko raz dla danego stanu.
- Matryca telefon ↔ komputer obejmuje również wyłączone read receipts;
  niewykonane próby rzeczywiste są jasno wymienione.

## Zakończenie sesji

Uruchom `scripts/check` i testy zachowania odpowiednie do etapu.
Dowody zapisuj w `docs/evidence/signal/S06/`, wyłącznie z danymi syntetycznymi;
nie zapisuj treści prywatnych rozmów, kluczy ani URI parowania.
Zaktualizuj `docs/signal/STATUS.md` i krótki wpis w `docs/status.md`:
zmienione pliki, rzeczywiste interfejsy, polecenia i wyniki, niewykonane
kryteria oraz dokładny następny krok. Aktualizuj kontrakty, API i plan testów,
jeśli implementacja je doprecyzowała. Odróżnij test atrapy od odbioru
z telefonem. Nie deklaruj commita bez istniejącego Git.
Zakończ krótkim opisem widocznego rezultatu i ograniczeń; nie realizuj
samodzielnie następnego etapu.
