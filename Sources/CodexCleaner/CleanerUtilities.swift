import Foundation

enum CleanerError: LocalizedError {
  case codexIsRunning

  var errorDescription: String? {
    switch self {
    case .codexIsRunning:
      return "Codex is running. Close Codex, then run cleanup again so the local database is not touched from two places."
    }
  }
}

func formatBytes(_ bytes: Int64) -> String {
  ByteCountFormatter.string(
    fromByteCount: bytes,
    countStyle: .file
  )
}
