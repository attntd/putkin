# Signal — zweryfikowane API S00

## S12 — lokalna diagnostyka i preflight

Pin protokołu pozostaje **0.14.8 JVM + putkin-retention-2**, SQLite v7
i bridge IPC v1. `distribution.json` przypina również całe CLI oraz
Temurin JRE 25.0.4.1+1, po walidacji oficjalnych archiwów. Metody sieciowe
nie zmieniły się. [Pakowanie i obsługa](OPERATIONS.md).

Publiczne IPC Quickshell `signal`:

- `status()` — JSON: `state`, `accountState`, `schemaVersion`, `cliVersion`,
  `errorCode`, `linkError`, `qrVisible`, `processId`. Bez tożsamości konta,
  QR/URI, kontaktów i treści.
- `openSettings()` — otwiera sekcję Signal, również gdy wcześniejsze
  ustawienia pokazywały inną sekcję; bool przyjęcia.
- `pair()` — otwiera tę sekcję i zleca istniejące `account.link.start`.
  Odmawia dla linked, blokady lub trwającej operacji sesji. Bool potwierdza
  przyjęcie żądania, a wynik parowania pochodzi z normalnego stanu usługi.

Nowe kody bridge: `runtime_invalid` (niezgodne pliki/prawa CLI/JRE)
i `incompatible_release` (niezgodny kontrakt danych/kodu). Uszkodzona lub
niedostępna baza nadal zwraca `storage_error`. Żaden kod nie zawiera
surowego błędu serwera ani prywatnego payloadu.

Audyt 2026-09-20. Docelowa baza: **signal-cli 0.14.8, dystrybucja JVM**,
tag `v0.14.8`, commit `22b028bbb9cee8f6aa22af71c6b3e9d09028a16a`.
To nie jest odbiór komunikacji z telefonem. Nie zarejestrowano ani nie
sparowano konta, nie wysłano wiadomości.

## Odbiór S11 — bez zmiany publicznego API

SQLite v7, IPC v1 i oba piny putkin-retention-2 pozostają bez zmian.
Powtórzono lokalną próbę binarki/JVM bez konta i testy rzeczywistych klas
mediów/retencji. [Dowody S11](../evidence/signal/S11/README.md).
Wyłącznie jawny `--test-scenario` dodaje `test.metrics`: liczniki aktywnych
terminów retencji/typing, oczekujących RPC/late results, zajętości outputu
oraz workerów mediów/katalogu. Metoda nie istnieje w capabilities produkcji,
nie zawiera treści/ścieżek/kluczy i służy pomiarowi odbiorowemu.

## Grupy i kontakty — S10, 2026-09-21

Nadal **signal-cli 0.14.8 JVM + putkin-retention-2**, IPC v1; SQLite v7.
Przeczytano źródła tagu v0.14.8, bez zmiany przypiętego wydania CLI:
[ListContactsCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/ListContactsCommand.java),
[JsonContact](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonContact.java),
[ListGroupsCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/ListGroupsCommand.java),
[UpdateGroupCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/UpdateGroupCommand.java),
[GroupHelper](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/GroupHelper.java).

- `listContacts(account, allRecipients:true)` eksportuje ACI `uuid`, number,
  username, nazwę kontaktu, `profileSharing`, isBlocked/unregistered i profile
  (givenName/familyName/about/hasAvatar). Wariant z `recipient:[ACI]` odświeża
  profil. Wyszukiwanie numeru/username nadal używa `getUserStatus`, bez send.
- `listGroups(account,detailed:true)` eksportuje members (uuid/number/isAdmin),
  pendingMembers, requestingMembers, admins, banned, isMember/isTerminated,
  permissionAddMember/permissionEditDetails/permissionSendMessage i groupInviteLink.
  Nie eksportuje revision ani osobnego stanu linku z wymaganiem akceptacji.
  UI oferuje jawne ustawienie trybu; nie udaje odczytu nieobecnego pola.
- `updateGroup` bez **groupId:string** tworzy grupę; wynik zawiera groupId.
  Aktualizacje zawsze mają jawny ID. Pola name/description/avatar, member,
  removeMember, admin/removeAdmin, setPermissionAddMember/EditDetails/SendMessages,
  link i resetLink zachowują nazwy JSON-RPC. Listy adresów używają ACI bez prefiksu.
  Uprawnienia zapisu: `every-member` / `only-admins`; odczytu: EVERY_MEMBER /
  ONLY_ADMINS. `member` przyjmuje również oczekującą prośbę, `removeMember`
  ją odrzuca. Puste updateGroup z ID przyjmuje własne zaproszenie.
- `joinGroup(uri)` zwraca groupId i opcjonalne `onlyRequested:true`.
  `quitGroup(groupId:string,admin?:[ACI])` opuszcza/odrzuca zaproszenie;
  ostatni administrator przekazuje rolę. Nie używamy opcji delete.
  [JoinGroup](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/JoinGroupCommand.java),
  [QuitGroup](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/QuitGroupCommand.java).

Akceptacja używa `sendMessageRequestResponse(recipient:[ACI],type:"accept")`.
[Polecenie](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendMessageRequestResponseCommand.java)
nie eksportuje wyniku wysyłki zwracanego przez Manager. Lokalny
[SyncHelper](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/SyncHelper.java)
ustawia profile sharing i wysyła sync. Potwierdzamy readback `profileSharing`,
**bez obietnicy odebrania akceptacji przez telefon**. `block` / `unblock`
używają recipient:[ACI] lub groupId:[ID], a wynik blokady jest ponownie
odczytywany. Ich Manager wysyła blocked list / message-request sync;
nie utożsamiamy tego z potwierdzonym stanem wszystkich urządzeń.
[Block](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/BlockCommand.java),
[Unblock](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/UnblockCommand.java).

`JsonSyncMessage` nie eksportuje osobnego messageRequestResponse. Zdarzenia
sync oraz wiadomości/aktualizacje grup wyzwalają scalany readback katalogu.
Bez okresowego pollingu. Nie importujemy historii sprzed sparowania.
Avatar: [getAvatar](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/GetAvatarCommand.java)
przyjmuje groupId:string albo profile:ACI i zwraca `{data:base64}`.
Bridge ogranicza wynik, dekoduje do prywatnego JPEG i przekazuje QML tylko
lokalny URL. Brak avatara daje placeholder. Upload jest sprawdzanym obrazem
PNG/JPEG/WebP do 2 MiB, pomniejszanym do 384 px; QML nie przekazuje bajtów.

Nowe IPC (zawsze accountId):

| Metoda | Parametry i wynik |
| --- | --- |
| directory.refresh / directory.profile | Bez dodatkowych pól / serviceId; aktualny katalog / profil |
| directory.avatar | serviceId albo groupId; target i lokalny avatar URL |
| group.get | groupId; członkowie, stan, role i jawne canAdmin/canEdit/canAdd/canAccept/canLeave |
| group.create | operationId, name, members:[ACI], avatar?:lokalny plik; trwała operacja i prawdziwy groupId |
| group.join | operationId, uri; operacja, grupa, ewentualnie requesting |
| group.update | operationId, groupId, action: details/add/remove/promote/demote/approve/deny/permissions/link/accept i pola akcji |
| group.quit | operationId, groupId, confirm:groupId, admins?:[ACI] |
| group.operations | Ostatnie operacje, najpierw nierozstrzygnięte; bez surowych błędów, payloadów i linków |
| group.reconcile | operationId; readback / kandydaci; jawne groupId + confirm:use-existing-group wiąże wskazaną grupę |
| conversation.accept | conversationId; ponownie odczytana lokalna akceptacja |
| conversation.block | conversationId, blocked:bool; blokada wymaga confirm:conversationId |
| conversation.preferences | conversationId, hidden:bool; wyłącznie lokalne ukrycie |

`conversation.notifications(muted)` pozostaje lokalną operacją S05.
`conversation.get` dodaje canRead, requestState, blocked, hidden, avatar,
canSetExpiration; canSend uwzględnia akceptację i członkostwo.
`message.get` dodaje systemChanges dla lokalnych, typowanych obserwacji grup.
Zmiana katalogu/operacji publikuje account.directory.changed,
conversation.changed / directory.operation.changed po COMMIT.

