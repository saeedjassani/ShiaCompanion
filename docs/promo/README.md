# App promo videos

Three files, all made by `build.sh` from live recordings of the web build
(`assemble.sh` cuts the first two, `store.html` is the third):

| File | For | Spec |
|---|---|---|
| `shia-companion-promo-whatsapp.mp4` | WhatsApp, Instagram, Shorts | 62.0 s, 1080×1920, ~12 MB (under WhatsApp's 16 MB, so it isn't recompressed) |
| `shia-companion-promo.mp4` (gitignored) | YouTube / Play Store promo video, master copy | 62.0 s, 1080×1920, CRF 17, ~35 MB |
| `app-store-preview.mp4` | App Store app preview (6.5"/6.9" iPhone slot) | 29.8 s, 886×1920, 30 fps, H.264 + stereo AAC |

The App Store cut (`store.html`) is only app footage with a caption band: no
device frame and no calligraphy intro, since Apple asks for previews made of
screen captures of the app. It runs Read along → script → auto-scroll → audio
→ dark mode → Home (prayer card, a glide down Home) → Continue into the Quran → several Khatms →
Qaza tracker and calendar (1.5 s each) → Home in Urdu and Gujarati, then Arabic
and Persian → logo.

**Soundtrack:** the opening of Dua Kumayl, the same recording the app's
player streams (`dua_kumayl_96k.mp3` on the app's R2 bucket). There is no
music.

| Time | What happens |
|---|---|
| 0–6 s | Cold open. Bismillah, written in gold Qalam **word by word in time with the reciter** (timings from a Whisper transcription of the recording), with the English fading in beneath and a waveform that follows the audio. |
| 6–17 s | The phone zooms out on the Dua Kumayl page. **Live recordings** of the zikr page, not screenshots: "Read along, line by line" (scrolling), then "Choose your script" (Qalam→Scheherazade in the Text & reading sheet). Taps show as touch ripples, and captions animate in word by word. |
| 17–22 s | "Auto-scroll", then "Hear it recited": the recitation player starts, with a waveform driven by the soundtrack. |
| 22–25 s | "Easy on the eyes at night": the phone switches to dark mode and the page follows live. |
| 24.5–38 s | One take of Home in dark mode, Thursday 6:08 pm in Toronto: "Prayer times" (up next: Sunset in 25 min, the next event), then Home glides down — "Everything on Home": Continue (the Quran and a library book), Today's Dua Kumayl and every feature — and the Continue card opens the Quran at the verse the Khatm reached (seeded demo history, `demo_data.js`), then a verse's sheet (save, note, share). |
| 38–42 s | "Keep several Khatms": the Quran tab holding three Khatms (My reading, Family Khatm, Ramazan; seeded). |
| 42–46 s | "Track · Read · Listen": a three-phone fan of My Stats, the book library and playlists. |
| 45.5–49 s | "At a glance": the app's real widgets around the Apple Watch (`make_glance.py`). |
| 48.5–52.5 s | "And so much more": a three-phone fan of the Qaza tracker, Hijri calendar and Qibla, in the same layout as the Track fan. |
| 52–56 s | "In five languages": whole Home screens, two at a time, in Urdu and Gujarati, then Arabic and Persian (English is on screen all along). |
| 56–62 s | Outro: logo, `www.shiacompanion.app`, **100% FREE**. The recitation fades out. |

## Files

- `promo.html`: the whole composition. `render(t)` draws any moment; the
  timeline (`shots`, `caps`, `cam` keyframes, word timings) is at the top of
  the script. A shot's `soft: {pre, frame, d}` skips the clip's in-between
  paint (the theme switch, a page's blank first frame) by fading frame `pre`
  out over frame `frame`.
- `assemble.sh`: cuts the promo from windows of `promo.html` (rendered by
  `render_win.js`) and the At a glance scene, with 0.3 s crossfades; the
  segment list, with each window's times, is at its top.
- `make_glance.py`: the At a glance scene, from the widget screenshots in
  `shots/widget_*.jpg` (each clipped to a clean rounded card with a soft
  shadow) and a drawn Watch face.
- `rec.js` + `clips.json`: records live interactions with the Flutter web
  build (taps, wheel scrolls, drags), each clip in a fresh browser context
  so app preferences start at their defaults. `"seed": ["quran"]` (or
  `"qaza"`, `"book"`) starts a clip with demo history from `demo_data.js`;
  `"geo"`, `"tz"` and `"clock"` put the phone somewhere at a set moment (the
  Home take is Toronto, `America/Toronto`, Thursday 6:08 pm, so its prayer
  times read in local time and Today offers Dua Kumayl); `"dark": true`
  puts the phone in dark mode, and a `{"scheme": "dark"}` action switches it
  mid-clip (the app follows the phone's theme live); `wheelX` swipes a
  carousel. Frames are read straight off
  Flutter's canvas at 897×1941 (DPR 2.3); browser screenshots come back at
  CSS pixels or stall the app's painting. Headless Chromium paints Flutter at
  only ~10 fps, so while a clip records the page's clock (`performance.now`,
  `Date.now`, rAF, timers) runs 6× slow (`SLOW`), which gives every animation
  6× the frames; the clip is written back at real speed. Under the slow clock
  Flutter takes only part of a wheel glide, so `wheel` distances are
  calibrated by eye (the Home take's 1300 moves the page about 250 px).
  Chromium goes through `HTTPS_PROXY` when it is set, so the recitation
  player can reach its audio.
- `store.html`: the App Store cut, same clips and stills.
- `interp.py`: resamples a clip to a constant 30 fps (frames are held, not
  motion-interpolated, because interpolation ghosts on UI text).
- `taps.js`, `env.js`: generated data (tap positions and frame counts,
  audio loudness envelope).
- `render_win.js`: renders one window of `promo.html` (t0 to t1).
- `render.js`: renders `promo.html` (or `store.html`) frame by frame with Playwright and
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
docs/promo/assemble.sh         # only the promo + WhatsApp copy
```

`clips/` (about 150 MB of frames) and the mp3 are gitignored. Set
`CHROMIUM_PATH` if Playwright's bundled browser isn't installed. Tap and
drag coordinates in `clips.json` are logical pixels on a 390×844 viewport
(the zikr page's action bar is at y 787: Bookmark 55, Listen 125, Text 195,
Tasbeeh 265, Share 335). If the zikr page layout changes, check them with
`node render.js "$PWD/promo.html" stills 26,30.5,39.5,43,47,50.5,53.8,57.9`.
