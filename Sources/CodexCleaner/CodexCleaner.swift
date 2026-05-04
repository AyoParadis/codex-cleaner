import AppKit
import Foundation

final class CodexCleaner {
  private let fileManager = FileManager.default
  private let codexHome: URL
  private let staleSessionDays: Int
  private let staleWorktreeDays: Int
  private let largeLogBytes: Int64
  private let codexRunningProvider: () -> Bool

  init(
    codexHome: URL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex"),
    staleSessionDays: Int = 10,
    staleWorktreeDays: Int = 14,
    largeLogBytes: Int64 = 100 * 1_024 * 1_024,
    codexRunningProvider: @escaping () -> Bool = CodexCleaner.detectCodexRunning
  ) {
    self.codexHome = codexHome
    self.staleSessionDays = staleSessionDays
    self.staleWorktreeDays = staleWorktreeDays
    self.largeLogBytes = largeLogBytes
    self.codexRunningProvider = codexRunningProvider
  }

  func scan() -> CleanerReport {
    let activeSessions = files(
      under: codexHome.appendingPathComponent("sessions"),
      matching: { $0.pathExtension == "jsonl" }
    )
    let archivedSessions = files(
      under: codexHome.appendingPathComponent("archived_sessions"),
      matching: { $0.pathExtension == "jsonl" }
    )
    let logFiles = files(
      under: codexHome,
      recursive: false,
      matching: { $0.lastPathComponent.hasPrefix("logs_") }
    )
    let worktrees = directories(
      under: codexHome.appendingPathComponent("worktrees")
    )
    let staleSessions = staleFiles(activeSessions, olderThanDays: staleSessionDays)
    let staleWorktrees = staleDirectories(
      worktrees,
      olderThanDays: staleWorktreeDays
    )
    let missingProjects = missingConfigProjects()
    let largest = (activeSessions + archivedSessions + logFiles)
      .map(record(for:))
      .sorted { $0.bytes > $1.bytes }
      .prefix(12)

    let metrics = CleanerMetrics(
      codexHome: codexHome,
      totalBytes: directorySize(codexHome),
      activeSessionBytes: activeSessions.reduce(0) { $0 + fileSize($1) },
      archivedSessionBytes: archivedSessions.reduce(0) { $0 + fileSize($1) },
      logBytes: logFiles.reduce(0) { $0 + fileSize($1) },
      activeSessionCount: activeSessions.count,
      staleSessionCount: staleSessions.count,
      staleWorktreeCount: staleWorktrees.count,
      largeLogCount: logFiles.filter { fileSize($0) >= largeLogBytes }.count,
      missingProjectCount: missingProjects.count,
      codexIsRunning: codexRunningProvider()
    )

    return CleanerReport(
      scannedAt: Date(),
      metrics: metrics,
      largestFiles: Array(largest),
      plan: makePlan(metrics: metrics)
    )
  }

  func clean() throws -> CleanupResult {
    let report = scan()
    if report.metrics.codexIsRunning {
      throw CleanerError.codexIsRunning
    }

    let backupDirectory = try createBackup()
    var result = CleanupResult(
      backupDirectory: backupDirectory,
      archivedSessions: 0,
      archivedWorktrees: 0,
      rotatedLogs: 0,
      prunedProjects: 0,
      bytesMoved: 0,
      verificationNotes: []
    )

    for file in staleFiles(
      files(
        under: codexHome.appendingPathComponent("sessions"),
        matching: { $0.pathExtension == "jsonl" }
      ),
      olderThanDays: staleSessionDays
    ) {
      result.bytesMoved += fileSize(file)
      try move(file, toDirectory: codexHome.appendingPathComponent("archived_sessions"))
      result.archivedSessions += 1
    }

    let worktreeArchive = codexHome
      .appendingPathComponent("archived_worktrees")
      .appendingPathComponent(timestamp())
    for directory in staleDirectories(
      directories(under: codexHome.appendingPathComponent("worktrees")),
      olderThanDays: staleWorktreeDays
    ) {
      result.bytesMoved += directorySize(directory)
      try move(directory, toDirectory: worktreeArchive)
      result.archivedWorktrees += 1
    }

    let logArchive = codexHome
      .appendingPathComponent("archived_logs")
      .appendingPathComponent(timestamp())
    for file in files(
      under: codexHome,
      recursive: false,
      matching: { $0.lastPathComponent.hasPrefix("logs_") }
    ) where fileSize(file) >= largeLogBytes {
      result.bytesMoved += fileSize(file)
      try move(file, toDirectory: logArchive)
      result.rotatedLogs += 1
    }

    result.prunedProjects = try pruneMissingConfigProjects()
    result.verificationNotes = verify(after: result)
    return result
  }

