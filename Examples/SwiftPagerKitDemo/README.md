# SwiftPagerKit Demo

iOS gallery and reels app for exercising `SwiftPagerKit` on device with bundled
photo and video media.

## Open

From this demo directory:

```sh
open SwiftPagerKitDemo.xcworkspace
```

Open the workspace, not the `.xcodeproj`, when editing the demo feature. The
feature code is a local Swift package, so SwiftPM picks up files from
`SwiftPagerKitDemoPackage/Sources/SwiftPagerKitDemoFeature` automatically rather
than listing them in `project.pbxproj`.

## What It Covers

- Bundled 9-photo portrait set derived from documented Mixkit clips.
- Bundled portrait Mixkit MP4 samples for full-screen vertical reels.
- Full-screen horizontal photo paging.
- Full-screen vertical video paging.
- Zoomable image pages with pull-to-dismiss and overscroll callbacks.
- Stable-ID paging with programmatic controls.
- Grid and pager load-more paths that append more local sample pages.
- Optional diagnostics for loaded pages, scroll phase, and visible fraction.

## CLI Validation

From the SwiftPagerKit package root:

```sh
SIMULATOR_ID=<simulator-udid> scripts/test/demo.sh
```

From this demo directory, the feature code lives in:

```sh
SwiftPagerKitDemoPackage/Sources/SwiftPagerKitDemoFeature/
```

The demo does not fetch media at runtime. Gallery JPEGs and reel MP4/poster
files are processed as Swift package resources so device runs and UI tests use
the same deterministic local assets. The bundled gallery JPEGs are still frames
from the documented Mixkit clips, and the reel MP4s are cropped/transcoded from
Mixkit stock videos for portrait playback.

See `THIRD_PARTY_MEDIA.md` for bundled media source and license notes.

Local device signing reads an ignored config value:

```xcconfig
// Config/Signing.local.xcconfig
DEMO_DEVELOPMENT_TEAM = ABCDE12345
```

Use `Config/Signing.local.example.xcconfig` as the template.
