import Foundation
import XCTest
@testable import CodexCleaner

final class CodexCleanerTests: XCTestCase {
  private var temporaryRoots: [URL] = []

  override func tearDownWithError() throws {
    for root in temporaryRoots {
      try? FileManager.default.removeItem(at: root)
    }
    temporaryRoots.removeAll()
  }

  func testScanAndCleanArchiveWithoutDeletingCodexData() throws {
    let root = try makeTemporaryCodexHome()
    let existingProject = root.appendingPathComponent("existing-project")
    try FileManager.default.createDirectory(
      at: existingProject,
      withIntermediateDirectories: true
    )

    try write("token", to: root.appendingPathComponent("auth.json"))
    try write("{}", to: root.appendingPathComponent("state_5.sqlite"))
    try write(
      """
      model = "gpt-5.5"

      [projects."\((existingProject.path))"]
      trust_level = "trusted"

      [projects."\((root.appendingPathComponent("missing-project").path))"]
      trust_level = "trusted"

      [features]
      apps = true
      """,
      to: root.appendingPathComponent("config.toml")
    )

    let oldSession = root
      .appendingPathComponent("sessions/2026/04/01/old.jsonl")
    let recentSession = root
      .appendingPathComponent("sessions/2026/05/04/recent.jsonl")
    try write("old chat", to: oldSession)
    try write("recent chat", to: recentSession)
    try setModifiedAt(daysAgo: 20, for: oldSession)
    try setModifiedAt(daysAgo: 1, for: recentSession)

    let staleWorktree = root.appendingPathComponent("worktrees/stale-worktree")
    try FileManager.default.createDirectory(
      at: staleWorktree,
      withIntermediateDirectories: true
    )
    try write("diff", to: staleWorktree.appendingPathComponent("note.txt"))
    try setModifiedAt(daysAgo: 30, for: staleWorktree)

    let largeLog = root.appendingPathComponent("logs_2.sqlite")
    try write(String(repeating: "x", count: 2_048), to: largeLog)
    let smallLogWal = root.appendingPathComponent("logs_2.sqlite-wal")
    try write("wal", to: smallLogWal)
    let smallLogShm = root.appendingPathComponent("logs_2.sqlite-shm")
    try write("shm", to: smallLogShm)

    let cleaner = CodexCleaner(
      codexHome: root,
      staleSessionDays: 10,
      staleWorktreeDays: 14,
      largeLogBytes: 1_024,
      codexRunningProvider: { false }
    )

    let report = try cleaner.scan()
    XCTAssertEqual(report.metrics.activeSessionCount, 2)
    XCTAssertEqual(report.metrics.staleSessionCount, 1)
    XCTAssertEqual(report.metrics.staleWorktreeCount, 1)
    XCTAssertEqual(report.metrics.largeLogCount, 1)
    XCTAssertEqual(report.metrics.missingProjectCount, 1)
    XCTAssertFalse(report.metrics.codexIsRunning)

    let result = try cleaner.clean()

    XCTAssertEqual(result.before.metrics.activeSessionCount, 2)
    XCTAssertEqual(result.before.metrics.staleSessionCount, 1)
    XCTAssertEqual(result.before.metrics.staleWorktreeCount, 1)
    XCTAssertEqual(result.before.metrics.largeLogCount, 1)
    XCTAssertEqual(result.before.metrics.missingProjectCount, 1)
    XCTAssertEqual(result.after.metrics.activeSessionCount, 1)
    XCTAssertEqual(result.after.metrics.staleSessionCount, 0)
    XCTAssertEqual(result.after.metrics.staleWorktreeCount, 0)
    XCTAssertEqual(result.after.metrics.largeLogCount, 0)
    XCTAssertEqual(result.after.metrics.missingProjectCount, 0)
    XCTAssertEqual(result.archivedSessions, 1)
    XCTAssertEqual(result.archivedWorktrees, 1)
    XCTAssertEqual(result.rotatedLogs, 3)
    XCTAssertEqual(result.prunedProjects, 1)
    XCTAssertGreaterThan(result.bytesMoved, 0)
    XCTAssertNotNil(result.backupDirectory)

    XCTAssertFalse(FileManager.default.fileExists(atPath: oldSession.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: recentSession.path))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("archived_sessions/old.jsonl").path
      )
    )
    XCTAssertFalse(FileManager.default.fileExists(atPath: largeLog.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: smallLogWal.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: smallLogShm.path))

    let archivedWorktrees = try contents(
      of: root.appendingPathComponent("archived_worktrees")
    )
    XCTAssertTrue(
      archivedWorktrees.contains {
        FileManager.default.fileExists(
          atPath: $0.appendingPathComponent("stale-worktree").path
        )
      }
    )

    let archivedLogs = try contents(of: root.appendingPathComponent("archived_logs"))
    XCTAssertTrue(
      archivedLogs.contains {
        FileManager.default.fileExists(
          atPath: $0.appendingPathComponent("logs_2.sqlite").path
        )
          && FileManager.default.fileExists(
            atPath: $0.appendingPathComponent("logs_2.sqlite-wal").path
          )
          && FileManager.default.fileExists(
            atPath: $0.appendingPathComponent("logs_2.sqlite-shm").path
          )
      }
    )

    let config = try String(
      contentsOf: root.appendingPathComponent("config.toml"),
      encoding: .utf8
    )
    XCTAssertTrue(config.contains(existingProject.path))
    XCTAssertFalse(config.contains("missing-project"))

    let backupDirectory = try XCTUnwrap(result.backupDirectory)
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: backupDirectory.appendingPathComponent("config.toml").path
      )
    )
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: backupDirectory.appendingPathComponent("auth.json").path
      )
    )
  }

  func testCleanBlocksWhenCodexIsRunning() throws {
    let root = try makeTemporaryCodexHome()
    let cleaner = CodexCleaner(
      codexHome: root,
      codexRunningProvider: { true }
    )

    XCTAssertThrowsError(try cleaner.clean()) { error in
      XCTAssertEqual(error as? CleanerError, .codexIsRunning)
    }
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: root.appendingPathComponent("maintenance_backups").path
      )
    )
  }

  func testRepeatedCleanupCreatesDistinctBackups() throws {
    let root = try makeTemporaryCodexHome()
    try write("model = \"gpt-5.5\"", to: root.appendingPathComponent("config.toml"))

    let cleaner = CodexCleaner(
      codexHome: root,
      codexRunningProvider: { false }
    )

    let first = try cleaner.clean()
    let second = try cleaner.clean()

    XCTAssertNotEqual(first.backupDirectory, second.backupDirectory)

    let firstBackup = try XCTUnwrap(first.backupDirectory)
    let secondBackup = try XCTUnwrap(second.backupDirectory)
    XCTAssertTrue(FileManager.default.fileExists(atPath: firstBackup.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: secondBackup.path))
  }

  func testCleanupPlanHidesNonApplicableActions() throws {
    let root = try makeTemporaryCodexHome()
    let existingProject = root.appendingPathComponent("existing-project")
    try FileManager.default.createDirectory(
      at: existingProject,
      withIntermediateDirectories: true
    )

    try write(
      """
      [projects."\((existingProject.path))"]
      trust_level = "trusted"
      """,
      to: root.appendingPathComponent("config.toml")
    )

    let recentSession = root
      .appendingPathComponent("sessions/2026/05/04/recent.jsonl")
    try write("recent chat", to: recentSession)
    try setModifiedAt(daysAgo: 1, for: recentSession)

    let activeWorktree = root.appendingPathComponent("worktrees/active-worktree")
    try FileManager.default.createDirectory(
      at: activeWorktree,
      withIntermediateDirectories: true
    )
    try setModifiedAt(daysAgo: 1, for: activeWorktree)

    try write("small", to: root.appendingPathComponent("logs_2.sqlite"))

    let cleaner = CodexCleaner(
      codexHome: root,
      staleSessionDays: 10,
      staleWorktreeDays: 14,
      largeLogBytes: 1_024,
      codexRunningProvider: { false }
    )

    let titles = try planTitles(from: cleaner)

    XCTAssertEqual(titles, ["Nothing to clean"])
    XCTAssertFalse(titles.contains("Archive stale active chats"))
    XCTAssertFalse(titles.contains("Move stale worktrees"))
    XCTAssertFalse(titles.contains("Rotate oversized logs"))
    XCTAssertFalse(titles.contains("Prune missing config projects"))
  }

  func testCleanupPlanShowsOnlyApplicableActions() throws {
    let root = try makeTemporaryCodexHome()
    let staleSession = root
      .appendingPathComponent("sessions/2026/04/01/old.jsonl")
    try write("old chat", to: staleSession)
    try setModifiedAt(daysAgo: 20, for: staleSession)

    let cleaner = CodexCleaner(
      codexHome: root,
      staleSessionDays: 10,
      staleWorktreeDays: 14,
      largeLogBytes: 1_024,
      codexRunningProvider: { false }
    )

    let titles = try planTitles(from: cleaner)

    XCTAssertEqual(
      titles,
      [
        "Back up important Codex state",
        "Archive stale active chats",
      ]
    )
  }

  private func makeTemporaryCodexHome() throws -> URL {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CodexCleanerTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
    temporaryRoots.append(root)
    return root
  }

  private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  private func setModifiedAt(daysAgo: Int, for url: URL) throws {
    let date = Calendar.current.date(
      byAdding: .day,
      value: -daysAgo,
      to: Date()
    ) ?? Date()
    try FileManager.default.setAttributes(
      [.modificationDate: date],
      ofItemAtPath: url.path
    )
  }

  private func contents(of url: URL) throws -> [URL] {
    try FileManager.default.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: nil
    )
  }

  private func planTitles(from cleaner: CodexCleaner) throws -> [String] {
    try cleaner.scan().plan.map(\.title)
  }
}