## Usuwanie i znikanie — S09, 2026-09-21

Aktualny runtime: **0.14.8 JVM + putkin-retention-2**, SQLite **v6**,
IPC **v1**. Poniższe sekcje S00–S08 opisują historię interfejsów;
ograniczenie `expiring_unsupported` dla nowych zwykłych wiadomości zostało
usunięte. View-once pozostaje niedostępny.

| Interfejs | Parametry i wynik |
| --- | --- |
| `message.delete` lokalne | accountId, conversationId, messageId, scope:`local`. Wynik messageId/scope; nie wysyła RPC. |
| `message.delete` zdalne | Te same ID, scope:`everyone`, versionTimestampMs i opcjonalny operationId UUID. Wynik wspólnej trwałej operacji; `kind:delete`. |
| `conversation.expiration` | accountId, conversationId, seconds:0..2419200. Zero wyłącza; wynik aktualnej rozmowy po odpowiedzi CLI. Bez automatycznego retry przy unknown. |
| `message.get/page` | Dodatkowo expirationSeconds, expirationStartMs, expiresAtMs, hiddenLocal, canDeleteLocal/canDeleteRemote. Lokalne usunięcia nie wchodzą w page. |
| `message.redacted` | accountId, conversationId, messageId; po COMMIT i próbie GC/checkpointu. Odbiorca natychmiast zwalnia kontrolowane kopie treści. |
| `draft.changed` | Przy usunięciu cytatu także quoteRemoved:true i nowa revision; tekst szkicu pozostaje. |

Rzeczywiste metody sprawdzono w przypiętych źródłach:
[RemoteDeleteCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/RemoteDeleteCommand.java),
[UpdateContactCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/UpdateContactCommand.java),
[UpdateGroupCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/UpdateGroupCommand.java).
`remoteDelete` przyjmuje targetTimestamp oraz recipient:[ACI], groupId:[ID]
albo noteToSelf:true. `updateContact` bierze **recipient:string** i
expiration:int; `updateGroup` bierze **groupId:string**, zawsze jawnie podane,
i expiration:int. Brak uprawnień jest błędem CLI, bez lokalnego udawania sukcesu.
Usunięcie przychodzące nadal jest w dataMessage.remoteDelete.timestamp,
a własne usunięcie z telefonu w spłaszczonym syncMessage.sentMessage.

Dodatkowy pin obejmuje dwa jary:

- libsignal-cli: `5551eae0dc4efddf89039b125c20ac8520793141e31c9af4c6dc1d43c9e1db9d`
- signal-cli: `f6c04e0856530875bbb2f1b4f4d2b621408c057b089e2b87567c69d65e2fa502`

[Recepta i kod](../../services/signal-cli-media/README.md) dopisują
`syncMessage.sentMessage.expirationStartTimestamp` z istniejącego pola
biblioteki, poprawiają milisekundy startu Note-to-Self i eksportują rzeczywiste
`send.result.expiresInSeconds` po zamknięciu buildera wiadomości. Produkcja
wymaga tego pola w wyniku send. Sprawdzenie listContacts/listGroups przed
wysłaniem pozostaje kontrolą dostępności; nie stanowi jedynego źródła timera.
Edycje nie nadpisują retencji pierwotnej wiadomości.

