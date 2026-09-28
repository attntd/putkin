# Signal Desktop message icons

The SVGs and their QML path catalog are unmodified vector geometry from
Signal Desktop v8.27.0, © Signal Messenger, LLC, AGPL-3.0-only (LICENSE).

- `react.svg`: `images/icons/v3/heart/heart-plus.svg`
- `reply.svg`: `images/icons/v3/reply/reply.svg`
- `more.svg`: `images/icons/v3/more/more.svg`

Source: https://github.com/signalapp/Signal-Desktop/tree/v8.27.0/images/icons/v3
The toolbar mapping comes from `stylesheets/_modules.scss` at that tag.

`Emoji.js` contains Unicode sequences, names and skin variants from that
version's generated `build/emoji-data.json`. Signal's generator is AGPL-3.0-only;
its source data is Cal Henderson's emoji-data (MIT, see EMOJI-LICENSE),
at https://github.com/greyson-signal/emoji-data/tree/457ad4f7a09699ec940b149c8f4e76382bb0aadf.
No emoji artwork is bundled; Qt renders the installed font glyphs.
