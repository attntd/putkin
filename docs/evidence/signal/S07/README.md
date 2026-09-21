# S07 — dowody mediów i załączników

2026-09-20–21, checkout `/home/attntd/projects/signal`. Wyłącznie pliki,
konta i treści syntetyczne. Bez podłączenia telefonu, kontaktów live,
aktywacji shella i commita. QML używa prywatnych XDG/D-Bus i offscreen;
próby JVM używają bubblewrap bez sieci, konta i home użytkownika.

## Końcowe wyniki

| Sprawdzenie | Wynik | Dowód |
| --- | --- | --- |
| Składnia/importy całego checkoutu | 250 plików, 0 błędów | [check.log](check.log) |
| Pełna regresja backendu po zmianach GC i sent sync | 92 PASS | [python-final.log](python-final.log) |
| Pełny zestaw QtTest | 642 PASS, 0 FAIL/SKIP | [all-qml.log](all-qml.log) |
| Końcowa kontrola mediów po poprawce przyczyny fokusu i Tab | 6 PASS, 0 FAIL/SKIP | [media-controls-final.log](media-controls-final.log) |
| Produkcyjne okno, bridge, SQLite i atrapa CLI | PASS, zero błędów QML i osieroconych procesów | [media-qml.json](media-qml.json), [log](media-qml.log) |
| Natywne zdarzenia drop i callback FileDialog | PASS | [media-input.log](media-input.log) |
| Build przypiętej poprawki CLI | PASS, zgodne źródła i hash biblioteki | [cli-build.log](cli-build.log), [pochodzenie API](api-provenance.json) |
| Rzeczywiste poprawione klasy Java | PASS, limity/retencja/nazwa | [cli-policy-tests.log](cli-policy-tests.log) |
| Rzeczywisty JVM, wersja/help/RPC/EOF, puste konto | PASS | [cli-probe.json](cli-probe.json) |
| Lifecycle/reload/cleanup/idle | PASS, 60 s: 0 ticków CPU, nowych procesów i RPC | [lifecycle-idle.json](lifecycle-idle.json) |
| Regresja powiadomień S05 i odczytu S06 | PASS | [notifications-regression.json](notifications-regression.json), [receipts-regression.json](receipts-regression.json) |
| Instalator w prywatnych katalogach | 15 PASS | [install-tests.log](install-tests.log) |

Pełny zestaw QML poprzedza końcową zmianę fokusu; po niej ponownie przeszedł
zestaw mediów i check. Logi `python-tests.log` (89 PASS) i `media-tests.log`
(12 PASS) są wcześniejszymi przebiegami; końcowy pełny Python zawiera 13
testów mediów, w tym dodatkowy przypadek sent sync przed i po odpowiedzi RPC.
Wynik QtTest obejmuje także init/cleanup (4 funkcje testujące + 2 lifecycle).

## Co rzeczywiście sprawdzono

- Rzeczywiste pliki PNG, H.264/MP4, PCM/WAV i TXT: przygotowanie czterech
  plików, tekst z załącznikami, utrata źródła, trwały szkic/outbox i restart.
  Odbiór wszystkich czterech formatów oraz sent sync, współdzielone
  referencje i usunięcie ostatniej kopii. Osobno pełny proces bridge z
  rzeczywistym pipe do atrapy CLI i natywny widok Quickshell.
- Zero/limit rozmiaru, niezgodny MIME, skrypt/executable, traversal,
  symlink/hardlink, brak uprawnień, zmiana źródła podczas kopiowania,
  pełny dysk/quota, zepsuty format, limit 20 MP, utrata kopii i resztki po
  awarii. Cancel przed send, known failure/retry, unknown bez ponowienia,
  eksport bez nadpisywania i usunięcie częściowego eksportu po błędzie.
- Rzeczywiste QDragEnterEvent/QDropEvent z dwoma lokalnymi URL docierają
  do wspólnej ścieżki adaptera. FileDialog: ustawienie selectedFile i
  wywołanie accepted, **nie interakcja z portalem**. Schowek: atrapa
  executable wl-paste zwraca prawdziwy PNG; nie czytano schowka użytkownika.
- Klawiatura usuwa załącznik, wkleja obraz i wysyła same pliki. Stara
  odpowiedź nie przenosi plików między rozmowami; mediaBusy blokuje send.
  Podgląd: proporcje, Tab/Shift+Tab w obrębie nakładki, przyczyna fokusu
  myszy, Escape/powrót fokusu i oba akcenty preview/save/cancel. Qt
  odtwarza film H.264, ładuje metadane WAV; brak fizycznego wyjścia audio.