CLI uruchamia się z istniejącą opcją **--disable-send-log**. Poprawiona klasa
[MessageSendLogStore](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/storage/sendLog/MessageSendLogStore.java)
usuwa także zastane payloady resend przy tym trybie. Konsekwencją jest brak
automatycznej naprawy wiadomości, której rozmówca nie mógł odszyfrować.
Nie dodano delete-for-me ani viewOnceOpen API. Zasady czasu/GC i granice
fizycznego usuwania są w [kontrakcie S09](CONTRACTS.md#usuwanie-i-retencja--s09-2026-09-21).

## Interakcje — S08

IPC pozostaje v1, SQLite v5. Nadal wymagany signal-cli **0.14.8 JVM +
putkin-media-1** z S07; etap nie zmienia jego dystrybucji ani aktywnego konta.
Odczytano przypięte źródła: [SendCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendCommand.java),
[SendReactionCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendReactionCommand.java),
[SendTypingCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendTypingCommand.java),
[JsonQuote](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonQuote.java),
[JsonMention](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonMention.java),
[JsonTypingMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonTypingMessage.java)
i [JsonTextStyle](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonTextStyle.java).
Hashe odczytanych plików: [proweniencja](../evidence/signal/S08/api-provenance.json).

| IPC / zdarzenie | Kontrakt |
| --- | --- |
| `message.edit` | accountId, conversationId, messageId, versionTimestampMs, text, opcjonalne mentions/styles i operationId. Wynik to trwała operacja, nie potwierdzenie wysłania. |
| `message.react` | Te same identyfikatory, emoji, remove:boolean i operationId. Własnego autora reakcji wyznacza konto, nie wejście QML. |
| `message.send` | Rozszerzenie o quoteMessageId, mentions i styles. Cytat rozwiązywany we wskazanej rozmowie/konto. |
| `draft.set/get` | Opcjonalne composition z quoteMessageId i mentions; wspólna rewizja szkicu tekstowego, trwałość po restarcie. |
| `typing.set` | accountId, conversationId, active:boolean. Ulotne, bez outbox/retry po reconnect. |
| `typing.changed` | accountId, conversationId, authors — pełna aktualna lista ACI. Nie tworzy rozmowy, historii, unread ani toasta. |
| `message.get/page` | canEdit/canReact/canReply, versionTimestampMs, editedTimestampMs, quote, mentions/styles, reactions z count/mine/people, interaction oraz maks. 11 podsumowań wersji. |

RPC edycji to `send` z **editTimestamp aktualnej wersji**, message oraz
zachowanymi załącznikami/cytatem. Reakcja to `sendReaction` z targetAuthor
(ACI bez prefiksu), targetTimestamp, emoji, remove i recipient/groupId/
noteToSelf. Oba RPC wymagają sprawdzonej listy `results`, nie tylko timestamp.
Cytaty używają quoteTimestamp/quoteAuthor/quoteMessage. Wzmianki używają
`mention:["start:length:ACI"]`, długości i pozycje są UTF-16. `textStyle`
obsługuje BOLD/ITALIC/SPOILER/STRIKETHROUGH/MONOSPACE.
Odbiór cytatu czyta id/authorUuid/text, wzmianki uuid/start/length,
pisanie action STARTED/STOPPED, timestamp i opcjonalne groupId.

Putkin sprawdza własność, możliwość wysyłania, bieżącą wersję i znany limit
**10 edycji / 24 godziny**; Notatka bez limitu czasu. Są to ograniczenia
klienta według [oficjalnego kontraktu Signala](https://support.signal.org/hc/en-us/articles/6255134251546-Edit-Message),
ponieważ CLI przekazuje edycję bez własnego magazynu historii. Nie można
policzyć zmian sprzed odebrania historii ani zagwarantować przyjęcia przez
inne urządzenie. Wynik RPC jest potwierdzeniem CLI, nie odbiorem telefonu.

**Ustawienie pisania jest lokalne.** `typingIndicators` w prywatnym
signal.json domyślnie false; przełącznik „Wskaźnik pisania w Putkinie”.
[ManagerImpl](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/ManagerImpl.java)
nie sprawdza telefonowego ustawienia w sendTypingMessage, a
[JsonSyncMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonSyncMessage.java)
nie eksportuje configuration. updateConfiguration odmawia na urządzeniu
połączonym. Nie obiecujemy synchronizacji tego przełącznika z telefonem.
Start maksymalnie co 8 s w bridge; impuls edytora maks. co 2 s, tylko przy
zmianie tekstu. STOP po 5 s bez aktywności, przy blur/send/zmianie rozmowy/
zamknięciu/lock/zmianie konfiguracji; po utracie transportu stan jest
czyszczony lokalnie, zdalny klient wygasza go sam. Odbiór wygasa po 15 s.

## Media i załączniki — S07

IPC **v1**, SQLite **v4**, signal-cli **0.14.8 JVM + putkin-media-1**.
Pin i odtwarzalny build: [polityka CLI](../../services/signal-cli-media/README.md).
Bridge weryfikuje SHA-256 poprawionej biblioteki przed JSON-RPC; zwykłe
0.14.8 daje `media_policy_required`, bez subskrypcji. Zastępuje to dawną
bramkę `--ignore-attachments`: media są teraz odbierane, a pomijanie
view-once/znikających odbywa się przed pobraniem w CLI.

| IPC | Parametry / wynik |
| --- | --- |
| `attachment.stage` | accountId, conversationId, paths:[lokalne ścieżki lub file:///]; atomowy wynik attachments. 1–8 plików. |
| `attachment.paste` | accountId, conversationId; jednorazowy wl-paste image/png, następnie ta sama ścieżka prepare/stage. |
| `attachment.remove` | accountId, conversationId, attachmentId; usuwa wyłącznie referencję szkicu. |
| `attachment.save` | accountId, attachmentId, destination; kopia 0600 po akcji użytkownika, bez nadpisywania/symlinków. |
| `attachment.open` | accountId, attachmentId; zweryfikowany lokalny URL dla rozpoznanych formatów; adapter otwiera go tylko w odpowiedzi na kliknięcie. |
| `draft.get/set` | dodatkowe attachments; treść zachowuje wcześniejszy revision/CAS. |
| `message.send` | dodatkowe attachmentIds:[UUID], tekst może być pusty przy plikach; quickReply odrzuca attachmentIds. |
| `attachments.changed` | accountId, conversationId po COMMIT. |
| `message.get/page` | attachments:{attachment_id,content_type,size_bytes,filename,state,errorCode,voiceNote,url,thumbnail,preview}[]; operationId i safeRetry dla bezpiecznych działań outboxu. |

Rzeczywisty RPC to `send` z **attachment:[ścieżka,...]** (liczba pojedyncza),
message i dotychczasowym adresowaniem. Nie ma base64 w QML ani wywołania
getAttachment. CLI pobiera przed receive; brak możliwości odzyskania na
żądanie pliku pominiętego przez limity. Źródłem odbioru jest kontrolowany
`cli/attachments/<id>`; filename służy wyłącznie do wyświetlania.
Wysyłane ścieżki mają basename UUID + wykryte rozszerzenie; oryginalna
nazwa pozostaje w lokalnej karcie, odbiorca otrzymuje nazwę zarządzaną.

Limity Putkina: 32 MiB/plik, 8 plików i 128 MiB/kompozycję,
512 MiB oryginałów/stagingu/miniatur łącznie; osobny cache CLI 512 MiB.
CLI sprawdza rozmiar wskaźnika, wolne miejsce i przekazuje limit 40 MiB
szyfrogramu do odbiornika; większe pliki mają jawny stan niedostępny.
Dekoder: 20 MP, worker do 12 s/wywołanie, 1 GiB przestrzeni adresowej,
10 s CPU, 40 MiB pliku i 64 deskryptory. Obraz daje JPEG 384 px oraz
1600 px. Qt ładuje te pochodne asynchronicznie bez cache; audio/wideo
korzysta z lokalnego oryginału dopiero w otwartym podglądzie.
Sent sync koreluje dokładny klucz autor/rozmowa/timestamp, porównując
tekst i metadane MIME/rozmiar/voice-note, ponieważ lokalny identyfikator
CLI zmienia się po uploadzie. Nie jest to porównanie hashy treści pliku.
Kopie CLI duplikatów/tombstone trafiają do trwałej kolejki cleanup.

Podprocesy mają parent-death; na anulowanie bridge czeka na zakończenie
bieżącego workera i usuwa jego kopie. Nie emituje fikcyjnego procentu.

Sprawdzone API Qt 6.11.2: [FileDialog](https://doc.qt.io/qt-6/qml-qtquick-dialogs-filedialog.html),
[MediaPlayer](https://doc.qt.io/qt-6/qml-qtmultimedia-mediaplayer.html),
[Drag](https://doc.qt.io/qt-6/qml-qtquick-drag.html). Qt Multimedia/FFmpeg
przeszły lokalnie H.264/MP4 oraz PCM/WAV; obrazy PNG/JPEG mają generowane
pochodne. Pozostałe kodeki zależą od instalacji. Błąd daje kartę z zapisem
i otwarciem; nie obiecujemy nagrywania ani wysyłania natywnych voice notes.
Wymagane narzędzia: file, ffprobe, ffmpeg, prlimit; wl-paste dla schowka.

## Odczyt i potwierdzenia — S06

IPC **v1**, SQLite **schemaVersion 3**, bez zmiany przypiętego CLI.
Ponowny audyt źródeł 0.14.8: [adresy i SHA-256](../evidence/signal/S06/api-provenance.json).

| Interfejs | Dane | Znaczenie |
| --- | --- | --- |
| `messages.read` | accountId, conversationId, messageIds:[UUID] (1–100) | Zapis tylko podanych incoming text/media; wynik messageIds zawiera nowo odczytane ID. Duplikat zwraca pustą listę. |
| `messages.read` — koniec rozmowy, 2026-09-24 | accountId, conversationId, throughMessageId:UUID (zamiast messageIds) | Czyta maks. 100 starszych incoming text/media według `(sort_ms,message_id)`, łącznie z granicą. ID granicy musi należeć do konta/rozmowy. Wynik `messageIds` i `hasMore`; kolejne żądanie powtarza tę samą granicę. Nowsze wpisy i placeholdery pozostają bez zmian. |
| `message.get`, `messages.page` | readAtMs, unread | Odczyt lokalny/własnych urządzeń, odrębny od statusu wysyłki. |
| Te same rekordy | status: sent/delivered/read/viewed lub dotychczasowe queued/sending/failed/unknown/cancelled | Status potwierdzony; nie regreduje od spóźnionego receipt. Incoming zachowuje status received. |
| Te same rekordy | receiptSummary:{total,delivered,read,viewed}, receipts:[{serviceId,deliveryTimestampMs,readTimestampMs,viewedTimestampMs}] | Osobno każdy odbiorca. total=null przy nieznanej grupowej liście wysyłki; null timestamp to brak konkretnego raportu, nie brak odczytu. |
| `message.read` | accountId, conversationId, messageId | Po COMMIT, także przy read sync; używany do wygaszania kart bez zwrotnej wysyłki. |
| `conversation.changed`, `message.changed` | dotychczasowe ID | Odświeżenie list/liczników/wierszy po COMMIT. |

Wewnętrzne kolejki rozróżniają submitted i unknown. `operation.status.state`
pozostaje stanem wysyłki outboxu; delivered/read/viewed należą do wiadomości.
RPC odczytu nie jest udostępniane przez publiczny IpcHandler shella.

Zweryfikowany
[SendReceiptCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendReceiptCommand.java):
`sendReceipt` przyjmuje **recipient jako string**, `targetTimestamp` jako
listę integerów oraz `type:"read"`; bridge dodaje `account`. To nie jest
tablica recipient używana przez `send`. Jeden autor na request, maks. 100
timestampów w polityce Putkina. Nie wysyłamy viewed dla przeczytanego tekstu.

[ManagerImpl.sendReceiptMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/ManagerImpl.java)
sprawdza lokalną zsynchronizowaną konfigurację read receipts przed raportem
zewnętrznym; potem, jeżeli adres ma ACI, wywołuje własne sync.
Wyłączone raporty zewnętrzne mogą zwrócić prawidłowe `results:[]`.
[SyncHelper.sendSyncReceiptMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/SyncHelper.java)
buduje oddzielne read lub viewed sync. Zwracany wynik `sendReceipt` nie
jest potwierdzeniem dostarczenia tego sync do telefonu. Ustawienia konta
są respektowane przez CLI, nie modyfikowane przez Putkina; nieznane
ustawienie rozmówcy ani brak receipt nie uprawniają do stwierdzenia
„nie przeczytał”. Bez ACI nie obiecujemy synchronizacji.

[JsonSyncMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonSyncMessage.java)
eksportuje readMessages, ale nie viewed sync.
[JsonSyncDataMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonSyncDataMessage.java)
nie eksportuje odbiorców/ich statusów z sent sync. Dlatego lokalna wysyłka
grupowa ma mianownik z wyników send, a grupa wysłana na innym urządzeniu
pozostaje z nieznanym mianownikiem. Bieżącego składu grupy nie traktujemy
jako historycznej listy odbiorców. Dla direct używamy destination ACI,
ale kompletność późniejszych raportów z innych urządzeń pozostaje live S12.

SQLite v3 przejmuje dotychczasowe pending read/receipt bez treści,
przechowuje marker po przeczytaniu i nie cofa bazy przy rollbacku kodu.
Próby syntetyczne i osobna macierz telefonu: [TESTING.md](TESTING.md#raporty-i-odczyt--po-s06).

## Powiadomienia i quick reply — S05

IPC pozostaje **v1**, SQLite ma **schemaVersion 2**. Migracja
`signal_schema_v2.sql` tworzy `reply_drafts` i `conversation_notifications`
w jednej transakcji. Konta, klucze, historia, outbox i szkice S04 zachowują ID.
Starszy kod odrzuci schemat 2; nie cofać bazy podczas rollbacku programu.
`signal-cli` pozostaje przypięty do 0.14.8 JVM; brak nowych metod CLI.

| Metoda / zdarzenie | Parametry / dane | Znaczenie |
| --- | --- | --- |
| `reply.draft.get` | accountId, conversationId | text, revision, operationId/null, state, safeRetry |
| `reply.draft.set` | accountId, conversationId, text, expectedRevision | CAS osobnego szkicu; aktywna/nieznana/nieudana operacja blokuje nową intencję |
| `message.send` | dotychczasowe pola + draftContext:`quickReply`, draftRevision | Ten sam outbox; atomowo wiąże szkic z UUID operacji i usuwa jego kopię tekstu |
| `conversation.notifications` | accountId, conversationId, muted:boolean | Trwałe, lokalne wyciszenie rozmowy Putkina; zwraca conversation.get z muted |
| `message.received` | accountId, conversationId, messageId | Wyłącznie pierwszy COMMIT przychodzącego remote; nigdy duplicate, sent sync ani event techniczny |
| `reply.draft.changed` | accountId, conversationId, revision | Zapis szkicu/powiązanie z outboxem po COMMIT |

`draft.get/set` pozostają szkicem pełnego edytora. Pominięte draftContext
oznacza dotychczasowy `composer`. Odpowiedź nie usuwa szkicu okna.
Szkic quick reply po enqueue czyta tekst **z rekordu wiadomości outboxu**,
także przy failed/unknown; brak drugiej trwałej kopii payloadu. Po sent lub
cancelled udostępnia pusty tekst i umożliwia nowy szkic. Wygaśnięcie treści
outboxu usuwa ją też z reply. `operation.retry` działa na tym samym UUID,
wyłącznie dla safeRetry; unknown nie ma automatycznego ani domyślnego resend.
Po utracie odpowiedzi QML odczytuje szkic, nie powtarza message.send.
Historia sesji powiadomień znika po reloadzie, szkic/operacja pozostają w DB.

`core/SignalNotifications` ma jawnie przekazane SignalService,
NotificationService i MessagesController. Lokalna karta ma deskryptor
`{serviceId:"signal",accountId,conversationId,messageId}`. Tytuły, tekst,
zewnętrzne hints i Signal Desktop nie wyznaczają adresu ani akcji.
Odczyt message.get + conversation.get potwierdza aktualne rekordy;
S04 ponawia sprawdzenie rozmowy przy otwarciu. Zmiana konta/odłączenie,
brak rozmowy i blokada wyłączają akcje.

Potwierdzono ponownie [NotificationServer 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationServer/)
i [TextEdit Qt 6.11.2](https://doc.qt.io/qt-6/qml-qtquick-textedit.html).
Wewnętrzny reply nie korzysta z protokołu zewnętrznych klientów.
`inlineReplySupported` pozostaje false; test prywatnego D-Bus potwierdza
tylko body/actions/icon-static. Enter sprawdza inputMethodComposing,
preeditText, Shift i autorepeat; IME na fizycznej sesji pozostaje S11/S12.

## Okno wiadomości i rozwiązywanie odbiorcy — S04

IPC v1 i schemaVersion 1, bez migracji bazy. Adapter okna zawsze przekazuje
jawny accountId. Dodatkowe metody:

| Metoda | Parametry | Wynik |
| --- | --- | --- |
| `conversation.get` | accountId, conversationId | Istniejący rekord rozmowy lub not_found/account_mismatch |
| `recipient.resolve` | accountId (obowiązkowy), query | Rozwiązuje E.164 lub nazwę użytkownika i zwraca pustą/istniejącą rozmowę; tylko przy ready |

Rekord rozmowy dodaje searchText, unreadCount i canSend; title wykorzystuje
zapisany katalog kontaktów/grup. account.directory dodaje blocked dla
kontaktu, blocked/isMember/canSend dla grup. Dane protokołu pozostają w
adapterze. Nie zmieniono znaczenia `conversation.open.serviceId` (ACI).
Adres wspólnego UI ma osobne `{serviceId:"signal", accountId, conversationId}`.

Zweryfikowano przypięte źródła **v0.14.8**:
[getUserStatus](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/GetUserStatusCommand.java)
przyjmuje recipient:[numer] lub username:[nazwa]; wynik jest tablicą
recipient, number/username, uuid, isRegistered. Tylko jeden pasujący,
zarejestrowany ACI tworzy rozmowę. Żaden lookup nie wywołuje send.
[ListGroups](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/ListGroupsCommand.java)
udostępnia isMember/isBlocked/isTerminated, permissionSendMessage i admins;
[JsonContact](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonContact.java)
udostępnia isBlocked. Bridge blokuje enqueue przy braku konta/uprawnień,
a preflight przed send ponownie odczytuje aktualny stan CLI.

Natywny routing: `quickshell ipc --path /ścieżka/shell.qml call messages open`
lub `... call messages openConversation signal ACCOUNT_UUID CONVERSATION_UUID`.
To trzy argumenty tekstowe, bez składania polecenia na podstawie treści
powiadomienia. S05 powinien przekazać dokładnie taki adres do kontrolera.

UI: sprawdzono [FloatingWindow 0.3.1](https://quickshell.org/docs/v0.3.1/types/Quickshell/FloatingWindow/),
[ListView Qt 6.11](https://doc.qt.io/qt-6/qml-qtquick-listview.html)
i [TextArea](https://doc.qt.io/qt-6/qml-qtquick-controls-textarea.html).
TextArea korzysta ze standardowego preedit/inputMethodComposing; Enter
wysyła poza kompozycją, Shift+Enter zostaje wejściem Qt. ListView jest
wirtualizowany, a restore kotwicy korzysta z forceLayout/positionViewAtIndex.

## IPC konta i parowania — S03

Wersja IPC i schemat SQLite pozostają 1. Snapshot dodaje `configuration`
(enabled, deviceName, opcjonalne executable/javaHome), `linkAttempt`,
`linkError`, `reconciling`. Nie zawiera URI ani macierzy QR.

| Metoda | Parametry i wynik |
| --- | --- |
| `account.configure` | Częściowe enabled/executable/javaHome/deviceName; accepted po trwałym zapisie, stan procesu wraca zdarzeniem. Nie zmienia konfiguracji podczas próby link. |
| `account.link.start` | deviceName; zwraca attemptId, ponowny start tej samej próby zwraca to samo ID. Włącza integrację i najpierw sprawdza konta. |
| `account.link.cancel` | attemptId; odrzuca obce ID, czyści QR, zamyka CLI i rekoncyliuje możliwy sukces telefonu. |
| `account.refresh` | Bez parametrów; listAccounts i lokalny katalog przy ready, ponowna kontrola narzędzia przy idle/failed. |
| `account.directory` | Bez parametrów; contacts: serviceId/number/name/profileName, groups: groupId/name. Bez wiadomości. |
| `account.history.clear` | accountId zgodne ze snapshotem, confirm=`delete-local-history`; tylko disabled i bez CLI. Zwraca cleared po transakcji i checkpoint. |

Zdarzenie `account.link.qr` zawiera attemptId, modules (kwadratowe wiersze
0/1), expiresAtMs. Jest efemeryczne, nie jest częścią historii ani statusu.
`account.link.cleared` kończy jego życie, `account.directory.changed`
ogłasza commit katalogu, `history.cleared` oznacza usunięcie historii.
SignalService nie przekazuje QR do ogólnego sygnału changed.

Źródła przypiętego wydania sprawdzono ponownie w S03:

- [StartLinkCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/StartLinkCommand.java)
  zwraca deviceLinkUri, a
  [FinishLinkCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/FinishLinkCommand.java)
  przyjmuje deviceLinkUri/deviceName i zwraca number.
  [ProvisioningManagerImpl](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/ProvisioningManagerImpl.java)
  dopuszcza ponowne połączenie wyrejestrowanego urządzenia podrzędnego;
  nie trzeba kasować jego danych ani rejestrować numeru od początku.
- [SendSyncRequestCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendSyncRequestCommand.java)
  prosi telefon o metadane synchronizacji. Dostępny katalog pochodzi z
  listContacts (włącznie z profile) i listGroups, a nie z importu wiadomości.
  [JsonSyncMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonSyncMessage.java)
  eksportuje type CONTACTS_SYNC/GROUPS_SYNC, używane do odświeżenia cache.
- [ReceiveHelper](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/ReceiveHelper.java)
  reaguje na AUTHENTICATION_FAILED, a
  [ManagerImpl](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/ManagerImpl.java)
  zamyka manager. Po jego usunięciu
  [MultiAccountManagerImpl](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/MultiAccountManagerImpl.java)
  nie zwraca numeru w listAccounts.
  [SignalJsonRpcDispatcherHandler](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/jsonrpc/SignalJsonRpcDispatcherHandler.java)
  nie eksportuje osobnego zdarzenia auth/websocket. Dlatego brak konta
  wykrywamy przy odświeżeniu/przed wysłaniem/restartem; błędu sieci ani -3
  nie interpretujemy jako potwierdzonego cofnięcia upoważnienia.

QR: sprawdzony lokalny ABI `/usr/include/qrencode.h`, libqrencode 4.1.1
(SONAME 4), QRcode_encodeString8bit/free, ECC M. Niezależny test dekoduje
moduły przez ZXing 3.1.1 (SONAME 4); ZXing jest zależnością tylko testową.
Brak libqrencode daje qr_unavailable przed startLink. Nie ma bitmap na dysku.

## Wydanie i środowisko — audyt S00

- [Oficjalne wydanie 0.14.8](https://github.com/AsamK/signal-cli/releases/tag/v0.14.8),
  opublikowane 2026-09-10. [Wymagania tego tagu](https://github.com/AsamK/signal-cli/blob/v0.14.8/README.md#installation):
  JRE co najmniej 25, natywna biblioteka libsignal dołączona dla obsługiwanych
  platform. Audyt obejmuje Linux x86_64, glibc 2.44.
- Lokalny JRE: **Eclipse Temurin 25.0.4.1+1-LTS**, HotSpot, archiwum
  [adoptium/temurin25-binaries](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4.1%2B1).
  Wyłącznie `artifacts/signal-s00/tool/`; bez instalacji systemowej/PATH.
- Quickshell 0.3.1, Qt 6.11.2, Python 3.14.7, SQLite 3.53.4 z modułu
  Python. Początkowo ani Java, ani signal-cli nie były dostępne w PATH.
  Pełne metadane i hashe: [provenance.json](../evidence/signal/S00/provenance.json).

| Archiwum | SHA-256 sprawdzone po pobraniu |
| --- | --- |
| `signal-cli-0.14.8.tar.gz` | `ccd408e831eff7e41ebaaf309704840bb00d78a7869f35ad700dbae5b5a5bb65` |
| `OpenJDK25U-jre_x64_linux_hotspot_25.0.4.1_1.tar.gz` | `1731a34baadec5479258ea0202e4d5d865d2efeee60cb0c7d7eb056fe96ca219` |
| `signal-cli-0.14.8-Linux-native.tar.gz` | `36569af20c709e0c5e6e677b74f50f147b21f3740620b8a7affde70f6027f82a` |
| `signal-cli-0.14.8-json-schemas.tar.gz` | `ac950a1a9c3e34b4eb7ca46a1a2ccd63dc183b78447ca7d654bac97af0b0096d` |

Sumy porównano z metadanymi publikującego przez HTTPS. Nie weryfikowano
osobno podpisów `.asc`; to nie jest deklaracja weryfikacji GPG.
Wersjonowanie jest punktem odniesienia audytu, nie zamrożeniem aktualizacji
bezpieczeństwa. Przed S12 ponownie ocenić zgodność z serwerem Signal;
zmiana wersji wymaga ponownego audytu i prób, nie automatycznego „latest”.

**Wynik natywnego wariantu:** wersja/help oraz 18 odpowiedzi RPC otrzymano,
ale zamknięcie stdin zakończyło proces kodem 99 z błędem GraalVM
`InterruptedException` w `PosixSignalHandlerSupport.stopDispatcherThread`.
Zachowano [wynik negatywny](../evidence/signal/S00/cli-native-probe.json).
Nie wnioskujemy, że wszystkie instalacje native mają ten błąd; ten artefakt
nie przeszedł lokalnego kryterium. **JVM: PASS**, ten sam zestaw i EOF
z kodem 0: [cli-jvm-probe.json](../evidence/signal/S00/cli-jvm-probe.json).

## Co rzeczywiście zweryfikowano

1. Rzeczywista binarka w bwrap: prywatne PID/mount/network, puste XDG,
   bez home, D-Bus i sieci. Version, 14 poleceń `--help` oraz 18 żądań RPC.
2. `listAccounts → []`, `subscribeReceive → 0`, nieznana metoda → -32601,
   polecenia wymagające konta → -32602, `finishLink` bez URI → -1.
   To potwierdza dispatcher i walidację konta, **nie** wysłanie, link ani
   walidację wszystkich parametrów operacji na koncie.
3. Odczyt źródeł oznaczonego tagu: polecenia, serializery, dispatcher,
   helpery odbioru i receipts. Hashe źródeł w provenance.
4. Syntetyczne przykłady i test framingu. Realne sent/read sync, media,
   grupy i działanie na urządzeniu połączonym pozostają testami S12.

## Źródła kontraktu

- [Podręcznik CLI](https://github.com/AsamK/signal-cli/blob/v0.14.8/man/signal-cli.1.adoc)
  i [JSON-RPC](https://github.com/AsamK/signal-cli/blob/v0.14.8/man/signal-cli-jsonrpc.5.adoc).
- [Polecenia](https://github.com/AsamK/signal-cli/tree/v0.14.8/src/main/java/org/asamk/signal/commands),
  [serializery JSON](https://github.com/AsamK/signal-cli/tree/v0.14.8/src/main/java/org/asamk/signal/json),
  [SignalJsonRpcDispatcherHandler](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/jsonrpc/SignalJsonRpcDispatcherHandler.java)
  i [JsonRpcNamespace](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/JsonRpcNamespace.java).
- [MessageEnvelope biblioteki](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/api/MessageEnvelope.java)
  rozróżnia pola dostępne wewnątrz biblioteki od wyeksportowanych w JSON.
  Zależność signal-service tego wydania to `2.15.3_unofficial_153`:
  [libs.versions.toml](https://github.com/AsamK/signal-cli/blob/v0.14.8/gradle/libs.versions.toml).

Podręcznik zawiera nieaktualne skróty przykładów: `finishLink` w kodzie
zwraca **`{"number":"…"}`**, nie `deviceLinkUri` jak w przykładzie man.
`send` ma także tablicę **`results`**; sam timestamp nie dowodzi sukcesu.
`listGroups.members` zawiera obiekty adresów/roli, nie same numery.
Kontrakt oparto na serializerach i wynikach executable, nie wyłącznie man.

## Framing i subskrypcja

Opis IPC S01 poniżej jest historyczny. S02 zastąpił storage_not_ready
trwałym odbiorem i dodał [API historii/outboxu](#ipc-i-dodatkowe-api-po-s02).

S01 implementuje transport w `services/signal_transport.py` i własność
procesu w `services/signal_process.py`. Pin pozostaje **0.14.8 JVM**;
nie dodano nowych pól API ani obejść luk S00. Test rzeczywistego JVM
potwierdza zachowanie PID i blokady przez exec oraz sprzątanie po TERM/KILL,
bez konta i sieci: [dowód](../evidence/signal/S01/jvm-process.json).

Własny IPC v1 w S01 eksportuje `service.status`, `service.retry` i
`request.cancel` (`params.id`, identyfikator próby IPC). Hello i
`service.changed` zawierają ipcVersion=1, schemaVersion=0, cliVersion,
accountState, serviceState, errorCode, retryCount i capabilities.
CLI version pozostaje pusty do potwierdzenia executable. Nie ma jeszcze
metod wiadomości/outboxu. Testowy argument dodaje `test.echo/mutate/receive`
tylko dla atrapy. [Pełne doprecyzowania](CONTRACTS.md#wykonane-doprecyzowania-s01).

W produkcji linked nie oznacza jeszcze ready: `storage_not_ready` zamyka
CLI bez subskrypcji. W S02 trzeba otworzyć magazyn i zapisać event przed
publikacją UI, zanim zostanie usunięta ta bramka. Obecny callback receive
jest wyłącznie efemeryczną ścieżką testową.

CLI: UTF-8 NDJSON na stdin/stdout. Każde żądanie posiada unikalne tekstowe
`id`; odbiór to notyfikacja `method:"receive"` bez `id`. Parametry są
camelCase, listy mogą mieć liczbę pojedynczą lub mnogą; przykłady poniżej
stosują jawne tablice tam, gdzie polecenie oczekuje listy. Wartości enumów
nie są automatycznie camelCase: np. permission `only-admins`.

Tryb `jsonRpc --receive-mode manual` uruchamia odbiór dopiero po subskrypcji.
W tym trybie koperta jest w `params.result.envelope`, konto w
`params.result.account`, numer subskrypcji w `params.subscription`.
Domyślny `on-start` ma inny wrapper (`params.envelope`); Putkin go nie
wybiera. Równoległa obsługa żądań w `JsonRpcReader` nie gwarantuje kolejności
odpowiedzi. Event może wyprzedzić odpowiedź `subscribeReceive`.

```json
{"jsonrpc":"2.0","id":"sub-1","method":"subscribeReceive","params":{"account":"+12025550100"}}
{"jsonrpc":"2.0","id":"sub-1","result":0}
{"jsonrpc":"2.0","id":"stop-1","method":"unsubscribeReceive","params":{"subscription":0}}
{"jsonrpc":"2.0","id":"stop-1","result":{}}
```

Numery w przykładach są syntetyczne. Produkt używa jednego własnego katalogu
i konta; techniczny tryb multi-account jest potrzebny do parowania.
Nie zakładać istnienia `ack`, `history`, `getMessages`, idempotency key ani
RPC anulowania — tych kontraktów nie ma w wybranym interfejsie.

## Mapa funkcji i późniejszych testów

„J” oznacza potwierdzoną obecność w JSON-RPC/kodzie; „L” to nadal wymagany
odbiór na połączonym koncie. Numery T odsyłają do [TESTING.md](TESTING.md).

| Funkcja | Metoda / zdarzenie 0.14.8 | Granice | Test |
| --- | --- | --- | --- |
| Parowanie | J `startLink`, `finishLink`, CLI `link`; `listAccounts` | `startLink` → `deviceLinkUri`, `finishLink` → `number`; URI tylko w pamięci. Bez `register`, bo to inny przepływ konta. L skan telefonu. | T03 |
| Odbiór | J `subscribeReceive`, `unsubscribeReceive`, `receive` | Jedna subskrypcja po gotowości bazy; brak ACK bridge i replay historii. | T01/T02 |
| Tekst / Notatka | J `send`, `recipient:[UUID]` albo `noteToSelf:true` | `results[].type`, nie samo `timestamp`. Test Notatki nie potwierdza zewnętrznych receipts. | T04/T06 |
| Nowa rozmowa / kontakt | J `getUserStatus`, `listContacts`, `updateContact`, `send` z recipient/username | ACI/alias rozstrzyga helper; znalezienie numeru zależy od ustawień/serwera. L kompletność kontaktów i zmian z telefonu. | T04/T10 |
| Synchronizacja metadanych | J `sendSyncRequest`; `syncMessage.type` CONTACTS_SYNC/GROUPS_SYNC | Nie pobiera starej historii. Lokalna lista CLI może być częściowa; L odświeżenie po zmianie telefonu. | T02/T10 |
| Telefonowe wysłane | J `syncMessage.sentMessage` | Dane są **spłaszczone**, nie pod `.dataMessage`; edit jest wyjątkiem opisanym niżej. Bez toasta. | T02 |
| Raport dostarczenia / odczytu | J `receiptMessage.{when,isDelivery,isRead,isViewed,timestamps}` | Osobno dla odbiorcy; brak read nie oznacza „nie przeczytano”. Ustawienia prywatności wpływają na raport. | T06 |
| Odczyt między własnymi urządzeniami | J `syncMessage.readMessages[]`, `sendReceipt` type=read | Biblioteka wysyła także read sync dla ACI; L oba kierunki, również wyłączone zewnętrzne receipts. | T06 |
| Media / pliki | J `send.attachment`, `dataMessage.attachments[]`, `getAttachment` | CLI pobiera przed emisją eventu; getAttachment zwraca base64 już pobranego pliku, nie zdalny lazy fetch. | T07 |
| Reakcja / cofnięcie | J `sendReaction`, `dataMessage.reaction` | UUID autora + target timestamp + emoji/isRemove; sent sync również może zawierać reakcję. | T08 |
| Edycja | J `send.editTimestamp`, `envelope.editMessage`, sent-sync edit | Nie `dataMessage.editMessage`. Zachować oryginalny ID oraz nowe wersje. L limity/autorstwo/duplikaty. | T08 |
| Cytat / wzmianki | J `send.quoteTimestamp/quoteAuthor/quoteMessage`, `mention`, dataMessage.quote/mentions | Offsety mention w jednostkach UTF-16, nie liczbie znaków Unicode. Kontrolowane cytaty podlegają retencji. | T08/T09 |
| Pisanie | J `sendTyping` (`stop:true`), `typingMessage` | Ulotny stan, bez historii, wygasający lokalnie; dostępny dla osoby/grupy. | T08 |
| Usuń u wszystkich | J `remoteDelete.targetTimestamp`, `dataMessage.remoteDelete.timestamp` | Metoda nazywa się **remoteDelete**, nie sendRemoteDelete. Sync wysłanego delete jak sentMessage. Nie gwarantuje usunięcia cudzych kopii. | T09 |
| Usuń u mnie | Operacja SQLite Putkina | Nie ma potwierdzonego JSON-RPC delete-for-me sync; lokalne usunięcie nie wysyła remoteDelete. | T09 |
| Znikanie | J `expiresInSeconds`, `isExpirationUpdate`; `updateContact.expiration`, `updateGroup.expiration` | **Luka eksportu:** sent sync pomija expirationStartTimestamp. Dokładna semantyka S09 wymaga uzupełnienia interfejsu. | T09, bramka wydania |
| View-once | J `viewOnce`, `send.viewOnce`, `sendReceipt` type=viewed | Biblioteka ma viewed/viewOnceOpen, serializer sync ich nie eksportuje. Typ niedostępny w UI, bez zwykłego podglądu. | T07/T09 |
| Grupy | J `listGroups`, `updateGroup`, `joinGroup`, `quitGroup`, `dataMessage.groupInfo` | groupId base64 jest kluczem; updateGroup bez ID tworzy grupę. Członkostwo/admin/permission/isTerminated są istotne. L drugie konto i brak uprawnień. | T10 |
| Akceptacja rozmowy / blokada | J `sendMessageRequestResponse`, `block`, `unblock` | Obsługę i widoczność stanów trzeba zweryfikować w S10; nie utożsamiać samego listContacts z akceptacją zaproszenia. | T10 |
| Otwórz / quick reply | Wewnętrzne API Putkina, wspólny outbox | Istniejące QML blokuje inline reply; nie jest to ograniczenie JSON-RPC Signala. | T05 |

Nie dopisano niezweryfikowanych limitów długości, rozmiaru plików, liczby
edycji i okna usunięcia jako stałych serwera. S07–S10 muszą oddzielić lokalne
limity zasobów od aktualnych zasad protokołu, odmowę pokazywać jako błąd.

## Przykłady żądań i wyników

Przykłady są syntetyczne, zgodne z poleceniami/serializerami tagu; nie były
wysłane do serwera. Parowanie: `startLink` bez parametrów, potem
`finishLink` z `deviceLinkUri` zwróconym w pamięci i `deviceName:"Putkin"`.
Nie zapisujemy nawet testowej treści QR do dowodów.

```json
{"jsonrpc":"2.0","id":"send-1","method":"send","params":{"account":"+12025550100","recipient":["bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"],"message":"Odpowiedź z Putkina"}}
{"jsonrpc":"2.0","id":"send-1","result":{"timestamp":1790000002000,"results":[{"recipientAddress":{"uuid":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","number":"+12025550101"},"type":"SUCCESS"}]}}
{"jsonrpc":"2.0","id":"edit-1","method":"send","params":{"account":"+12025550100","recipient":["bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"],"message":"Poprawiony tekst","editTimestamp":1790000002000}}
{"jsonrpc":"2.0","id":"react-1","method":"sendReaction","params":{"account":"+12025550100","recipient":["bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"],"emoji":"👍","targetAuthor":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","targetTimestamp":1790000000000,"remove":false}}
{"jsonrpc":"2.0","id":"delete-1","method":"remoteDelete","params":{"account":"+12025550100","recipient":["bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"],"targetTimestamp":1790000002000}}
{"jsonrpc":"2.0","id":"read-1","method":"sendReceipt","params":{"account":"+12025550100","recipient":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","targetTimestamp":[1790000000000],"type":"read"}}
{"jsonrpc":"2.0","id":"media-1","method":"send","params":{"account":"+12025550100","recipient":["bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"],"attachment":["/private/staged/synthetic.png"]}}
{"jsonrpc":"2.0","id":"groups-1","method":"listGroups","params":{"account":"+12025550100","detailed":true}}
{"jsonrpc":"2.0","id":"group-send-1","method":"send","params":{"account":"+12025550100","groupId":["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="],"message":"Tekst w grupie"}}
```

W odpowiedzi `results[].type` występują SUCCESS, NETWORK_FAILURE,
UNREGISTERED_FAILURE, IDENTITY_FAILURE, RATE_LIMIT_FAILURE,
INVALID_PRE_KEY_FAILURE. RATE_LIMIT_FAILURE może zawierać `retryAfterSeconds`
i token wyzwania (nie logować). Wynik grupy może być częściowy. Błędy RPC
to także `error.code`: -32600/-32601/-32602 oraz CLI -1 (użytkownik),
-3 (I/O), -4 (tożsamość), -5 (limit), -6 (captcha). Błąd po wykonaniu
części operacji nie dowodzi braku skutków. Nie włączać automatycznego
zaufania zmienionym kluczom tożsamości.

## IPC i dodatkowe API po S02

Pin CLI pozostaje 0.14.8 JVM. Sprawdzono ponownie źródła tego tagu:
[listAccounts](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/ListAccountsCommand.java)
zwraca tylko numer; ACI własnego konta ustalamy przez
[listContacts](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/ListContactsCommand.java)
z `account`, `recipient:[własnyNumer]`, `allRecipients:true`.
Odpowiedź musi zawierać jeden pasujący `number` i prawidłowy `uuid`.
Ta ścieżka może także odświeżać profile w bibliotece, więc nie zakładamy
braku ruchu sieciowego na prawdziwym koncie. Brak wyniku blokuje odbiór.

Przed send helper pyta o `messageExpirationTime` konkretnego kontaktu lub
grupy: `listContacts` z UUID / `listGroups` z `groupId:[base64]`.
Pola potwierdzono w [JsonContact](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonContact.java)
i [ListGroupsCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/ListGroupsCommand.java).
Do S07/S09 używamy `--ignore-attachments --ignore-avatars` z
[JsonRpcDispatcherCommand](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/JsonRpcDispatcherCommand.java).
Nie dodano własnego timestamp/idempotencyKey do
[send](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/commands/SendCommand.java),
bo ten interfejs ich nie przyjmuje. Wszystkie nowe przepływy sprawdzono
na atrapach; linked account/live pozostaje w S12.

IPC nadal ma v1. Snapshot dodaje `accountId`; schemaVersion jest 0 przed
otwarciem magazynu, następnie 1. Capabilities metod domenowych pojawiają
się tylko przy zdrowej bazie i znanym koncie. Generacja resetuje modele;
zmiany mają wspólny seq S01. Wszystkie metody dotyczą bieżącego konta;
opcjonalny accountId niezgodny ze snapshotem daje account_mismatch.

| Metoda | Parametry | Wynik |
| --- | --- | --- |
| `conversations.page` | `before:null/cursor`, `limit:1..100` (domyślnie 50) | `items,nextCursor` |
| `messages.page` | `conversationId`, `before`, `limit` | `items,nextCursor` |
| `message.get` | `messageId` | Jeden rekord, do odświeżenia po zmianie |
| `conversation.open` | `kind:direct,serviceId` / `kind:group,groupId` / `kind:note` | `conversationId`; tworzy tylko lokalną tożsamość, nie grupę na serwerze |
| `draft.get` | `conversationId` | `conversationId,text,revision` |
| `draft.set` | `conversationId,text,expectedRevision` | Nowy szkic/revision albo draft_conflict |
| `message.send` | `conversationId,text,operationId?`, opcjonalnie `draftRevision` | Przyjęcie queued z operationId/messageId, nie dowód wysłania |
| `operation.status` | `operationId` | `state,errorCode,safeRetry,attempt,recipients` oraz stabilne ID |
| `operation.cancel` | `operationId` | Anulowanie wyłącznie queued; sending/unknown nie są cofane |
| `operation.retry` | `operationId` | Kolejna jawna próba wyłącznie definite failed/safeRetry; nie unknown/partial |

Zalecany operationId to UUID utworzony przez wywołującego **przed** send
i zachowany do otrzymania wyniku. Powtórne przekazanie tego samego UUID
z tą samą treścią zwraca istniejący outbox; inna treść daje operation_conflict.
Gdy pominięty, helper tworzy UUID przed INSERT, ale klient tracący odpowiedź
enqueue musi odtworzyć stan z historii, zamiast ponowić send bez UUID.
Nie stanowi to obietnicy idempotencji serwera. `request.cancel` nadal
anuluje wyłącznie próbę IPC; do trwałej operacji służy operation.cancel.

Rekord wiadomości: `messageId,conversationId,authorServiceId,sentTimestampMs`
(null przed wynikiem CLI), `sortTimestampMs,direction,origin,kind,text,status,
conflict,expiresAtMs,attachments`. Statusy S02 to received i stany outboxu;
brak deklarowanego delivered/read. Referencje mediów zawierają tylko
`attachment_id,content_type,size_bytes`, bez ścieżki/base64/filename.
Rekord rozmowy: `conversationId,kind,target,title,activityTimestampMs,
expirationSeconds`. Tytuł grupy nie jest jej kluczem.

Element `operation.status.recipients`: `recipient,result_type,
retry_after_seconds`. To oczyszczone wyniki bieżącej próby; historia
prób pozostaje w bazie. Nie eksportujemy raw error/challenge tokenów.

Zdarzenia `conversation.changed`, `message.changed`, `draft.changed`,
`operation.changed` niosą ID konta/rozmowy/obiektu (szkic także revision),
wyłącznie po COMMIT. `message.removed` zawiera messageId i replacementId
przy połączeniu wczesnej kopii sent sync z lokalnym rekordem. Konsument
aktualizuje wpis po ID; nie pobiera całej bazy. Wysłane z telefonu nie
mają eventu powiadomienia/toasta; S05 musi filtrować direction/origin.

SignalService udostępnia `conversations`, `messages`, `message`,
`openConversation`, `draft`, `setDraft`, `sendText` (wymaga operationId),
`operation`, `cancelOperation`, `retryOperation`; zwracają request ID.
Sygnały `response(requestId,result,error)`, `changed(name,data)` i `reset()`
po zmianie generacji pozwalają podłączyć modele okna/quick reply.
S04 dodaje SignalMessagingAdapter oraz wspólne okno; opisany wyżej pełny
adres jest publicznym kontraktem otwierania z UI/IPC/powiadomienia.

## Schematy zdarzeń

Pełne, wykonywalne przykłady (15 eventów, 5 wymian):
[session.json](../../tests/fixtures/signal/v0.14.8/session.json).
Każdy zwykły event ma `jsonrpc`, `method:receive`, `params.subscription`,
`params.result.account`, `params.result.envelope`. Pola tekstowe/adresy
mogą być null lub nieobecne. Nie należy oczekiwać pustej tablicy tam,
gdzie serializer pomija pustą kolekcję.

| Rodzaj | Właściwa ścieżka wewnątrz envelope |
| --- | --- |
| Przychodzący tekst / media / grupa | `sourceUuid`, `timestamp`, `dataMessage.{timestamp,message,attachments,groupInfo}` |
| Sent sync | `syncMessage.sentMessage.{destinationUuid,timestamp,message,groupInfo}`; płaska treść, nie dodatkowe `.dataMessage` |
| Edycja | `editMessage.{targetSentTimestamp,dataMessage}` |
| Edycja z telefonu | `syncMessage.sentMessage.editMessage.{targetSentTimestamp,dataMessage}` |
| Reakcja | `dataMessage.reaction.{emoji,targetAuthorUuid,targetSentTimestamp,isRemove}` |
| Usunięcie | `dataMessage.remoteDelete.timestamp`; autora celu wyznacza nadawca operacji |
| Dostarczenie / read / viewed | `receiptMessage.{when,isDelivery,isRead,isViewed,timestamps}` |
| Odczyt na telefonie | `syncMessage.readMessages[].{senderUuid,timestamp}` |
| Grupa | `dataMessage.groupInfo.{groupId,groupName,revision,type}`; type DELIVER/UPDATE |
| Załącznik | `attachments[].{contentType,filename,id,size,width,height,caption,uploadTimestamp,isVoiceNote}` |
| Znikająca wiadomość | `dataMessage.expiresInSeconds` oraz `isExpirationUpdate` |

`JsonMessageEnvelope` dodaje `serverReceivedTimestamp` i
`serverDeliveredTimestamp`; żaden nie zastępuje `sentTimestampMs` w ID.
`params.result.exception` może towarzyszyć kopercie; to błąd odbioru,
nie tekst rozmowy. Nieznane pola/metody mają kontrolowany wynik, bez
wyrzucenia całego modelu lub logowania treści.

Archiwum JSON schemas wydania pobrano i sprawdzono jego hash. Generowane
schematy opisują nazwy i typy, ale część referencyjnych pól w kodzie bywa
null, podczas gdy schema wskazuje tylko string/object. Nie należy
uznać bezrefleksyjnego walidatora tych schematów za dowód zgodności runtime.
W fixtures wartości null odpowiadają serializerom Java.

## Receipts, media i wykryte luki

[ManagerImpl.sendReceiptMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/ManagerImpl.java)
sprawdza ustawienie read receipts przed wysłaniem do rozmówcy, a następnie
dla ACI wywołuje
[SyncHelper.sendSyncReceiptMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/SyncHelper.java).
Dlatego istnieje droga komputer → telefon read sync; telefon → komputer
eksportuje `readMessages`. Jest to wynik audytu kodu, nie próby na telefonie.

[IncomingMessageHandler](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/IncomingMessageHandler.java)
pobiera załączniki przed JSON. `--ignore-attachments` pomija zwykłe media,
ale nadal może pobierać długi tekst. `getAttachment` czyta plik już lokalny
i zwraca `data` w base64. JSON załącznika nie daje kompletnego zdalnego
pointera/klucza do pobierania na żądanie. S07 nie może obiecać takiej
funkcji tylko przez włączenie tej flagi.

[PathConfig](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/internal/PathConfig.java)
umieszcza attachments obok `data` we wskazanym data-dir.
[AttachmentStore](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/storage/AttachmentStore.java)
wyznacza lokalny identyfikator pliku. Bridge ma dodatkowo sprawdzać granice
ścieżek/symlinki oraz kontrolować wszystkie kopie tej integracji.
Limitu pobierania per medium i selektywnego pominięcia view-once nie
potwierdzono w JSON-RPC. Przed rzeczywistym odbiorem mediów S07/S09 musi
wykazać ograniczenie zasobów i brak zwykłego cache/podglądu view-once;
w razie potrzeby przez wąską, przypiętą poprawkę CLI. Globalne pomijanie
mediów nie spełnia wymagania obsługi załączników.

Ustalone braki wymagające jawnego traktowania:

- `MessageEnvelope.Sync.Sent` biblioteki ma `expirationStartTimestamp`,
  lecz [JsonSyncDataMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonSyncDataMessage.java)
  go nie eksportuje. Nie da się z samego JSON ustalić dokładnego startu
  timera wszystkich wysłanych wiadomości z telefonu. **Obowiązkowa bramka
  S09:** udostępnić metadane w sprawdzonym wydaniu/adapterze, odświeżyć pin
  i testy przed deklaracją zgodności retencji. Odbiór pełnego S09 i S12
  pozostaje niemożliwy przy niezmienionym, niepełnym interfejsie.
- Biblioteka ma sync `viewed`/`viewOnceOpen`, ale
  [JsonSyncMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/src/main/java/org/asamk/signal/json/JsonSyncMessage.java)
  ich nie eksportuje. Samo `sendReceipt(type:viewed)` nie zastępuje
  view-once-open. Zgodnie z zakresem S09: niedostępny typ, bez podglądu
  i bez deklaracji pełnej synchronizacji jednokrotnego obejrzenia.
- Brak eksportu potwierdzonego delete-for-me sync. „Usuń u mnie” zostaje
  lokalne; remoteDelete z telefonu nadal należy obsłużyć.
- Sent sync nie jest potwierdzonym mechanizmem odtworzenia każdej operacji
  po utracie odpowiedzi. Bez znanego timestampu pozostaje unknown.

## Odbiór, ACK i przerwy

[ReceiveHelper](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/helper/ReceiveHelper.java)
(okolice linii 135–165, 229–261) zapisuje kopertę w cache i wysyła ACK
serwera przed wywołaniem handlera. Po przetworzeniu usuwa cache, z wyjątkiem
wybranych błędów (np. niezaufanej tożsamości).
[MessageCache.cacheMessage](https://github.com/AsamK/signal-cli/blob/v0.14.8/lib/src/main/java/org/asamk/signal/manager/storage/messageCache/MessageCache.java)
ma ścieżkę błędu zapisu, która zwraca obiekt po ostrzeżeniu; sam cache nie
jest dowodem trwałego fsync przed ACK. Handler JSON wypisuje zdarzenie,
nie czeka na transakcję odbiorcy stdout.

Wniosek projektowy: nawet z SQLite istnieje okno utraty CLI → pipe → commit.
Nie ma API dowolnego replay ani transakcji obejmującej oba procesy.
Odłączenie subskrypcji, zatrzymanie procesu czy backpressure nie cofają
już wysłanego ACK. S02/S11 muszą wykazać lokalną trwałość i uczciwe unknown,
nie deklarować bezstratności po dowolnej awarii. Wyłączony shell nie
odbiera; nie obiecujemy bezterminowej kolejki serwera lub importu starej
historii telefonu po późniejszym podłączeniu.

## Powiadomienia Quickshell

Zainstalowane qmltypes oraz dokumentacja 0.3.1 udostępniają
[`Notification.sendInlineReply`](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/Notification/)
i [`NotificationServer.inlineReplySupported`](https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Notifications/NotificationServer/).
To dotyczy natywnych obiektów D-Bus. Własny Signal użyje rozszerzonego
`LocalNotification` i domenowego outboxu; QML nie musi udawać zewnętrznego
klienta powiadomień. Luka jest w filtrach/akcjach/fokusie Putkina, do S05.


Diagnostyka S12: opcjonalne `eventErrorLocation` w stanie bridge i `signal status`
zawiera tylko lokalizację walidacji w kodzie (`signal_events:<linia>` albo
`account_binding`). Nie zawiera surowego wyjątku, treści ani wartości upstream.
To ostatnia odrzucona ramka w życiu bridge, nie identyfikator wiadomości.
