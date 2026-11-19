<div align="center">

<img src="App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="next.fm waveform icon" />

# next.fm

**Your music. A different perspective.**

A native iPhone dashboard for your Last.fm listening history, with album artwork, interactive charts, and Liquid Glass.

[![Total downloads](https://img.shields.io/github/downloads/Rapou7/next.fm/total?include_prereleases)](https://github.com/Rapou7/next.fm/releases)
[![GitHub release](https://img.shields.io/github/v/release/Rapou7/next.fm?include_prereleases)](https://github.com/Rapou7/next.fm/releases)
[![License](https://img.shields.io/github/license/Rapou7/next.fm)](LICENSE)
![iOS 26+](https://img.shields.io/badge/iOS-26%2B-111111?logo=apple&logoColor=white)

[Download](https://github.com/Rapou7/next.fm/releases) · [Roadmap](TODO.md) · [Report an issue](https://github.com/Rapou7/next.fm/issues)

</div>

## Your listening, at a glance

- **Summary:** now playing, activity charts, streaks, a listening clock, scrobble calendar, and monthly favorites.
- **Tops:** swipe between tracks, artists, and albums, with presets and custom date ranges.
- **Search:** search your music and explore artwork, play counts, and listening details.
- **History:** revisit scrobbles by day or filter by track, artist, album, or date.

Account settings can sort rankings by scrobbles or estimated listening time. Time rankings use matched track durations and place unmatched entries last. History stays on your device. Enable estimated listening time in Summary to look up track, artist and album names over HTTPS. Durations are cached on-device. Summary, Tops, profiles, and history show estimates for the corresponding date range or scrobbles. Account settings show how many stored scrobbles contributed to time estimates. Try **Explore the demo** without credentials.

## Install

1. Download the unsigned IPA from [Releases](https://github.com/Rapou7/next.fm/releases).
2. Transfer it to your iPhone and import it with **+** in LiveContainer.
3. Launch next.fm, then explore the demo or enter your Last.fm username and [API key](https://www.last.fm/api/account/create). No password or API secret is needed.

Requires **iOS 26+** and a configured [LiveContainer installation](https://livecontainer.github.io/docs/installation), or a separate signing/install process. These are unsigned builds, not App Store releases. Device and LiveContainer behavior still need [verification](docs/DEVICE-TEST.md).

Keep the app open during the first import; you can pause and resume from the account screen. Pull to refresh afterward. Imported history and statistics remain available offline.

Test builds are also available as ZIP artifacts from successful [Actions runs](https://github.com/Rapou7/next.fm/actions/workflows/ios-ipa-build.yml). Extract the ZIP to get the IPA; downloading artifacts requires a GitHub login.

## Development

Use macOS with **Xcode 26.2+**, XcodeGen, and Python 3.

```sh
git clone https://github.com/Rapou7/next.fm.git
cd next.fm
brew install xcodegen
python3 scripts/configure.py
swift test
xcodegen generate
open NextFM.xcodeproj
```

Built with Swift 6, SwiftUI, Swift Charts, and SQLite, with no third-party Swift packages. `App/` contains the UI; `Sources/NextFMCore/` contains the API, sync, storage, and statistics. Edit `project.yml` rather than the generated Xcode project.

The [IPA workflow](.github/workflows/ios-ipa-build.yml) runs manually: leave `publish_release` off for test artifacts, or enable it for a versioned release. Pushes do not trigger builds. See [AGENTS.md](AGENTS.md) for build and packaging details.

## Debug and showcase

Version 0.2.3 adds a Debug-only diagnostics panel, rendering-feedback screenshots, and an animated automatic feature tour for README photos and promo recordings. Showcase can use your own music while hiding your username. Build with `debug_build: true` and `publish_release: false`; Release keeps the normal UI. See [Debug and showcase](docs/DEBUG-SHOWCASE.md) for capture controls and verification limits.

## Current limits

This is an early project. Initial imports need the app open, large libraries need profiling, and edits or deletions outside the refresh window are not reconciled. Identical events can coalesce; partial imports are labeled. next.fm reads history and does not control playback or submit scrobbles. See the [roadmap](TODO.md) for planned work.

## Credits and license

Statistics inspired by [Last.fm Stats Web](https://github.com/felhag/lastfm-stats-web). Listening data comes from [Last.fm](https://www.last.fm); artwork belongs to its respective owners. next.fm is independent of Last.fm and Apple.

Licensed under the [GNU General Public License v3.0](LICENSE).