- Powiadomienie używa tej samej miniatury; lock usuwa referencję.
  Hard reload zachowuje pięć plików w historii i nie powtarza send.
  [Kompozycja](composer.png), [podgląd obrazu](image-preview.png) są
  zrzutami prawdziwego okna offscreen, z syntetycznymi danymi.
- Java test wywołuje faktycznie zmodyfikowaną metodę odbioru. Tripwire
  downloadera jest osiągany przez ordinary, pomijany dla view-once i
  expiring, dla incoming/sent sync i obu wartości ignore. Osobno realny
  katalog cache z plikiem sparse, granice rozmiaru i AttachmentStore
  z wrogą nazwą. To test polityki lokalnej, **nie transfer serwerowy**.

## Polecenia

Uruchomione z katalogu checkoutu; logi konsoli zapisano obok raportów.
Lokalne sockety asyncio oraz prywatny D-Bus wymagają dopuszczenia poza
sandboxem blokującym socketpair. Izolacja danych i offscreen pozostają.

```sh
python3 scripts/check
python3 -B -m unittest discover -s tests -p 'test_signal*.py' -v
python3 scripts/test-icons --all-qml --timeout 600 --log docs/evidence/signal/S07/all-qml.log
python3 scripts/test-icons --file tst_signal_media.qml --log docs/evidence/signal/S07/media-controls-final.log
python3 scripts/test-signal-media-input
python3 scripts/test-signal-media --output docs/evidence/signal/S07/media-qml.json
python3 scripts/test-signal-integration --idle --output docs/evidence/signal/S07/lifecycle-idle.json
python3 scripts/test-signal-notifications --output docs/evidence/signal/S07/notifications-regression.json
python3 scripts/test-signal-receipts --output docs/evidence/signal/S07/receipts-regression.json
python3 -B -m unittest discover -s tests -p test_install.py -v
python3 scripts/build-signal-media-cli \
  --source artifacts/signal-s07/source \
  --distribution artifacts/signal-s00/tool/signal-cli-0.14.8 \
  --jdk artifacts/signal-s07/jdk-25.0.4.1+1 \
  --output artifacts/signal-s07/signal-cli-0.14.8-putkin-media-1
python3 scripts/test-signal-media-cli \
  --distribution artifacts/signal-s07/signal-cli-0.14.8-putkin-media-1 \
  --jdk artifacts/signal-s07/jdk-25.0.4.1+1
python3 scripts/test-signal-cli \
  --executable artifacts/signal-s07/signal-cli-0.14.8-putkin-media-1/bin/signal-cli \
  --java-home artifacts/signal-s00/tool/jdk-25.0.4.1+1-jre \
  --output docs/evidence/signal/S07/cli-probe.json
git diff --check
```

Build wymaga nieistniejącego katalogu wynikowego. Pobrane oficjalne
źródła i JDK znajdują się w ignorowanym `artifacts/`; recepta, patche
i runtime pin są źródłami repozytorium. Biblioteka:
`8f942b9a6f758d4dc9a0c58f786354c2f75e0721d5b60416384323b33e4c8ed0`.

## Początkowe błędy i ograniczenia

Pierwsze próby nie były zielone: stare asercje migracji/schema3
([history-initial.log](history-initial.log), [python-initial.log](python-initial.log)),
worker asyncio zatrzymany przez sandbox socketpair
([media-initial.log](media-initial.log)) i nieistniejące Metrics.fadeDuration
([qml-initial.log](qml-initial.log)). Poprawiono fixture/schema4,
użyto dopuszczonego prywatnego transportu i wspólnego Metrics.panelFade.
W runnerze natywnym uzupełniono akceptację schema4, zamieniono top-level
JSON-array IPC na obiekt paths (Quickshell rozpakowuje tablicę argumentów),
a FileDialog test korzysta z zapisywalnego selectedFile. Eager AudioOutput
zastąpiono utworzeniem przy jawnym play, więc obraz nie otwiera audio.
Test viewportu S06 czeka teraz na ustabilizowany układ przed asercjami;
nie zmniejszono wymagań dotyczących widoczności. Ostrzeżenie kompilatora
Qt QBitArray/GCC16 pozostaje jawnie w media-input.log; runtime jest czysty.

Telefon, właściwy portal, schowek Waylanda i fizyczne audio pozostają
S11/S12. Dostępne kodeki zależą od instalacji, brak nagrywania voice notes.
Odbiorca otrzymuje nazwę UUID.ext; oryginalna nazwa jest zachowana lokalnie.
CLI nie udostępnia zdalnego lazy fetch ani hashy bajtów do sent-sync;
deduplikacja metadanych działa pod dokładnym kluczem wiadomości.
S09 nadal musi rozwiązać brak czasu startu znikania oraz objąć retencją
aktywny worker. View-once/expiring są obecnie jawnymi placeholderami
bez pobrania. Nie wykonywano następnego etapu.
