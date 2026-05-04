# Changelog

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
