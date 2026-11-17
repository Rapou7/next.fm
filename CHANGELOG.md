# Changelog

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
