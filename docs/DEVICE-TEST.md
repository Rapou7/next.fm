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

## Summary and Tops layout regression checks

- Load real artwork on Summary, then scroll away and back. The status, cover, title, and artist must remain inside the card before and after the image loads.
- Try a long track title and accessibility text sizes. The card should grow, with a vertical arrangement at accessibility sizes.
- In Tops, verify the underlined Tracks / Artists / Albums tabs and that the ranking begins without a separate top-spot card.
- Tap and slide across the timeframe choices. Check interactive glass selection and haptic feedback; VoiceOver should expose each choice as a selectable button.
- Expand the up arrow. Today / This week / current year must appear above the main row, with a calendar button at right. Collapse, reopen, and apply custom dates.
- Check Reduce Motion, both appearances, and that the bottom navigation remains usable while the timeframe panel is expanded.

## Reference layout update

- Tops: check compact rounded rows, rank outside each card, square track/album covers, round artist covers, and single-line title/metadata. Test rank 100+ and large text.
- Summary: change all timeframe options and confirm totals, top-music shelves, and all charts update together. First/last cumulative counts should match the selected scrobbles.
- Open each chart's expand button and dismiss its sheet. Check empty profiles and ranges with no scrobbles.
- Settings → About: check the actual app icon, next.fm title, version/build, repository link, and Rapou7 / Codex credits.
