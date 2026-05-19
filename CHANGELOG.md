# Changelog

## v1.0.7 - 2026-05-19

- Added Codex artifact cleanup for stale generated image runs.
- Added cleanup for stale shell snapshot files.
- Added dashboard metrics and cleanup results for generated artifacts.
- Updated cleanup tests to verify generated artifacts are archived, not deleted.
- Updated the app bundle version emitted by the build script.

## v1.0.6 - 2026-05-14

- Removed placeholder cleanup data before the first real scan completes.
- Removed nonfunctional sidebar destinations so only working controls remain.
- Added before-and-after cleanup results for active chats, logs, stale items, and missing projects.
- Filtered the cleanup plan to show only actions backed by current scan data.
- Added tests for cleanup result comparisons and plan filtering.

## v1.0.5 - 2026-05-04

- Stabilized layout during scan and cleanup state changes.
- Reserved toolbar progress space so the toolbar height no longer jumps.
- Replaced conditional action panels with one fixed-height action status panel.
- Added fixed-width toolbar buttons so labels do not resize the action area.
- Kept error, locked, ready, and progress states in the same visual location.

## v1.0.4 - 2026-05-04

- Made disabled cleanup controls visually disabled.
- Added a clear cleanup locked state when Codex is open.
- Added visible cleanup failure messaging instead of only updating toolbar text.
- Added tooltip/help text explaining why cleanup cannot run.

## v1.0.3 - 2026-05-04

- Added visible scan progress in the toolbar and main dashboard.
- Added scan phase labels and percentages so loading state is understandable.
- Added a retryable error state for scan failures.
- Kept cleanup disabled while scan progress is active.

## v1.0.2 - 2026-05-04

- Fixed a launch-time scan hang caused by process detection waiting on `ps`
  output before reading it.
- Replaced shell process detection with native macOS
  `NSWorkspace.runningApplications`.
- Added a placeholder dashboard so the app shows useful state while scanning.
- Added visible scan errors instead of leaving the app on a loading state.

## v1.0.1 - 2026-05-04

- Replaced the README screenshot with a cropped app-only screenshot.
- Added a dedicated 1280 x 640 social preview image for sharing.
- Improved README SEO copy for Codex, macOS, SwiftUI, and developer-tool search.

## v1.0.0 - 2026-05-04

- Initial native SwiftUI macOS app.
- Added one-button Codex scan and cleanup flow.
- Added backup-before-mutation behavior.
- Added stale active session archiving.
- Added stale worktree archiving.
- Added oversized SQLite log-family rotation.
- Added missing config project pruning.
- Added tests for cleanup safety and repeat runs.
- Added light-mode native Apple internal-tool UI.
