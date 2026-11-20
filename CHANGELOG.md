# Changelog

## 0.3.3

- Timeframe selectors use native Liquid Glass animations when you tap or slide between ranges. The arrow opens Today, This week, the current year, and Custom dates.
- Swipe across the listening clock to scroll. Hold briefly on an hour, then drag to explore. The hour readout appears below the dial so the dial stays in place.
- Ranking labels such as `#100` stay on one line and cards align across the list.
- Account settings show estimated listening time in localized hours and minutes, with the matched-scrobble count below.
- Artist profiles use a line chart for Daily listening over ranges longer than three months. Silent days appear at zero.
- The iOS bundle identifier is now `com.rapou7.nextfm`.

[Full changelog](https://github.com/Rapou7/next.fm/compare/v0.3.2...v0.3.3)

## 0.3.2

- Account settings can sort Tops, Summary lists, Search, and profile rankings by scrobbles or estimated listening time.
- Summary centers the text in all nine tiles. Duration labels use minutes, and match coverage appears below the listening-time toggle.
- Search shows its field on the first tap. Tapping the selected Search tab again focuses the field.

[Full changelog](https://github.com/Rapou7/next.fm/compare/v0.3.1...v0.3.2)

## 0.3.1

- Summary has nine equal-size tiles for counts, estimated minutes and hours, daily activity, and the most active hour.
- Estimated minutes appear alongside scrobble counts throughout Summary, Tops, profiles, Search, History, and chart details. The app reuses cached durations and shows match coverage.
- Shared backgrounds are darker across the app.

[Full changelog](https://github.com/Rapou7/next.fm/compare/v0.3.0...v0.3.1)

## 0.2.6

### Improvements

- Renamed the Library tab to Search, with a magnifying-glass icon and matching showcase navigation.
- Added a persistent History search field and calendar sheet, with date selection, cancellation, and quick clearing of search and date filters.
- Selecting a History date automatically expands that day's scrobbles.

### Fixes

- Refresh statistics when future-dated scrobbles become eligible or the device clock moves backward, while retaining cached results for unchanged history.
- Prevent stale library results during history updates and return to the top when changing music categories.
- Compute entity profile statistics and recent listening together off the UI actor, with cancellation support and consistent selected-range results.
- Refresh Summary and entity profiles when import completeness changes, and clarify song-specific album counts.

### Distribution

- Unsigned iPhone IPA for LiveContainer or a separate signing/install process. Device behavior remains subject to manual verification.

[Full changelog](https://github.com/Rapou7/next.fm/compare/v0.2.5...v0.2.6)