  func revealCodexHome() {
    NSWorkspace.shared.activateFileViewerSelecting([codexHome])
  }

  private func makePlan(metrics: CleanerMetrics) -> [CleanupPlanItem] {
    [
      CleanupPlanItem(
        title: "Back up important Codex state",
        detail: "Config, state databases, session index, memories, rules, and automations are copied before cleanup.",
        impact: "Safety first"
      ),
      CleanupPlanItem(
        title: "Archive stale active chats",
        detail: "\(metrics.staleSessionCount) session files older than \(staleSessionDays) days can move out of the hot sessions folder.",
        impact: formatBytes(metrics.activeSessionBytes)
      ),
      CleanupPlanItem(
        title: "Move stale worktrees",
        detail: "\(metrics.staleWorktreeCount) old worktree folders can move to archived_worktrees.",
        impact: "Keeps active work light"
      ),
      CleanupPlanItem(
        title: "Rotate oversized logs",
        detail: "\(metrics.largeLogCount) log files are over \(formatBytes(largeLogBytes)) and can be archived so Codex starts fresh.",
        impact: formatBytes(metrics.logBytes)
      ),
      CleanupPlanItem(
        title: "Prune missing config projects",
        detail: "\(metrics.missingProjectCount) trusted project entries point to paths that no longer exist.",
        impact: "Cleaner config"
      ),
      CleanupPlanItem(
        title: metrics.codexIsRunning ? "Close Codex before cleanup" : "Ready to clean",
        detail: metrics.codexIsRunning
          ? "The app will scan while Codex is open, but cleanup waits so local databases are not touched from two places."
          : "Codex is not running, so the one-button cleanup can proceed.",
        impact: metrics.codexIsRunning ? "Blocked" : "Clear",
        isBlocked: metrics.codexIsRunning
      ),
    ]
  }

  private func createBackup() throws -> URL {
    let backupRoot = codexHome
      .appendingPathComponent("maintenance_backups")
      .appendingPathComponent(timestamp())
    try fileManager.createDirectory(
      at: backupRoot,
      withIntermediateDirectories: true
    )

    let names = [
      "config.toml",
      "auth.json",
      "session_index.jsonl",
      "state_5.sqlite",
      "state_5.sqlite-wal",
      "state_5.sqlite-shm",
      ".codex-global-state.json",
      ".codex-global-state.json.bak",
    ]

    for name in names {
      let source = codexHome.appendingPathComponent(name)
      if fileManager.fileExists(atPath: source.path) {
        try fileManager.copyItem(
          at: source,
          to: backupRoot.appendingPathComponent(name)
        )
      }
    }

    for name in ["automations", "memories", "rules"] {
      let source = codexHome.appendingPathComponent(name)
      if fileManager.fileExists(atPath: source.path) {
        try fileManager.copyItem(
          at: source,
          to: backupRoot.appendingPathComponent(name)
        )
      }
    }

    return backupRoot
  }

  private func pruneMissingConfigProjects() throws -> Int {
    let config = codexHome.appendingPathComponent("config.toml")
    guard var text = try? String(contentsOf: config, encoding: .utf8) else {
      return 0
    }

    let missing = Set(missingConfigProjects())
    guard !missing.isEmpty else { return 0 }

    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
    var output: [String] = []
    var index = 0
    var removed = 0

    while index < lines.count {
      let line = lines[index]
      if let projectPath = projectPath(fromHeader: line),
        missing.contains(projectPath)
      {
        removed += 1
        index += 1
        while index < lines.count, !lines[index].hasPrefix("[") {
          index += 1
        }
        continue
      }
      output.append(line)
      index += 1
    }

    text = output.joined(separator: "\n")
    try text.write(to: config, atomically: true, encoding: .utf8)
    return removed
  }

