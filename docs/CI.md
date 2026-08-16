# CI and release pipeline

## Workflows

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | push to `master`, every PR, manual | Analysis, tests, web build + visual checks, Android APK, iOS build |
| `web-preview.yml` | push to `master`, every PR, manual | Deploys a Firebase preview channel. Never touches production. |
| `web-release.yml` | push of a `v*` tag, manual | The only workflow that writes to the live site |

`ci.yml` runs analysis and tests first, on Ubuntu, and only starts the slow
platform builds once they pass. A failing test is reported in about three
minutes instead of after a twenty minute build that was going to fail anyway.

## Releasing the web app

Production is no longer deployed by merging to `master`. Merging deploys to the
`staging` preview channel; production is cut from a tag:

```bash
node scripts/bump_version.js     # 3.3.1+94 -> 3.3.2+95
git add pubspec.yaml && git commit -m "Bump version to 3.3.2"
git push
git tag v3.3.2 && git push origin v3.3.2
```

`web-release.yml` then verifies the tag matches `pubspec.yaml`, re-runs
analysis and tests, builds, runs the visual suite against the built bundle, and
only then deploys to `live`.

**Rolling back** is dispatching `web-release.yml` manually against an older tag.

**Nothing reaches production until a tag is pushed.** Merging to `master` moves
`staging` and nothing else, so `https://shia-companion.web.app` can sit many
merges behind `master` without anything looking wrong. This matters most for
SEO: the pre-rendered `/zikr/<slug>` pages and the generated `sitemap.xml` only
exist in a deployed bundle, so until a release tag ships them, Search Console
keeps crawling the previous sitemap. Check the `live` row of
`firebase hosting:channel:list` against the tag you expect before concluding
anything about what Google can see.

## SEO surface

Three things have to line up, and all three ship in the same bundle:

| File | Where it comes from |
| --- | --- |
| `sitemap.xml` | generated into `build/web` by `scripts/generate_zikr_seo_pages.js`; `web/sitemap.xml` is only the fallback |
| `/zikr/<slug>/index.html` | same script, one pre-rendered page per zikr |
| `robots.txt` | checked in at `web/robots.txt`, points at `SITE_ORIGIN/sitemap.xml` |

`test_visual/specs/seo.spec.js` asserts all of it against the built bundle.
The failure it exists to catch is quiet: if `sitemap.xml` is missing from
`build/web`, the `**` rewrite in `firebase.json` answers with the app shell
while the `headers` rule still labels it `application/xml`. That is a 200 no
crawler can parse, and Search Console reports it as **"Couldn't fetch"** — which
reads like a network problem and is not one.

Every `<loc>` must resolve to a real file in the bundle. A path that exists only
through the rewrite returns the same app shell as every other such path, so
Google folds it into the home page instead of indexing it.

It must also be the **final** URL, not one that redirects. The generated pages
are written as `<slug>/index.html`, and Hosting's default is to serve those at
`/<slug>/` while 301ing `/<slug>` to it — the opposite of the slash-less form
the generator emits as `<loc>`, `rel=canonical`, `og:url` and the JSON-LD `url`.
That left Google following a 301 to a page naming the redirecting URL as its
canonical. `"trailingSlash": false` in `firebase.json` inverts it so the
slash-less form is what serves.

If you ever change `trailingSlash`, change the canonical form in
`generate_zikr_seo_pages.js` with it — they have to agree, and `serve.js`
mirrors the setting so the suite will tell you when they don't.

## Where to test changes before releasing

| Channel | URL | Updated by | Lifetime |
| --- | --- | --- | --- |
| `live` | https://shia-companion.web.app | a `v*` tag | permanent |
| `staging` | https://shia-companion--staging-3dxo2xwu.web.app | every merge to `master` | 30 days, reset on each deploy |
| per-PR | posted as a comment on the pull request | every push to the PR | 7 days |

`staging` is the one to check before cutting a release: it always holds what is
currently on `master`.

Every deploy also prints its URL to the **run summary**, at the top of the
workflow run page in the Actions tab. That is the quickest place to look and it
is always correct, which a bookmark is not — see the caveat below.

To list the channels directly:

```bash
firebase hosting:channel:list --site shia-companion --project shia-comapnion
```

`--site` is **not optional**. The project id is misspelled (`shia-comapnion`)
but the site is not (`shia-companion`), and without `--site` the CLI queries a
near-empty site of the same name as the project and reports a stale `live` row
and no preview channels at all. Same distinction in the console:
https://console.firebase.google.com/project/shia-comapnion/hosting/sites/shia-companion

**The staging URL is stable, but not permanent.** The hash belongs to the
channel rather than to any single deploy, so redeploying does not change it.
Preview channels are capped at a 30-day expiry by Firebase, and this one's
clock resets on every merge to `master`. If `master` goes untouched for longer
than that, Firebase deletes the channel and the next merge recreates it —
expect a new hash then, and prefer the run summary over a bookmark.

## Testing layers

Three layers, each catching what the others cannot.

### 1. Unit and widget tests — `test/`

Logic and behaviour. Runs in seconds.

### 2. Page render tests — `test/ui/page_render_test.dart`

