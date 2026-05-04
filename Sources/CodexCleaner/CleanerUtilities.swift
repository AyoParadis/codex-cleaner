import Foundation

enum CleanerError: LocalizedError, Equatable {
  case codexIsRunning
  case codexHomeMissing(String)

  var errorDescription: String? {
    switch self {
    case .codexIsRunning:
      return "Codex is running. Close Codex, then run cleanup again so the local database is not touched from two places."
    case .codexHomeMissing(let path):
      return "Could not find Codex home at \(path). Open Codex once, then scan again."
    }
  }
}

extension CleanerReport {
  static var placeholder: CleanerReport {
    let codexHome = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex")
    let metrics = CleanerMetrics(
      codexHome: codexHome,
      totalBytes: 0,
      activeSessionBytes: 0,
      archivedSessionBytes: 0,
      logBytes: 0,
      activeSessionCount: 0,
      staleSessionCount: 0,
      staleWorktreeCount: 0,
      largeLogCount: 0,
      missingProjectCount: 0,
      codexIsRunning: true
    )

    return CleanerReport(
      scannedAt: Date(),
      metrics: metrics,
      largestFiles: [],
      plan: [
        CleanupPlanItem(
          title: "Scanning Codex state",
          detail: "The app is checking sessions, worktrees, logs, and config entries.",
          impact: "Working"
        ),
      ]
    )
  }
}

func formatBytes(_ bytes: Int64) -> String {
  ByteCountFormatter.string(
    fromByteCount: bytes,
    countStyle: .file
  )
}
