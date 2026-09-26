# App promo video

`shia-companion-promo.mp4`: 58.5 s, 1080×1920 (9:16), 30 fps, H.264 + AAC.
Made for Reels, Shorts, TikTok and the store preview slots.

**Soundtrack:** the opening of Dua Kumayl, the same recording the app's
player streams (`dua_kumayl_96k.mp3` on the app's R2 bucket). There is no
music.

| Time | What happens |
|---|---|
| 0–16 s | Cold open. Bismillah, then "Allahumma inni as'aluka bi-raḥmatika…", written in gold Qalam **word by word in time with the reciter** (timings from a Whisper transcription of the recording), with the English fading in beneath and a waveform that follows the audio. |
| 16–18 s | Match cut: the calligraphy dissolves and the camera pulls back out of the phone, where the same verse sits on the Dua Kumayl page. |
| 18–48 s | **Live recordings** of the zikr page, not screenshots: scrolling, switching Qalam→Scheherazade in the settings drawer, dragging the Arabic size slider, turning on paragraph mode, focus mode, starting the audio player (with a waveform driven by the soundtrack), and tapping the counter from 1 to 9. The camera pushes in on each interaction, taps show as touch ripples, and captions animate in word by word. |
| 48–52 s | "And so much more": a fan of prayer times, Hijri calendar, Qibla and tasbeeh. |
| 52–58.5 s | Outro: logo, **100% FREE**, the official App Store / Google Play badges, `shia-companion.web.app`. The recitation fades out. |

## Files

- `promo.html`: the whole composition. `render(t)` draws any moment; the
  timeline (`shots`, `caps`, `cam` keyframes, word timings) is at the top of
  the script.
- `rec.js` + `clips.json`: records live interactions with the Flutter web
  build (taps, wheel scrolls, drags), each clip in a fresh browser context
  so app preferences start at their defaults. It saves timestamped
  full-resolution frames plus tap positions.
- `interp.py`: resamples a clip to a constant 30 fps (frames are held, not
  motion-interpolated, because interpolation ghosts on UI text).
- `taps.js`, `env.js`: generated data (tap positions and frame counts,
  audio loudness envelope).
- `render.js`: renders `promo.html` frame by frame with Playwright and
  pipes the frames to ffmpeg. `stills` mode renders single frames for
  previewing.
- `cap.js`, `shots/`: static screenshots used in the feature fan, and the
  store badges (`appstore.svg` from developer.apple.com, `gplay_c.png` from
  play.google.com with its padding trimmed).

## Rebuilding

```sh
docs/promo/build.sh            # flutter build web, record clips, render, add audio
docs/promo/build.sh --render   # clips/ already recorded: only re-render + audio
```

`clips/` (about 150 MB of frames) and the mp3 are gitignored. Set
`CHROMIUM_PATH` if Playwright's bundled browser isn't installed. Tap and
drag coordinates in `clips.json` are logical pixels on a 390×844 viewport.
If the zikr page layout changes, check them with
`node render.js "$PWD/promo.html" stills 26,30,46`.
