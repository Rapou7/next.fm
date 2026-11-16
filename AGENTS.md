# next.fm — AI project context

This file applies to the whole repository. Read it when starting work on a new
computer, then inspect `git status`, the current request, and the relevant code.
This is a handoff snapshot, not a new task list. Do not automatically implement
roadmap items or repeat old builds unless the current task calls for it.

## Product and direction

- Repository: https://github.com/Rapou7/next.fm
- Native iPhone Last.fm listening-history dashboard, written in Swift 6 and
  SwiftUI, targeting iOS 26+. This is not a Flutter or web project.
- Visual direction: artwork-led Apple Music / Apple Fitness feel, native bottom
  tabs, Swift Charts, Liquid Glass controls, compact rankings, and an accent
  palette defined in `App/DesignSystem.swift`.
- Four tabs: Summary, Tops, Library, History. Account/settings opens from the
  profile button. Demo mode works without credentials.
- Read-only Last.fm client: no playback control or scrobble submission. History
  stays on the device; there is no next.fm backend.
- Rankings count scrobbles. Genre and listening-minute rankings are explicitly
  deferred until reliable metadata/counting rules exist.

## Architecture and entry points

- `App/NextFMApp.swift`: app entry and model setup.
- `App/AppModel.swift`: `@MainActor @Observable` UI state, account restoration,
  demo mode, sync lifecycle, and generation tokens that reject stale results.
  `Sources/NextFMCore/Analytics.swift` runs statistics and History grouping in an
  actor separately from UI state. Its single-entry history-insights cache uses
  the model revision, calendar and day (and expires when future events become
  eligible). Change the revision whenever history changes, including profiles.
  Unchanged sync results retain the revision; now-playing callers share an
  in-flight request and reuse successful results for 10 seconds.
- `App/RootView.swift`: tabs, connect/settings screens, and foreground
  now-playing polling (45 seconds).
- `App/SummaryView.swift`, `ProfileDashboardView.swift`, `ListeningCharts.swift`:
  range-aware summary and charts.
- `App/ListeningClock.swift`, `ScrobbleCalendar.swift`,
  `ListeningHighlights.swift`, `NowPlayingIndicator.swift`: listening insights.
- `App/TopsView.swift`, `TopRankCard.swift`, `TimeRangeBar.swift`: swipeable
  Tracks / Artists / Albums, compact rows, and interactive time selection.
- `App/LibraryView.swift`, `HistoryView.swift`, `AboutView.swift`: browsing,
  details, history filtering, and app credits.
- `Sources/NextFMCore/Models.swift`: shared models and calendar-based ranges.
- `Sources/NextFMCore/LastFMClient.swift`: API decoding, errors, bounded retries.
- `Sources/NextFMCore/SyncService.swift`: paginated initial import and refresh.
- `Sources/NextFMCore/HistoryStore.swift`: actor-isolated SQLite storage using
  the platform library through `Sources/CSQLite/`; no third-party Swift packages.
- `Sources/NextFMCore/StatsEngine.swift` and `DashboardStats.swift`: rankings,
  summaries, buckets, streaks, percentages, monthly favorites.
- `Tests/NextFMCoreTests/`: Swift Testing tests for API, storage, sync, statistics,
  date boundaries, and dashboard behavior.

## Behavior to preserve

- Initial history import freezes an upper cutoff so new scrobbles cannot shift
  pagination. Each page and its resume checkpoint commit in one transaction.
- Refresh overlaps the recent window and deduplicates events. Storage isolates
  profiles by normalized username. Cancellation must preserve resumable imports.
- Now-playing tracks and undated events do not enter dated scrobble statistics.
- Four weeks means today plus 27 preceding calendar days; six months starts at
  midnight six calendar months ago. Custom dates include both whole days.
- Use device calendar/timezone and calendar arithmetic, including DST. Filters
  use start-inclusive, end-exclusive boundaries. A current streak may end yesterday.
- Summary metrics/charts, listening habits, and Tops must follow their selected ranges.
  The scrobble calendar and monthly favorites always use all imported history,
  independent of the Summary range; the current month is month-to-date. Partial
  history must be labeled rather than implying complete lifetime statistics.
- Days-scrobbled denominators exclude dates before the first imported scrobble.
  Calendar navigation includes silent days/months through today.
- Monthly charts require more than 31 eligible calendar days and multiple monthly
  buckets; yearly charts require more than 366 and multiple yearly buckets.
- The listening clock has a fixed 24-hour structure and central hole, including
  silent hours. Keep tap/drag and VoiceOver interactions.
- Respect Reduce Motion, Dynamic Type, and native button/tab behavior. Keep
  currently playing / last played prominent at the top of Summary.

## Setup on another computer

Clone the repository and check the branch/commit before continuing:

```sh
git clone https://github.com/Rapou7/next.fm.git
cd next.fm
git status
git log -5 --oneline
```

For the native app, use macOS with Xcode 26.2 or newer, XcodeGen, and Python 3.
CI currently selects Xcode 26.2 explicitly. On macOS:

```sh
brew install xcodegen
python3 scripts/configure.py
swift test
xcodegen generate
open NextFM.xcodeproj
```

`project.yml` is the source of truth; change it rather than editing the generated
Xcode project. `Package.swift` defines the independently testable core package.
Linux core testing needs Swift 6 and SQLite development headers
(`libsqlite3-dev`). Windows can edit sources and use macOS GitHub Actions for
iPhone builds; do not assume native Xcode builds are available on Windows.

