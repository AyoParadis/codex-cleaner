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

func formatBytes(_ bytes: Int64) -> String {
  ByteCountFormatter.string(
    fromByteCount: bytes,
    countStyle: .file
  )
}
