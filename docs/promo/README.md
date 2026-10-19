# App promo videos

Three files, all made by `build.sh` from live recordings of the web build:

| File | For | Spec |
|---|---|---|
| `shia-companion-promo-whatsapp.mp4` | WhatsApp, Instagram, Shorts | 62.3 s, 1080×1920, ~12 MB (under WhatsApp's 16 MB, so it isn't recompressed) |
| `shia-companion-promo.mp4` (gitignored) | YouTube / Play Store promo video, master copy | 62.3 s, 1080×1920, CRF 17, ~38 MB |
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
| 0–6 s | Cold open. Bismillah, then "Allahumma inni as'aluka bi-raḥmatika…", written in gold Qalam **word by word in time with the reciter** (timings from a Whisper transcription of the recording), with the English fading in beneath and a waveform that follows the audio. |
| 6–16 s | Match cut into the phone, where the same verse sits on the Dua Kumayl page. **Live recordings** of the zikr page, not screenshots: "Read along, line by line" (scrolling), then "Choose your script" (Qalam→Scheherazade in the Text & reading sheet). Taps show as touch ripples, and captions animate in word by word. |
| 16–21 s | "Auto-scroll", then "Hear it recited": the recitation player starts, with a waveform driven by the soundtrack. |
| 21–24 s | "Easy on the eyes at night": the phone switches to dark mode and the page follows live. |
| 24–34 s | Home in dark mode, location set to Toronto: the prayer-times card (countdown to the next prayer, the next event), then a hard cut to the same Home on Thursday evening — "Today's recitations, one tap away / Dua Kumayl on Thursdays, Dua Nudba on Fridays — right on Home". |
| 34–39 s | "Pick up where you left off": the Continue card opens the Quran at the verse the Khatm reached (seeded demo history, `demo_data.js`), and a verse's sheet (save, note, share). |
| 39–43 s | "Keep several Khatms": the Quran tab holding three Khatms (My reading, Family Khatm, Ramazan; seeded). |
| 43–46 s | "Track · Read · Listen": a three-phone fan of My Stats, the book library and playlists. |
| 46–49 s | "At a glance": the app's real prayer widgets arranged around the Apple Watch. |
| 49–53 s | "And so much more": a three-phone fan of the Qaza tracker, Hijri calendar and Qibla, in the same layout as the Track fan. |
| 53–57 s | "In five languages": whole Home screens, two at a time, in Urdu and Gujarati, then Arabic and Persian (English is on screen all along). |
| 57–62.3 s | Outro: logo, `www.shiacompanion.app`, **100% FREE**. The recitation fades out. |

## Final cut (v22) — where everything lives

The shipped WhatsApp video above is the v22 cut. Its composition is
`promo.html` in this folder (the v14 revision of the composition; also kept
verbatim as `promo_v14.html`). Three scenes come from side pipelines:

- **Thursday Home** ("Today's recitations…"): `promo_thu.html`, rendered as
  `promo_thu2.html` (same file with the scene extended so the used window
  opens on the settled Home — that is what makes the Home→Thursday cut a
  clean hard cut). The take is recorded with `rec_home_pw2.js`, which pins
  the clock to Thursday 20:30 and selects Toronto in the city picker.
- **"At a glance" fan**: built by `make_fan3_v20anim.py` (layout:
  `make_fan3_v20.py`; widget cut-outs: `make_fan3_v14.py`) from the app's
  real widget screenshots in `shots/widget_*.jpg` around the Watch.
- **Home + recitation clips**: recorded with `rec_fix2.js`, which routes
  the R2 audio and font requests through a local mirror (the recording
  sandbox cannot reach them directly — without it the app shows its
  "recitation couldn't be loaded" toast) and runs the setup under the
  slow clock so the city-picker flow registers. Specs: `clips_home3.json`
  (Toronto flow; also folded into `clips.json` as the `home` clip) and
  `clips_listen2.json`.

`assemble_v22.sh` is the exact assembly: window renders of the composition
(`render_win.js`), the hard-cut join, and the crossfade graph. The recorded
frames themselves (`clips/`, ~150 MB) stay gitignored, as before; re-record
them with the scripts above.

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
