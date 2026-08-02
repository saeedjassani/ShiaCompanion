# CI and release pipeline

## Workflows

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `ci.yml` | push to `master`, every PR, manual | Analysis, tests, web build + visual checks, Android APK, Wear OS APK, iOS build |
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

The `ios` job pins `macos-15`, whose default is Xcode 16.4 — the same version
used locally and on Codemagic.

It cannot use `macos-latest`. That label now resolves to macOS 26, where the
build fails to link:

```
Error (Xcode): Undefined symbol: __swift_FORCE_LOAD_$_swiftCompatibility56
```

This is **not** a missing library. `libswiftCompatibility56.a` is present for
`iphoneos`, `iphonesimulator`, `watchos` and `watchsimulator` in every Xcode on
both runner images, 16.0 through 26.6 — verified directly on the runners. The
symbol is auto-linked by a prebuilt dependency and Xcode 26's linker is not
resolving it from the toolchain the way Xcode 16 did.

The `ios-xcode-26` job builds on `macos-latest` with `continue-on-error: true`
purely as early warning. **When it goes green, move the `ios` job to
`macos-latest` and delete it.** Until then, note that upgrading a local machine
or Codemagic to Xcode 26 is expected to hit the same failure — this is an
Xcode-version problem, not a CI-environment problem.

## Pinned versions

`FLUTTER_VERSION` is pinned in each workflow. `channel: stable` previously
tracked whatever Flutter released, which is a way for CI to break with no code
change. Bump it deliberately.
