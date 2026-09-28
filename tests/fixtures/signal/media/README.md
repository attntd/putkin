# Syntetyczne media

`audio-long.wav` zawiera osiem sekund ciszy PCM, mono, 8000 Hz, 16 bitów.
Służy do sprawdzania play/pause i przewijania bez wyjścia audio:

```python
import wave
with wave.open("audio-long.wav", "wb") as output:
    output.setnchannels(1)
    output.setsampwidth(2)
    output.setframerate(8000)
    output.writeframes(bytes(8000 * 8 * 2))
```

Istniejące `image.png` (96 × 64), `video.mp4`, `audio.wav` i `document.txt`
są atrapami używanymi przez testy mediów Signala, bez treści użytkownika.
