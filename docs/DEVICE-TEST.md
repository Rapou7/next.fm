# First device verification

The initial GitHub Actions build passed core tests, compiled the iPhone app with Xcode 26.2, and produced an unsigned IPA. The on-device checks below remain unverified.

1. Build the IPA in GitHub Actions; confirm core tests and iPhone compilation pass.
2. Import into LiveContainer and launch. Check icon, launch screen, and app name.
3. Open demo mode. Check four bottom icon tabs in light/dark appearance and larger text.
4. Summary: currently playing / last played remains at the top; chart scrubbing shows date/count.
5. Tops: switch Tracks / Artists / Albums; test every range and custom date endpoints.
6. Library: search and open artist/album/track details. History: search and filter by day.
7. Connect a real public Last.fm account. Verify failed/invalid keys show an actionable error.
8. Pause during import, relaunch, and resume; ensure totals do not double after refresh.
9. Go offline after sync. Cached history must remain usable. Resume network access and retry.
10. Play music through a scrobbling source. Verify the currently-playing card refreshes while next.fm is active; pull to refresh to import new events.
11. Compare a complete custom-date ranking against Last.fm Stats Web with matching timezone and boundaries.
12. Test a large profile for memory pressure and scrolling responsiveness before distributing more broadly.
