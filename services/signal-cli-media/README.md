# Putkin retention policy 2 — signal-cli 0.14.8 JVM

Pinned patches against [upstream v0.14.8](https://github.com/AsamK/signal-cli/tree/v0.14.8).
The upstream GPL-3.0 license applies. `recipe.json` verifies original sources
and both original jars. `runtime.json` verifies **both resulting jars** before
production JSON-RPC; stock CLI and policy 1 are refused.

- `IncomingMessageHandler`: view-once never enters attachment/long-text
  retrieval, in incoming and sent-sync paths. Ordinary and disappearing media
  use the same bounded downloader. Contact avatars, web-preview images and
  quote thumbnails remain omitted.
- `AttachmentHelper` / `AttachmentStore` / `PutkinMediaPolicy`: 32 MiB file,
  40 MiB encrypted transfer, 512 MiB CLI cache, disk reserve, private temporary
  files and MIME-derived local suffixes. No lazy remote fetch.
- `JsonSyncDataMessage`: exports the library's exact millisecond
  `expirationStartTimestamp`, including zero, without changing flattened data.
- `SendHelper`: fixes Note-to-Self's upstream use of a duration in the transcript
  start field; captures the actual expiration after the message builder is final.
- `PutkinRetention` / `SendMessageResultUtils`: a bounded map of timestamps and
  durations (no bodies) adds `expiresInSeconds` to the corresponding send result,
  then releases that metadata. This closes the read-preflight / send-setting race.
- `MessageSendLogStore`: with the existing `--disable-send-log` flag, purges
  legacy resend payloads with secure_delete and a truncating WAL checkpoint.
  Failure blocks opening the store. The flag prevents new resend payloads.
  **Tradeoff:** automatic resend after a recipient's decryption failure is
  unavailable. It is separate from Putkin's explicit outbox retry.

Build uses JDK 25.0.4.1+1 and the original distribution. It does not download,
activate or overwrite a distribution. Original source files belong in one
source directory, using the filenames in `recipe.json`.

```sh
python3 scripts/build-signal-media-cli \
  --source artifacts/signal-s09/source \
  --distribution artifacts/signal-s00/tool/signal-cli-0.14.8 \
  --jdk artifacts/signal-s07/jdk-25.0.4.1+1 \
  --output artifacts/signal-s09/cli-final
python3 scripts/test-signal-media-cli \
  --distribution artifacts/signal-s09/cli-final \
  --jdk artifacts/signal-s07/jdk-25.0.4.1+1
```

Offline tests execute the actual receive method, JSON serializer and SQLite
send-log implementation inside bubblewrap with no network/account. They do not
prove phone delivery. S12 must supply this build/JRE. Full retention contract,
limits of disk deletion and results: [S09](../../docs/evidence/signal/S09/README.md).