Renders each screen at phone, tablet and desktop viewports in both light and
dark themes, and fails on any framework error raised while laying it out.
`RenderFlex` overflows, bad constraints and nulls during build all surface
here. No golden files to maintain.

To cover another screen, add it to `_screens` in that file.

**Known gap.** Screens that reach Firebase while building cannot be listed
yet. `FavoritesManager` and `QazaTrackerManager` hold Firestore and Auth
instances as fields, and `ItemList` builds a Firestore collection reference in
a field initializer, so constructing any of them without a Firebase app throws
`[core/no-app]`. That covers Favorites, Library, Qaza tracker and the eight
zikr list screens. Closing it means standing up Firebase test doubles in the
suite — `TestFirebaseCoreHostApi` from `firebase_core_platform_interface`,
plus fakes for Firestore and Auth — or making those singletons lazy. Worth
doing; it is the single biggest coverage win available.

Screens are wrapped in a `Scaffold` when they are page bodies rather than whole
pages (`ownsScaffold: false`). Without it they render with no `Material`
ancestor and unbounded width, which fails for reasons that have nothing to do
with the screen.

### 3. Web visual and smoke tests — `test_visual/`

Playwright, against the real built bundle, served through `serve.js`, which
mirrors the rewrite rules and content-type headers in `firebase.json`. This is
the layer that catches web-specific breakage the Dart tests cannot see: a bad
wasm build, a missing asset, a broken rewrite, a page that never paints.

The app renders into a canvas, so there is nothing meaningful in the DOM to
assert against. `web/index.html` removes `#app-loading` on the
`flutter-first-frame` event, so that element disappearing is a direct signal
that the engine booted and produced a frame — which is exactly the blank-white-
page failure mode, inverted.

Each test also fails on uncaught exceptions, console errors and any same-origin
asset returning 4xx/5xx. Third-party and network noise is filtered by an
explicit allowlist in `specs/helpers.js`.

Running it locally:

```bash
flutter build web --wasm
node scripts/generate_zikr_seo_pages.js   # WEB_BUILD_DIR=build/web
cd test_visual && npm install && npx playwright install chromium
npm test
```

#### Screenshot baselines

Baselines live in `test_visual/specs/__screenshots__/<viewport>/`. When a
baseline is missing the test seeds it and passes — a first run has nothing to
regress against. Seeded baselines come back as the `playwright-*` CI artifact.
Download them, commit them, and every later run compares against them.

Regenerate deliberately after an intended UI change:

```bash
cd test_visual && npm run test:update
```

## iOS builds and Xcode

### Why Runner links libswiftCompatibility56.a explicitly

Under Xcode 26 the app failed to link:

```
Error (Xcode): Undefined symbol: __swift_FORCE_LOAD_$_swiftCompatibility56
```

Two separate things were going on.

**1. Why the symbol is needed at all.** `FirebaseAnalytics` ships as a
precompiled binary whose device slice leaves that symbol undefined and expects
the linker to supply it — `nm -u` on
`FirebaseAnalytics.xcframework/ios-arm64/…/FirebaseAnalytics` shows it, and
`FirebaseAuth` does the same. Apple still provides it: `nm` on
`libswiftCompatibility56.a` in Xcode 26.6 reports it as a defined symbol for
arm64 and arm64e. Xcode 26 simply stopped putting that library on the link
line, so Runner names it explicitly.

Upgrading Firebase is not an alternative. 12.17.0, three releases newer than
the pinned 12.14.0, still leaves the symbol undefined — checked by downloading
the release and inspecting the binary.

**2. Why `$(TOOLCHAIN_DIR)` cannot be used to find it.** On the macOS 26
runners the Metal toolchain is mounted as a MobileAsset cryptex, and
`TOOLCHAIN_DIR` resolves to *that* during the link phase:

```
/var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain-…/
Metal.xctoolchain/usr/lib/swift/iphoneos/libswiftCompatibility56.a
```

which does not exist. Note that `xcodebuild -showBuildSettings` reports
`TOOLCHAIN_DIR` as the XcodeDefault toolchain — the value differs between that
query and the actual build, so the setting cannot be trusted from a query
alone. A machine without the Metal cryptex mounted resolves it correctly, which
is why this reproduced only in CI.

**`DT_TOOLCHAIN_DIR` always names the Xcode default toolchain**, so that is what
the build settings use.

The archive is passed by absolute path rather than `-lswiftCompatibility56`. A
minimal reproduction on the runner confirmed the linker resolves it equally well
either way; the absolute path is preferred because a wrong directory then fails
with the offending path in the message, rather than an unhelpful
`library 'swiftCompatibility56' not found`.

Both settings are applied to all three build configurations of the Runner
target in `Runner.xcodeproj`, and verified by the `ios-xcode-26` CI job.

### Runner labels

The `ios` job pins `macos-15` (Xcode 16.4), matching Codemagic. The
`ios-xcode-26` job builds the same code on `macos-latest` (Xcode 26.x) with
`continue-on-error: true`, so a regression under the newer toolchain is visible
without blocking a merge. Once it has been green for a while, fold the two
together and build only on `macos-latest`.

## Pinned versions

`FLUTTER_VERSION` is pinned in each workflow. `channel: stable` previously
tracked whatever Flutter released, which is a way for CI to break with no code
change. Bump it deliberately.
