# App promo videos

Three files, all made by `build.sh` from live recordings of the web build:

| File | For | Spec |
|---|---|---|
| `shia-companion-promo-whatsapp.mp4` | WhatsApp, Instagram, Shorts | 70.3 s, 1080×1920, ~15 MB (under WhatsApp's 16 MB, so it isn't recompressed) |
| `shia-companion-promo.mp4` (gitignored) | YouTube / Play Store promo video, master copy | 70.3 s, 1080×1920, CRF 18, ~33 MB |
| `app-store-preview.mp4` | App Store app preview (6.5"/6.9" iPhone slot) | 29.8 s, 886×1920, 30 fps, H.264 + stereo AAC |

The App Store cut (`store.html`) is only app footage with a caption band: no
device frame and no calligraphy intro, since Apple asks for previews made of
screen captures of the app. It runs Read along → script → auto-scroll → audio
→ dark mode → Home's prayer card → Continue into the Quran → several Khatms →
Qaza tracker and calendar (1.5 s each) → Home in Urdu and Gujarati, then Arabic
and Persian → logo.

**Soundtrack:** the opening of Dua Kumayl, the same recording the app's
player streams (`dua_kumayl_96k.mp3` on the app's R2 bucket). There is no
music.

| Time | What happens |
|---|---|
| 0–16 s | Cold open. Bismillah, then "Allahumma inni as'aluka bi-raḥmatika…", written in gold Qalam **word by word in time with the reciter** (timings from a Whisper transcription of the recording), with the English fading in beneath and a waveform that follows the audio. |
| 16–18 s | Match cut: the calligraphy dissolves and the camera pulls back out of the phone, where the same verse sits on the Dua Kumayl page. |
| 18–41 s | **Live recordings** of the zikr page, not screenshots: scrolling, switching Qalam→Scheherazade in the Text & reading sheet, starting auto-scroll, starting the audio player (with a waveform driven by the soundtrack), and the phone switching to dark mode, which the page follows live. The camera pushes in on each interaction, taps show as touch ripples, and captions animate in word by word. |
| 41–51 s | One take, in dark mode: Home's prayer card (countdown to the next prayer, the next event), then its Continue card opens the Quran at the verse the Khatm reached (seeded demo history, `demo_data.js`), in IndoPak, and a verse's sheet (save, note, share). |
| 51–55 s | The Quran tab holding three Khatms (My reading, Family Khatm, Ramazan; seeded): the row is swiped and Family Khatm opens at Al-Kahf 60, where it left off. |
| 55–60 s | "And so much more": a fan of the Qaza tracker, Hijri calendar and Qibla. |
| 60–64 s | "In five languages": whole Home screens, two at a time, in Urdu and Gujarati, then Arabic and Persian (English is on screen all along). |
| 64–70.3 s | Outro: logo, **100% FREE**, the official App Store / Google Play badges, `shiacompanion.app`. The recitation fades out. |

## Files

- `promo.html`: the whole composition. `render(t)` draws any moment; the
  timeline (`shots`, `caps`, `cam` keyframes, word timings) is at the top of
  the script.
- `rec.js` + `clips.json`: records live interactions with the Flutter web
  build (taps, wheel scrolls, drags), each clip in a fresh browser context
  so app preferences start at their defaults. `"seed": ["quran"]` (or
  `"qaza"`) starts a clip with demo history from `demo_data.js`, `"dark": true`
  puts the phone in dark mode, and a `{"scheme": "dark"}` action switches it
  mid-clip (the app follows the phone's theme live); `wheelX` swipes a
  carousel. Frames are read straight off
  Flutter's canvas at 897×1941 (DPR 2.3); browser screenshots come back at
  CSS pixels or stall the app's painting. Headless Chromium paints Flutter at
  only ~10 fps, so while a clip records the page's clock (`performance.now`,
  `Date.now`, rAF, timers) runs 6× slow (`SLOW`), which gives every animation
  6× the frames; the clip is written back at real speed.
- `store.html`: the App Store cut, same clips and stills.
- `interp.py`: resamples a clip to a constant 30 fps (frames are held, not
  motion-interpolated, because interpolation ghosts on UI text).
- `taps.js`, `env.js`: generated data (tap positions and frame counts,
  audio loudness envelope).
- `render.js`: renders `promo.html` frame by frame with Playwright and
  pipes the frames to ffmpeg. `stills` mode renders single frames for
  previewing.
- `cap.js`, `shots.json`, `shots/`: static screenshots for the feature fan
  and the languages scene (London location), recaptured with
  `node cap.js "$PWD/shots" "$(cat shots.json)"`, and the
  store badges (`appstore.svg` from developer.apple.com, `gplay_c.png` from
  play.google.com with its padding trimmed).

## Rebuilding

```sh
docs/promo/build.sh            # flutter build web, record clips, render all three
docs/promo/build.sh --render   # clips/ already recorded: only re-render + audio
```

`clips/` (about 150 MB of frames) and the mp3 are gitignored. Set
`CHROMIUM_PATH` if Playwright's bundled browser isn't installed. Tap and
drag coordinates in `clips.json` are logical pixels on a 390×844 viewport
(the zikr page's action bar is at y 787: Bookmark 55, Listen 125, Text 195,
Tasbeeh 265, Share 335). If the zikr page layout changes, check them with
`node render.js "$PWD/promo.html" stills 26,30.5,39.5,44,47.5,49.8,51.8,57,61,63`.
