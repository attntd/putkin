# Signal — instalacja i utrzymanie

S12, Linux x86_64/glibc. Kod, CLI i JRE stanowią jedno wydanie Putkina.
Historia i klucze nie należą do wydania. Wynik bieżącego wdrożenia oraz
prób z telefonem jest w [STATUS.md](STATUS.md) i [ACCEPTANCE.md](ACCEPTANCE.md).

## Wymagania i przypięte narzędzia

Obowiązują zależności [instalatora Putkina](../install.md), Qt Multimedia,
`ffmpeg`, `ffprobe`, `file` i `libqrencode.so.4`. Schowek wymaga `wl-copy`
i `wl-paste`; dialog pliku korzysta z Qt/portalu sesji. Testy nie zastępują
odbioru fizycznego dźwięku, silnika IME ani portalu.

Pakiet zawiera signal-cli **0.14.8 JVM + putkin-retention-2** i Temurin
JRE **25.0.4.1+1**. Źródła to konkretne oficjalne wydania:
[signal-cli v0.14.8](https://github.com/AsamK/signal-cli/releases/tag/v0.14.8)
oraz [Temurin](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4.1%2B1).
Adresy archiwów i SHA-256 są w
[`distribution.json`](../../services/signal-cli-media/distribution.json).
Nie ma pobierania przy starcie, wyboru „latest”, instalacji pakietów
systemowych ani samodzielnej usługi/autostartu Signala.

Poprawione jary odtwarza istniejący
[`scripts/build-signal-media-cli`](../../scripts/build-signal-media-cli),
według [receptury](../../services/signal-cli-media/README.md).
Budowanie wymaga przypiętego JDK; wykonanie używa dołączonego JRE.
Polityka zachowuje licencję upstream; paczka zawiera licencje dystrybucji,
a wydanie Putkina także recepturę, poprawki Java i ich sumy.

## Przygotowanie pakietu

Pobierz dwa archiwa z adresów w `distribution.json` do prywatnego katalogu.
Następnie użyj odtworzonej dystrybucji z poprawionymi jarami:

```sh
scripts/package-signal-runtime \
  --cli-archive artifacts/signal-s12/downloads/signal-cli.tar.gz \
  --jre-archive artifacts/signal-s12/downloads/jre.tar.gz \
  --patched-cli artifacts/signal-s09/cli-final \
  --output artifacts/signal-runtime
scripts/install --dry-run --destination artifacts/signal-s12/destination
scripts/install --destination artifacts/signal-s12/destination
```

Pakowanie sprawdza SHA-256 obu archiwów, wszystkie pliki oryginalnego CLI,
oba zmienione jary i kompletne drzewo końcowe wraz z prawami wykonania.
Wewnętrzne dowiązania licencji JRE są rozwiązywane do zwykłych plików.
Nieznane pliki, w tym konto dodane do dystrybucji, zmieniają sumę i blokują
pakowanie. Istniejący pakiet jest ponownie sprawdzany, nie nadpisywany.

Instalator domyślnie szuka `artifacts/signal-runtime`; inny katalog podaj
przez `--signal-runtime KATALOG`. Gotowe wydanie może samo dostarczyć
`dependencies/signal` przez `--source KATALOG_WYDANIA`. Brak lub uszkodzenie
pakietu kończy preflight przed zatrzymaniem shella. `--destination` nie
łączy się z `--activate`. Dry-run nie zmienia docelowych plików.

Próba z gotowym wydaniem, prawdziwym CLI i pustym kontem, bez sieci:

```sh
scripts/test-signal-release \
  --package artifacts/signal-s12/destination/data/putkin/current \
  --output docs/evidence/signal/S12/installed-runtime.json
```

Wydanie nie zawiera `preview/`, `tests/`, atrap CLI ani prywatnego konta.
Nie należy ręcznie zmieniać plików pod `current`.

## Aktywacja, start i zatrzymanie

Po kontroli źródeł i testach:

```sh
scripts/install --dry-run --activate
scripts/install --activate
qs ipc call signal status
qs ipc call signal openSettings
```

Instalator rozpoznaje pojedynczy Putkin, sprawdza odblokowanie i brak
operacji lock/suspend, zapamiętuje Caffeinate, zatrzymuje usługę UWSM,
ponownie sprawdza zgodność danych pod blokadą właściciela i publikuje
`current`. Sprawdza gotowość blokady, odbiornika Signala, właściciela
powiadomień oraz odtworzenie trybu Caffeinate. Zachowuje pięć buildów,
chroniąc aktywny i poprzedni. Dane `putkin/signal` nie podlegają temu limitowi.

`qs` uruchamia domyślne wydanie przez `putkin.service`. Zamknięcie okna
Wiadomości zachowuje odbiór. `systemctl --user stop putkin.service`
zatrzymuje cały cgroup, w tym bridge i JVM; wykonuj to wyłącznie przy
odblokowanej, bezczynnej sesji. Po ponownym `qs` konto i historia pozostają.
Zwykły restart nie wymaga QR. Bez skonfigurowanego konta bridge pozostaje
w idle; nie rozpoczyna parowania samoczynnie.

`signal status` zwraca wyłącznie stan procesu/konta, wersje, kody błędów
i informację o widoczności QR. Nie zwraca identyfikatora konta, URI QR,
kontaktów ani treści. `signal pair` otwiera ustawienia i rozpoczyna
parowanie; odmawia przy blokadzie lub trwającej operacji sesji.

## Dane i zgodność aktualizacji

| Ścieżka (z uwzględnieniem XDG) | Zawartość |
| --- | --- |
| `$XDG_DATA_HOME/putkin/releases/BUILD/dependencies/signal` | CLI i JRE danego wydania; bez konta |
| `$XDG_CONFIG_HOME/putkin/signal.json` | Włączenie, nazwa urządzenia, lokalne typing; 0600 |
| `$XDG_DATA_HOME/putkin/signal/` | SQLite/WAL, szkice/outbox, media/cache i `cli/` z kluczami; 0700 |
| `$XDG_DATA_HOME/putkin/signal/release.json` | Kontrakt zgodności danych; bez danych konta |
| `$XDG_DATA_HOME/putkin/signal/owner.lock` | Dziedziczona wyłączność bridge/CLI; nie usuwać |

Przy nieustawionym XDG używane są standardowe `~/.config` i `~/.local/share`.
Opublikowany backend wybiera narzędzia ze swojego wydania. Pola Narzędzia
w ustawieniach mogą pozostać puste. Sprzeczne ręczne ścieżki są odrzucane;
instalator nie przepisuje preferencji. Źródła deweloperskie nadal pozwalają
na jawne narzędzia, sprawdzając wersję i oba jary polityki.

`signal-release.json` deklaruje schematy wejściowe 0–7, docelowy v7,
format danych CLI `signal-cli-0.14.8` i politykę retencji 2. Pod blokadą
właściciela backend zapisuje minimalny kontrakt **przed** migracją
i otwarciem CLI. Nowszego schematu, innej wersji magazynu CLI ani wyższej
polityki retencji nie można otworzyć starszym kodem. Nieznane starsze
konto CLI bez tego znacznika wymaga audytu zamiast domyślnego uznania
zgodności. Kontrola SQLite uwzględnia WAL na prywatnej kopii tymczasowej;
dry-run nie tworzy SHM w danych użytkownika.

## Rollback

```sh
scripts/install --dry-run --restore
scripts/install --restore --activate
# albo konkretny zachowany build:
scripts/install --restore NAZWA_BUILDU --activate
```

Powrót przełącza kod **razem z przypiętymi CLI/JRE**, używając aktualnych
danych. Nie przywraca SQLite, kluczy/sesji, cache, usuniętych wiadomości
ani poprzednich terminów wygaśnięcia. Downgrade v7 → starszy reader lub
zmiana formatu magazynu CLI jest zatrzymana z konkretnym błędem.
Wydanie z SignalBackend bez kontraktu zgodności również jest odrzucane.

Powrót do wydania sprzed Signala jest dozwolony: taki shell nie otwiera
jego danych i nie odbiera wiadomości. Powrót do zgodnego wydania z Signalem
odtwarza odbiór; zaległe wygaśnięcia są usuwane przed publikacją historii.
Automatyczny powrót po nieudanej aktywacji także ponownie sprawdza dane,
ponieważ nowy proces mógł już wykonać migrację. Jeśli wcześniejszy reader
jest niezgodny, instalator zatrzymuje odzyskiwanie zamiast go uruchamiać.
Należy wtedy zainstalować zgodny/nowszy kod, bez cofania danych.

## Odbiór z telefonem i współistnienie

W ustawieniach Signal wybierz Połącz z telefonem i zeskanuj QR w
Signal → Połączone urządzenia. Kod żyje w pamięci i wygasa po 120 s;
nie zapisuj go w logach ani zrzutach. Po sparowaniu użyj Notatki do siebie
do jawnie testowego tekstu i małego syntetycznego pliku; poproś o odpowiedź,
edycję i reakcję z telefonu. Historia zaczyna się od połączenia urządzenia.

Toast/quick reply, raporty innego odbiorcy oraz role grupowe wymagają
wskazanej osoby/grupy testowej. Notatka i własny sent sync nie zaliczają
tych kryteriów. [Macierz odbioru](ACCEPTANCE.md) rozdziela testy lokalne
od niepotwierdzonych prób live. Nie zapisuj prywatnych rozmów jako dowodów.

Signal Desktop może pozostać osobnym urządzeniem. Jego autostart, historia
i powiadomienia nie są zmieniane przez instalator; dwa włączone klienty
mogą pokazywać dwa powiadomienia. Typing Putkina ma osobny przełącznik,
domyślnie wyłączony. View-once pozostaje niedostępny; automatyczny resend
log CLI jest wyłączony zgodnie z polityką retencji.
