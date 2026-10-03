# Agreed mockups

Source of every screen agreed for the revamp, exported from the design
canvas (https://claude.ai/artifact/AjdZLyGAdFC5faTXco6Um5, private to the
owner). Read them alongside [`../../DESIGN_SPEC.md`](../../DESIGN_SPEC.md);
where the two disagree, the spec wins.

Each `.dc.html` file is one screen: plain HTML with inline styles, so the
exact sizes, colours, spacing and copy can be read straight from the
markup. A small `<script>` at the bottom of some files holds list data or,
for the interactive ones (Tasbeeh-A, Rakaat-A, Setup-3-font), the
behaviour. They only render inside the canvas: `support.js` and the
`/_blob/...` images and fonts live there, not in this repo.

## Files

| File | Screen | Spec section |
|---|---|---|
| `R2-Home.dc.html`, `R2-Home-scrolled.dc.html`, `R2-Home-dark.dc.html` | Home (top, scrolled, dark) | Home |
| `R2-Shortcuts-edit.dc.html` | Edit shortcuts sheet | Home → Shortcuts |
| `R2-All-features.dc.html` | All features grid | All features |
| `R2-Quran.dc.html` | Quran tab | Quran |
| `R2-Favorites.dc.html` | Favorites tab | Favorites |
| `R2-Reader.dc.html`, `R2-Reader-dark.dc.html` | Reading a dua | Reading |
| `R2-Reader-paragraph.dc.html` | Multi-part zikr, Arabic as paragraph | Reading |
| `R2-Reader-text.dc.html` | Text & reading sheet | Reading |
| `R2-Quran-reader.dc.html` | Quran reading with the verse sheet | Reading |
| `T-Home.dc.html`, `T-Reader.dc.html` | iPad portrait (820 × 1180) | Responsive |
| `W-Home.dc.html`, `W-Reader.dc.html` | Web (1440 × 900) | Responsive |
| `Setup-0-welcome.dc.html` … `Setup-5-signin.dc.html` | First-run setup | First-run setup |
| `Loc-A-card.dc.html` | Home prayer card with no location | Home → Prayer card |
| `Loc-A-picker.dc.html` | City picker | Tools → City picker |
| `Verse-A-search.dc.html` | Search with a Go-to-verse result | Navigation → Search |
| `Verse-B-surah.dc.html`, `Verse-B-verse.dc.html` | Go to a verse, steps 1 and 2 | Quran |
| `Tasbeeh-A.dc.html` | Tasbeeh (guided Tasbih al-Zahra) | Tools |
| `Rakaat-A.dc.html`, `Rakaat-B.dc.html` | Rakaat counter and dim mode | Tools |
| `Settings-A.dc.html`, `Settings-A-signedin.dc.html` | Settings signed out / in | Settings |
| `Nudge-C.dc.html` | Back-up banner (shown on Favorites) | Back-up nudges |

The round-1 files (everything not prefixed `R2-`, `T-` or `W-`) were drawn
before the home and navigation were settled. Use them for their own screen
only: `Loc-A-card` and `Verse-A-search` still show the old bottom search
field, a "Today" heading and the old grid around the part that matters, and
`Nudge-C` shows Favorites as a plain page rather than the tab. The `R2-`
files and the spec are authoritative for everything around them.

## Images referenced as `/_blob/<id>`

All are renders of the app's own painters or bundled assets.

| What | Light | Dark |
|---|---|---|
| `HomeGlyph.surahs` (Quran) | `e9653bf1936c05a427e7ff402326c1d2` | `5d474757a75204cb284794ad69441561` |
| `HomeGlyph.duas` | `f93c92fb4f6ecc14fb7e473a9b7f4505` | `c2ad967a05e926206b4d596f70151c24` |
| `HomeGlyph.ziyaraat` | `d71cd6cd36f1a09da6459d94da518e31` | `96bf1549fac6b0e9d0bdc571fae038bb` |
| `HomeGlyph.munajaat` | `f77f493bef30782c6cc3959f7aa68021` | `e4dfcfa4726111d9f9da29d8d12a1feb` |
| `HomeGlyph.namaz` | `83e76e426e8526036b4273cc9dbf4f7d` | `e86de39212165387d1de693c9363f3f7` |
| `HomeGlyph.taqeebat` | `6b15230696b9d552d7f29e988a8a058f` | `902342b402a57509f0a2684eea14da9a` |
| `HomeGlyph.aamaal` | `5c10bd7f8b368b4ff7597fbecbef8aee` | `a80e2997ef7368fa0419240c4cd794b3` |
| `HomeGlyph.baqeyaat` | `38f8079cfd0fb21be769716a443b2a53` | `140ad2d3a991366cecb3394f974da442` |
| `HomeGlyph.library` | `26a9147caa0cf8b982d1216f92cc5f99` | `0e5a8f27d23f932f80ab2e23248a5dad` |
| `HomeGlyph.todaysRecitations` | `26459c1fa0b50ce9ba59d3506bb93ec6` | `a0adecde53c30b8c956b70b073c36444` |
| `HomeGlyph.tasbeeh` | `4e12a2c7dc6d2f873644bb29e6cdad10` | `98814a11824f215b7355e85bd01fa6aa` |
| `HomeGlyph.rakaat` | `9fe87353f2f0afb3cd9d405b1e297d3d` | `d6377853a6408f7021ca30830d9ac77f` |

| What | White (on the prayer card) | Light | Dark |
|---|---|---|---|
| `PrayerGlyph` Fajr | `f7e33b8d3068f8be2be64ed37ea8b04a` | `4e9f62a8bba482c3755ea0d072367842` | `9e5729e87fa783615be92bf5aba1d6a3` |
| `PrayerGlyph` Zuhr | `510fca5e0fd2fab700ca71d8de1a8c64` | `f655cef2a1d7abed249e8e611a8174a8` | `7280a4e2a907cf45a81ddb5f24ef34dd` |
| `PrayerGlyph` Asr | `734b4b79afce34d8d72655910ba18df8` | `c9c57d3c833a3b76fe33488b82707e12` | `e38c677750ed6ddebddd9c63963c85f6` |
| `PrayerGlyph` Maghrib | `6b4cfce23edf2c99dd5e34be11e98522` | `0fbd90378c22cf385124a471cbdad48c` | `dab69aba3b5d50985facbf21335eff6f` |
| `PrayerGlyph` Isha | `71155b241202896075fb6fccc694781e` | `83a69e478fe618af28b2d75809ea2106` | `261437c926421abeefffa52984bcd277` |

Other: `assets/logo.png` = `26d0dfdceda2ab04f17c43ee503c5dca`;
`assets/images/google_logo.png` = `efae57714c0f2a0ef9c9bc70bc1d2ea0`;
`assets/images/apple_logo.png` = `da0f22bd582d26d51a543b92bcfcb634`;
fonts `assets/fonts/qalam` = `d5d1bb57f046a6be658e48261d0cd523`,
`assets/fonts/scheherazade.ttf` = `26f10f12c5eab2d8bdffcca1b82048c4`,
`assets/fonts/quranwbw-indopak.ttf` = `5c78e8588c1d4d4510456f20fc4e3dc7`.