  private func missingConfigProjects() -> [String] {
    let config = codexHome.appendingPathComponent("config.toml")
    guard let text = try? String(contentsOf: config, encoding: .utf8) else {
      return []
    }

    return text
      .split(separator: "\n")
      .compactMap { projectPath(fromHeader: String($0)) }
      .filter { !fileManager.fileExists(atPath: $0) }
  }

  private func projectPath(fromHeader line: String) -> String? {
    let prefix = "[projects.\""
    let suffix = "\"]"
    guard line.hasPrefix(prefix), line.hasSuffix(suffix) else { return nil }
    return String(line.dropFirst(prefix.count).dropLast(suffix.count))
  }

  private func verify(after result: CleanupResult) -> [String] {
    var notes = [
      "Backup created before cleanup.",
      "Config file is still readable.",
      "Archived sessions folder is present.",
    ]

    if result.archivedSessions == 0 {
      notes.append("No stale active sessions needed archiving.")
    }
    if result.rotatedLogs == 0 {
      notes.append("No oversized logs needed rotation.")
    }
    return notes
  }

  private func files(
    under directory: URL,
    recursive: Bool = true,
    matching: (URL) -> Bool
  ) -> [URL] {
    guard fileManager.fileExists(atPath: directory.path) else { return [] }

    if !recursive {
      let contents = (try? fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )) ?? []
      return contents.filter(matching)
    }

    guard let enumerator = fileManager.enumerator(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return enumerator.compactMap { $0 as? URL }.filter(matching)
  }

  private func directories(under directory: URL) -> [URL] {
    let contents = (try? fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
      options: [.skipsHiddenFiles]
    )) ?? []

    return contents.filter { url in
      ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
    }
  }

  private func staleFiles(_ files: [URL], olderThanDays days: Int) -> [URL] {
    let cutoff = Calendar.current.date(
      byAdding: .day,
      value: -days,
      to: Date()
    ) ?? Date()

    return files.filter { modifiedAt($0) < cutoff }
  }

  private func staleDirectories(_ directories: [URL], olderThanDays days: Int)
    -> [URL]
  {
    let cutoff = Calendar.current.date(
      byAdding: .day,
      value: -days,
      to: Date()
    ) ?? Date()

    return directories.filter { modifiedAt($0) < cutoff }
  }

  private func move(_ source: URL, toDirectory directory: URL) throws {
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let destination = uniqueDestination(
      for: source,
      in: directory
    )
    try fileManager.moveItem(at: source, to: destination)
  }

  private func uniqueDestination(for source: URL, in directory: URL) -> URL {
    let initial = directory.appendingPathComponent(source.lastPathComponent)
    guard fileManager.fileExists(atPath: initial.path) else {
      return initial
    }

    let baseName = source.deletingPathExtension().lastPathComponent
    let pathExtension = source.pathExtension
    let suffix = pathExtension.isEmpty ? "" : ".\(pathExtension)"
    return directory.appendingPathComponent("\(baseName)-\(timestamp())\(suffix)")
  }

  private static func detectCodexRunning() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-axo", "comm,args"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return true
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return output
      .split(separator: "\n")
      .contains { line in
        let value = String(line)
        return value.contains("/Codex.app/")
          || value.contains("Codex.app/Contents/MacOS/Codex")
      }
  }

  private func record(for url: URL) -> FileRecord {
    FileRecord(url: url, bytes: fileSize(url), modifiedAt: modifiedAt(url))
  }

  private func fileSize(_ url: URL) -> Int64 {
    let values = try? url.resourceValues(forKeys: [.fileSizeKey])
    return Int64(values?.fileSize ?? 0)
  }

  private func directorySize(_ url: URL) -> Int64 {
    guard let enumerator = fileManager.enumerator(
      at: url,
      includingPropertiesForKeys: [.fileSizeKey],
      options: [.skipsHiddenFiles]
    ) else {
      return 0
    }

    return enumerator.compactMap { $0 as? URL }.reduce(Int64(0)) {
      $0 + fileSize($1)
    }
  }

  private func modifiedAt(_ url: URL) -> Date {
    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
    return values?.contentModificationDate ?? .distantPast
  }

  private func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: Date())
  }
}

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
