import Foundation

struct CleanerMetrics: Equatable {
  var codexHome: URL
  var totalBytes: Int64
  var activeSessionBytes: Int64
  var archivedSessionBytes: Int64
  var logBytes: Int64
  var activeSessionCount: Int
  var staleSessionCount: Int
  var staleWorktreeCount: Int
  var largeLogCount: Int
  var missingProjectCount: Int
  var codexIsRunning: Bool
}

struct CleanupPlanItem: Identifiable, Equatable {
  let id = UUID()
  var title: String
  var detail: String
  var impact: String
  var isBlocked: Bool = false
}

struct CleanupResult: Equatable {
  var backupDirectory: URL?
  var archivedSessions: Int
  var archivedWorktrees: Int
  var rotatedLogs: Int
  var prunedProjects: Int
  var bytesMoved: Int64
  var verificationNotes: [String]
}

struct CleanerReport: Equatable {
  var scannedAt: Date
  var metrics: CleanerMetrics
  var largestFiles: [FileRecord]
  var plan: [CleanupPlanItem]
}

enum ScanState: Equatable {
  case idle
  case scanning
  case failed(String)
}

struct ScanProgress: Equatable {
  var title: String
  var detail: String
  var fraction: Double

  static let idle = ScanProgress(
    title: "Ready",
    detail: "Run a scan to inspect local Codex state.",
    fraction: 0
  )
}

struct FileRecord: Identifiable, Equatable {
  var id: String { url.path }
  var url: URL
  var bytes: Int64
  var modifiedAt: Date
}
