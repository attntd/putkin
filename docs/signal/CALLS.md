# Rozmowy głosowe 1:1 — 2026-09-26

Zakres wybrany przez użytkownika po wskazaniu
[PR #1932](https://github.com/AsamK/signal-cli/pull/1932).
PR został scalony 1 kwietnia 2026, a eksperymentalne rozmowy weszły do
[signal-cli 0.14.2](https://github.com/AsamK/signal-cli/releases/tag/v0.14.2).
Przypięte w Putkinie 0.14.8 ma ten interfejs. Wcześniejsze stwierdzenie,
że signal-cli nie obsługuje rozmów głosowych, było nieaktualne.

## Zachowanie

W nagłówku dostępnej rozmowy bezpośredniej jest przycisk słuchawki.
Jednocześnie może trwać jedno połączenie. Pasek nad listą i historią
pokazuje rozmówcę, stan, czas od połączenia, odbieranie/odrzucanie,
rozłączenie oraz wyciszenie mikrofonu. Widać go także po przejściu do
innej rozmowy i po ponownym otwarciu okna. Stan połączenia należy do
usługi, więc zamknięcie okna nie rozłącza rozmowy.

Incoming tworzy powiadomienie z akcjami Otwórz/Odbierz/Odrzuć, bez
przejmowania fokusu. DND nie pokazuje toasta; połączenie pozostaje w hubie.
Blokada usuwa dane rozmówcy z aktywnego powiadomienia i centrum oraz
blokuje rozpoczęcie i odbieranie. Trwające połączenie pozostaje aktywne.
Zakończenie usuwa powiadomienie i unieważnia jego akcje. Nie ma osobnego
dzwonka ani historii połączeń. Nieznany dzwoniący nie akceptuje samoczynnie
prośby o wiadomości; zablokowany jest odrzucany.

Sterowanie korzysta ze wspólnych NavigationButton/ControlInput i
FocusIndicator. `k` na początku listy przechodzi do paska połączenia,
`h/l` zmienia akcję, `j` wraca na listę, Enter aktywuje. Kliknięcie
nie zostawia ramki klawiatury. Litery w edytorze zachowują wpisywanie.
Bez tooltipów i dodatkowych tekstów pomocniczych.

## Proces i audio

`SignalCallService` udostępnia stan adapterowi i powiadomieniom.
`signal_calls.Calls` korzysta z istniejącego procesu signal-cli i jego
transportu JSON-RPC, ale ma własną blokadę działań, niezależną od outboxu.
Subskrypcja następuje raz na połączenie transportu. Nie ma pollingu,
zapisu audio, outboxu rozmów ani automatycznego ponawiania po reconnect.
Po utracie CLI, wyłączeniu konta lub zakończeniu shella audio jest zamykane.

CLI uruchamia osobny `signal-call-tunnel` dla połączenia. RingRTC tworzy
trzy prywatne moduły PulseAudio. `CallAudio` łączy domyślny mikrofon z
wejściem tunelu i wyjście tunelu z domyślnymi głośnikami: dwa kierunki,
każdy przez parę procesów `pacat` i pipe PCM 48 kHz/mono/s16le.
Strumienie mikrofonu ruszają dopiero przy CONNECTED po lokalnym odebraniu
lub rozpoczęciu. Mute kończy wyłącznie parę mikrofonu, bez zmiany globalnego
wyciszenia. Każde połączenie posiada własne strumienie i zadania sprzątania.
Śmierć właściciela kończy potomków; zakończenie tunelu usuwa jego moduły
według dokładnych identyfikatorów, również po częściowym błędzie setupu.

Domyślne urządzenia są odczytywane przy połączeniu. Brak urządzenia lub
śmierć strumienia kończy rozmowę z błędem audio. Przełączanie urządzeń
w trakcie rozmowy, Bluetooth i jakość redukcji echa wymagają odbioru live.
Implementacja nie gwarantuje sprzątania modułów po SIGKILL samego tunelu;
obsługuje EOF, SIGTERM i zakończenie właściciela.

## Przypięte API i poprawki

Źródła API: [CALL_TUNNEL.md dla 0.14.8](https://github.com/AsamK/signal-cli/blob/v0.14.8/docs/CALL_TUNNEL.md),
[CallManager](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/CallManager.java)
oraz [dispatcher JSON-RPC](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/jsonrpc/SignalJsonRpcDispatcherHandler.java).

| Prywatne IPC Putkina | Działanie |
| --- | --- |
| `call.status` | `accountId`, dostępność i bieżący snapshot |
| `call.start` | `accountId, conversationId`; CLI `startCall`, `recipient: [ACI]` |
| `call.accept/reject/hangup` | `accountId, callId`; CLI `acceptCall/rejectCall/hangupCall` |
| `call.mute` | `accountId, callId, muted`; lokalne strumienie |
| `call.dismiss` | usuwa wyłącznie zakończony snapshot |
| `call.changed` | zdarzenie stanu; QML ignoruje starszą odpowiedź statusu |

`subscribeCallEvents` zwraca liczbę. Zdarzenie CLI ma postać
`callEvent.params = {subscription, result: {callId, uuid, state, isOutgoing, …}}`.
Zdarzenia przed odpowiedzią subskrypcji mają ograniczony bufor. Call ID jest
signed long w RPC CLI, **stringiem w IPC/QML**, a unsigned decimal w tunelu.
Nie przechodzi przez JS Number. Dane urządzeń audio pozostają w backendzie.
ENDED nie może zostać cofnięte przez spóźniony CONNECTED. Nieoczekiwane
połączenia są odrzucane, a błędne/niejednoznaczne zdarzenie zamyka transport.

CLI nadal ma politykę retencji 2, schemat SQLite 7 i IPC 1. Nowa poprawka
`CallManager.java.patch` przekazuje prawdziwy `account.getDeviceId()` zamiast
stałego 1. Zmieniony jar i cały pakiet CLI/JRE mają nowe sumy w
`services/signal-cli-media/{runtime,distribution}.json`; nie ma migracji danych.

Tunel jest przypięty osobno w `services/signal-call-tunnel/runtime.json`:

- signal-call-tunnel: `02c84e9bfbb45e6872956ac2168adcc0b1e7a8ba`;
- RingRTC 2.65.1: `a86f8a6832cec291ef4f77e4ee9b941e5b91a01f`;
- `compatibility.patch`: senderDeviceId przy ICE, zakończenie właściciela,
  SIGTERM i limit enumeracji urządzeń;
- `audio-lifecycle.patch`: dokładne ID własnych modułów i sprzątanie
  częściowego setupu zamiast powłoki wyszukującej moduły po nazwie.

Manifest pakietu przechowuje piny, sumę binarki i wersję Rust.
Usługa weryfikuje manifest i binarkę przed ustawieniem
`SIGNAL_CALL_TUNNEL_BIN`; nie przejmuje tej zmiennej z pulpitu.
Brak poprawnego tunelu wyłącza rozmowy, zachowując wiadomości.
Instalator dołącza binarkę i licencję AGPL do `dependencies/signal-calls`.
Źródła i obie poprawki są dostępne przez wskazane repozytoria oraz to repo.

## Budowanie i odbiór

Runtime: PipeWire/PulseAudio, `pactl`, `pacat`. Kompilacja: Git, Cargo/Rust,
Clang, CMake, Protobuf, pkg-config i standardowe narzędzia C/C++.
`config/packages/arch.txt` zawiera pakiety. Instalator przygotowuje tunel
automatycznie; samo budowanie nie otwiera urządzeń ani konta.

```sh
scripts/prepare-signal --cache artifacts/signal-cache
scripts/prepare-signal-calls --cache artifacts/signal-cache
scripts/test-signal-calls --native
```

`--offline` wymaga wypełnionego cache. Cargo.lock i commity są przypięte;
suma binarki zależy od platformy/toolchainu, nie deklarujemy identycznej
binarki Rust przy różnych kompilatorach. Gotowy pakiet i wszystkie pliki
zainstalowanego wydania są objęte kontrolą sum.

Runner sprawdza produkcyjny bridge/transport/SQLite z atrapą CLI i audio,
interfejs Qt, a `--native` dodatkowo prawdziwy tunel, RingRTC i procesy PCM
na prywatnym PipeWire z wirtualnymi urządzeniami. Ma prywatne XDG/D-Bus;
tunel jest bez sieci i bez urządzeń sprzętowych. Test Java uruchamia
rzeczywisty serializer CLI dla device ID 1, 2, 7 oraz ID spoza dokładności JS.
Wyniki i granice odbioru są w [statusie](../status.md#rozmowy-głosowe-signal--2026-09-26).

Poza tym zakresem: rozmowy grupowe, wideo, voice notes i Call Links.
Testy izolowane nie potwierdzają transmisji WebRTC przez sieć Signala
ani jakości mikrofonu/głośników. Wymagany jest test wychodzący i przychodzący
z drugim urządzeniem: dźwięk w obie strony, mute, rozłączenie z obu stron,
odmowa, timeout, reconnect, blokada, zamknięcie okna i restart shella.