## Build, test, and package

Run `swift test` for core logic changes. It does not compile SwiftUI app screens;
UI changes also need an Xcode build. Device interactions require manual checks.
Do not report a device test or fresh compilation unless actually performed.

After configuring and generating the project on macOS:

```sh
xcodebuild -project NextFM.xcodeproj -scheme NextFM \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
bash scripts/package-ipa.sh
```

Output: `build/next.fm-unsigned.ipa`. Packaging requires an already built
`build/DerivedData/Build/Products/Release-iphoneos/NextFM.app`.

The active workflow is **`.github/workflows/ios-ipa-build.yml`**. It runs only
on manual dispatch, using macOS 15. Routine pushes and pull requests do not compile. It
tests the core, configures resources, generates the project, builds without
signing, and uploads `next.fm-unsigned-<run number>` and `build-log-<run number>`.
The ignored root `ios-ipa-build.yml` is a legacy Flutter reference, not this pipeline.

### Build, push, and release policy

- Do not compile the app, dispatch CI, bump versions, tag, or publish a release
  after every prompt. Wait for the user to request a build or a new release.
- Commit and push only when requested. A request to push does not imply a build
  or release, especially for documentation, workflow, or other small changes.
- Run relevant core tests for core logic changes; routine documentation edits
  do not need compilation. Report checks actually performed.
- For an explicitly requested build, manually dispatch the workflow with
  `publish_release: false` (the default); retrieve the Actions IPA artifact.
- For an explicitly requested new release, set the intended version in
  `project.yml` and version fallbacks, commit/push as authorized, then manually
  dispatch with `publish_release: true`. It builds and attaches the unsigned
  IPA to `v<MARKETING_VERSION>` in GitHub Releases. It rejects an existing tag
  pointing at a different commit; retries reuse the same release.
- Do not create a release for every fix. Batch changes until the user asks
  for the next release. Changing this workflow does not authorize running it.

Download an artifact ZIP from a successful run and extract the IPA. It is
unsigned and intended for LiveContainer or a separate signing/install process;
it is not an App Store release. Consult `docs/DEVICE-TEST.md` for device checks.

### Windows development

Windows can edit sources and run core tests through WSL/Docker with Swift 6
and SQLite development headers. Full iPhone builds use the manually dispatched
GitHub Actions workflow described above; local Xcode builds require macOS.

Machine-specific commands, local tool status, and artifact records belong in
`AGENTS.private.md`, which is ignored by Git. If that file exists, read it for
local setup details. Never add credentials to either instructions file.

## Configuration and machine-local files

- Username and an API key are sufficient; no Last.fm password or API secret.
- `scripts/configure.py` writes `App/Resources/BuildConfig.json`, reading the
  optional `LASTFM_API_KEY` environment variable (empty is allowed for demo/manual
  entry). CI uses an optional repository secret with the same name.
- Do not commit credentials or print tokens. An embedded API key is extractable
  from the app and is not a protected server secret.
- The app stores history in Application Support as `nextfm.sqlite`; username
  and API key are currently saved in UserDefaults. Disconnect does not erase
  imported history. User-initiated deletion is a roadmap item.
- Generated Xcode projects/workspaces, `.build/`, `build/`, IPAs, local build
  config, and editor workspace files are ignored. A clone will not include them.
  Regenerate/download them on the new machine; obtain credentials separately.

## Known limits and next work

Read `TODO.md` and `docs/DEVICE-TEST.md` before choosing follow-up work. Priorities
include device validation, JSON import/export, history reconciliation, artwork
caching, accessibility, and large-library profiling. Do not treat these as
already implemented:

- Edits/deletions or late scrobbles outside the refresh window are not reconciled.
- Identical timestamp/artist/album/track events coalesce, losing multiplicity.
- Large histories are loaded into memory for analysis; 100k–1m-event profiles
  still need profiling.
- Artist images use associated album artwork; there is no dedicated disk cache.
- Initial import needs the app open; continuous background sync is absent.
- Calendar heatmap/discovery/milestones/ranking history, multi-account switching,
  widgets, recaps, and authenticated actions remain roadmap work.

Keep changes scoped to the current request. If asked only to compile, finish
the build and retrieve artifacts without unrelated code edits. Keep this file
and user-facing docs accurate when architecture or build requirements change.
Last.fm Stats Web inspired the statistics. Preserve attribution if adapting
external code.

## Debug diagnostics and showcase (0.2.3 work)

`App/DebugTools.swift` and `App/ShowcasePresentation.swift` provide Debug-only capture, startup animation and a choreographed feature tour. Showcase preserves current music and masks the username through `AppModel.displayUsername`; demo data is optional. Release has no tools or tour and `Diagnostics` cannot record. Core diagnostics are bounded to 2,000 in-memory events with safe error codes, not raw error descriptions or request URLs. See `docs/DEBUG-SHOWCASE.md`.

The manual IPA workflow accepts `debug_build` (default false), selecting Debug or Release; debug release publishing is rejected. `scripts/package-ipa.sh` accepts `CONFIGURATION` (default Release). No dispatch, push, or release is implied by these changes. iPhone compilation, rendering, and ReplayKit in LiveContainer still need verification.
