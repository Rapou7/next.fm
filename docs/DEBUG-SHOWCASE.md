# Debug diagnostics and showcase (0.2.3)

These tools are available only in the **Debug IPA**. Release has no debug panel,
showcase animation, tour, or recording controls; diagnostics recording cannot be
enabled in Release. No files are uploaded automatically.

## Build

On macOS, configure resources and generate the project as usual, then select the
Debug configuration in Xcode. For an unsigned device IPA:

```sh
xcodebuild -project NextFM.xcodeproj -scheme NextFM \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
CONFIGURATION=Debug bash scripts/package-ipa.sh
```

Alternatively, manually dispatch the IPA workflow with `debug_build: true` and
`publish_release: false`. The artifact name contains `debug`; the extracted IPA
is still `next.fm-unsigned.ipa`. Debug and Release currently share the same bundle
identifier, so treat them as alternative installations. Debug timings include
unoptimized code overhead and should not be treated as Release benchmarks.

## Logs and rendering feedback

Open the bug button, or **Account > Debug tools**. Recording starts automatically
in Debug. Logs include API attempts, backoff, HTTP/API/network error codes, page
commits, database load/save durations, analytics durations, lifecycle events and
screen visits. Export or clear them from the panel. The recorder keeps only the
latest 2,000 events in memory; relaunching loses that session. This is not a crash
reporter, frame profiler, or persistent background logger.

**Capture screenshot + feedback files** dismisses the panel, waits three seconds,
captures the current app window at its native scale and opens a share sheet with:

- `screenshot.png`
- `rendering-context.json` (version/build, OS, screen geometry, text size,
  appearance, accent, locale, timezone, demo status and imported event count)
- `diagnostics.json`

For feedback, send those files with what looks wrong and the steps that led to it.
Logs exclude account names, API keys, request URLs, payloads and music titles.
Screenshots and videos contain the music visible on screen. Enable showcase mode
to mask the username first. Temporary exports stay in the app's temporary folder
until iOS cleans it up. Window capture may differ from system screenshots for
status bars and system-owned surfaces; compare a native screenshot when needed.

## Automatic showcase for README photos or promo video

1. Load your profile (or optionally choose **Use demo data instead**).
2. Open **Account > Debug tools** and enable **Showcase mode (hide username)**.
   This preserves your listening data and artwork, replaces the visible account
   name with "Your listening", hides the bug button and lets you choose light or
   dark appearance. It does not change your stored username or credentials.
3. Choose **Play animated showcase** to run it with your own recorder, or leave
   automatic touring enabled and choose **Record animated showcase tour**.
4. The approximately one-minute sequence plays a branded startup animation,
   reveals Summary, scrolls through metrics, calendar, artwork, activity charts,
   listening clock and monthly favorites; switches through Tracks / Artists /
   Albums with ranking scrolls; scrolls the artwork library; expands recent
   History; then returns to the Summary header. Scrolls ease over 2.4 seconds
   with reading pauses. Reduce Motion disables spatial animation.
5. Built-in recording uses ReplayKit with the microphone off and opens Apple's
   preview for review and sharing. Accept the system permission prompt and retry
   if it interrupts the first take. Trim or crop for TikTok in your editor; there
   is no added soundtrack, caption track, or automatic posting.

For still photos, enable showcase mode, navigate to the desired feature and use
the screenshot action. Settings remain accessible through Account while the bug
button is hidden. Stop a running tour from the same panel. Turn showcase mode off
to restore the account label and normal appearance; scroll positions and the
selected tab remain where the tour left them. After switching to demo data, use
the account screen to reconnect to your saved profile. Demo data is anchored to
the current day, not a frozen date. A Debug launch argument `--showcase` opens
directly into demo showcase without restoring a saved account.

## Device validation still required

- Build Debug and Release with Xcode; ensure Release has no debug controls.
- In Debug, verify username masking in Summary and Account while API sync still
  uses the real identity. Confirm normal labels return after leaving showcase.
- Run the complete tour with real artwork, demo data, sparse/empty history,
  light/dark appearance, larger text and Reduce Motion. Confirm every scroll
  destination is visible and transitions do not clip content on the target phone.
- Verify screenshot dimensions, captured safe areas, share cancellation and
  exported metadata/logs. Test offline failures and retry timing.
- Test ReplayKit permission denial, recording/preview/export, unavailable capture,
  cancellation and backgrounding in LiveContainer; compatibility is unverified.
- Leave the app, relaunch, and ensure diagnostics are bounded and account/history
  persistence and import resume still work normally.

No device screenshots or promo video have been captured or visually approved as
part of this Windows implementation. Core tests do not compile the SwiftUI UI.
