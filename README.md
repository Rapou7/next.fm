<div align="center">

<img src="App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="next.fm waveform icon" />

# next.fm

**Your music. A different perspective.**

A native iPhone client that turns your Last.fm listening history into a personal music dashboard.
Album artwork, interactive charts, and Liquid Glass — built with SwiftUI.

[![iOS build](https://github.com/Rapou7/next.fm/actions/workflows/ios-ipa-build.yml/badge.svg)](https://github.com/Rapou7/next.fm/actions/workflows/ios-ipa-build.yml)
![iOS 26+](https://img.shields.io/badge/iOS-26%2B-111111?logo=apple&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)

[Get a build](https://github.com/Rapou7/next.fm/actions/workflows/ios-ipa-build.yml) · [Roadmap](TODO.md) · [Report an issue](https://github.com/Rapou7/next.fm/issues)

</div>

---

## A closer look at your listening

next.fm combines the artwork-led feel of Apple Music with the glanceable statistics of Apple Fitness. Start with what is playing now, then explore the artists, albums, and tracks that make up your listening history.

**Rankings count scrobbles.** No guessed song lengths or estimated minutes affecting your tops.

> **Early development:** the first implementation includes core tests and an unsigned IPA workflow. Native UI and LiveContainer compatibility still need on-device verification. This is not a stable release.

## Four tabs, your whole soundtrack

| Tab | What you can explore |
| --- | --- |
| **Summary** | Currently playing at the top, or your last played track when nothing is playing. A 28-day activity chart, scrobble totals, artists, albums, listening streak, and the album you keep returning to. |
| **Tops** | Switch between **Tracks, Artists, and Albums**. Select **4 weeks, 6 months, or Lifetime**, with **Today, This week, the current year, and Custom dates** in the range menu. |
| **Library** | Search your imported music, browse artwork grids, and open detail pages with activity, first and latest plays, and favorite tracks. |
| **History** | Browse scrobbles grouped by day. Search by track, artist, or album, or narrow the list to a specific date. |

Native bottom tabs, Swift Charts, floating Liquid Glass controls, and artwork-backed listening cards keep the focus on your music. A clearly labeled **demo mode** lets you explore without an API key.

## Install an unsigned IPA

### Download

1. Open [GitHub Actions](https://github.com/Rapou7/next.fm/actions/workflows/ios-ipa-build.yml).
2. Select a successful **Build unsigned next.fm IPA** run.
3. Download the `next.fm-unsigned-<run number>` artifact at the bottom of the run page. You must be signed into GitHub with access to the repository.
4. Extract the ZIP to get `next.fm-unsigned.ipa`.

Builds run on pushes to `main` and can also be started with **Run workflow**. Artifacts are development builds, not App Store releases.

### Open in LiveContainer

1. Transfer the IPA to your iPhone's Files app.
2. In LiveContainer, tap **+** and select the IPA.
3. Launch next.fm and choose **Explore the demo** or connect your Last.fm profile.

The app requires **iOS 26 or later**. The initial device target is an **iPhone 15 using LiveContainer on iOS 27.0.1**; that combination is not yet verified. LiveContainer handles guest app signing/loading according to its configuration. See its [installation documentation](https://livecontainer.github.io/docs/installation) for setup.

## Connect Last.fm

You need a Last.fm username with accessible listening history and a [Last.fm API key](https://www.last.fm/api/account/create).

- Enter your username and API key on the connection screen. Your Last.fm password is never requested.
- Keep next.fm open during the first import. Large histories can take time.
- Pause and resume from the account screen. Completed pages are saved locally.
- Pull to refresh to import new scrobbles. Currently playing is checked periodically while the app is active.
- Imported history and statistics remain available offline. Artwork availability depends on cached network responses.

For your own builds, optionally configure a repository Actions secret named `LASTFM_API_KEY`. The workflow embeds it as a default key. **No Last.fm API secret is required.** An embedded API key can be extracted from the app; it is a client credential, not a protected server secret.

## Built for local history

Listening history lives in SQLite on your device. next.fm does not require its own backend or upload imported history to a next.fm server. Requests go to Last.fm and the artwork URLs it returns.

The sync engine uses a fixed import cutoff so new scrobbles do not shift the pages being downloaded. Each page and its resume checkpoint commit together. Refreshes overlap the latest sync window and deduplicate existing events. Temporary network failures use bounded retries.

Statistics run separately from the UI. Every Tops range is calculated from imported listening events. **Partial imports are labeled**, so unfinished lifetime rankings are not presented as complete.

### Dates and counts

- **4 weeks:** today plus the preceding 27 calendar days.
- **6 months:** from midnight six calendar months ago through now.
- **Custom dates:** both selected days are included in full.
- Day and week boundaries follow your device's calendar and timezone.
- A current streak can end yesterday if you have not listened today yet.
- A currently playing track is not counted until Last.fm records it as a scrobble.

### Current limitations

- Deleted, corrected, or late-added scrobbles outside the refresh window need a future reconciliation feature.
- Identical events sharing a timestamp, artist, album, and track are coalesced. Undated events are excluded.
- Artist thumbnails currently use artwork from an associated album. Missing artwork gets a generated placeholder.
- Very large profiles still need memory and performance testing; analysis currently loads stored events into memory.
- Initial import should run with the app open. Continuous background syncing is not implemented.
- This version reads listening history; it does not submit scrobbles or control playback.

## Develop locally

### Requirements

- macOS with **Xcode 26.2 or newer** selected
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Python 3 for the optional build configuration

```sh
git clone https://github.com/Rapou7/next.fm.git
cd next.fm
brew install xcodegen
python3 scripts/configure.py
swift test
xcodegen generate
open NextFM.xcodeproj
```

`project.yml` is the source of truth for the Xcode project. Generated projects, build output, and local API configuration are ignored by Git. No third-party Swift package dependencies are needed; the core uses the platform SQLite library.

For direct device installation outside LiveContainer, configure your development team and enable code signing in Xcode.

### Build an IPA from the command line

```sh
xcodebuild -project NextFM.xcodeproj -scheme NextFM \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build

bash scripts/package-ipa.sh
```

Output: `build/next.fm-unsigned.ipa`.

The [Actions workflow](.github/workflows/ios-ipa-build.yml) selects Xcode 26.2 on macOS 15, runs core tests, generates the project, builds for iPhone without signing, and uploads the IPA and build log. It does not automatically publish GitHub releases.

### Project layout

```text
App/                        SwiftUI screens, app state, and assets
Sources/NextFMCore/          Last.fm API, sync, SQLite storage, and statistics
Sources/CSQLite/             System SQLite module
Tests/NextFMCoreTests/       Statistics, API, persistence, and sync tests
scripts/                    Build configuration, icon generation, IPA packaging
docs/DEVICE-TEST.md          First-device verification checklist
project.yml                 XcodeGen project specification
.github/workflows/          Unsigned IPA build pipeline
```

### Tests and verification

Run `swift test` for the core package. The 13 tests cover date boundaries and daylight saving, ranking identity, missing albums, API response variants, currently playing exclusion, overlapping pages, profile isolation, and interrupted-import recovery.

The initial core suite passed using Swift 6.2 on Linux. The app model also passed Swift 6 type-checking; SwiftUI sources passed syntax parsing. Those checks do not validate Apple-only UI APIs or prove device compatibility. Use the build workflow and [device checklist](docs/DEVICE-TEST.md) for the remaining verification.

## What's next

- Device validation and refinement of the first native experience
- Last.fm Stats Web JSON import/export
- Calendar heatmaps, discovery statistics, milestones, and ranking history
- Better artwork caching and artist imagery
- Large-library performance improvements and history reconciliation
- Shareable recaps and widgets, subject to installation support

**Genre Tops** and **minute-based Tops** are deliberately deferred until their metadata and counting rules can be handled reliably. The full working list lives in [TODO.md](TODO.md).

## Inspiration and acknowledgments

[Last.fm Stats Web](https://github.com/felhag/lastfm-stats-web) inspired the depth of statistics and the approach of keeping listening history locally.

The initial implementation is original Swift code. If code from MIT-licensed Last.fm Stats Web is adapted later, its required license and attribution will be included.

Listening data is provided by [Last.fm](https://www.last.fm). next.fm is an independent project and is not affiliated with Last.fm or Apple. Artist names and album artwork belong to their respective owners.
