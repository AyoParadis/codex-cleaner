import SwiftUI

struct ContentView: View {
  @State private var report = CleanerReport.placeholder
  @State private var result: CleanupResult?
  @State private var scanState = ScanState.idle
  @State private var scanProgress = ScanProgress.idle
  @State private var isCleaning = false
  @State private var cleanupError: String?
  @State private var message = "Ready to scan ~/.codex."

  private let cleaner = CodexCleaner()

  var body: some View {
    HStack(spacing: 0) {
      AppSidebar(codexHome: report.metrics.codexHome)

      Divider()

      VStack(spacing: 0) {
        AppToolbar(
          message: message,
          isScanning: scanState == .scanning,
          progress: scanProgress,
          cleanupIsDisabled: cleanupIsDisabled,
          cleanupDisabledReason: cleanupDisabledReason,
          onReveal: cleaner.revealCodexHome,
          onScan: { Task { await scan() } },
          onClean: { Task { await clean() } }
        )

        Divider()

        mainContent(report)
      }
      .background(Color(nsColor: .textBackgroundColor))
    }
    .preferredColorScheme(.light)
    .tint(.blue)
    .task {
      await scan()
    }
  }

  private var cleanupIsDisabled: Bool {
    isCleaning || scanState == .scanning || report.metrics.codexIsRunning
  }

  private var cleanupDisabledReason: String? {
    if isCleaning {
      return "Cleanup is already running."
    }
    if scanState == .scanning {
      return "Wait for the scan to finish before running cleanup."
    }
    if report.metrics.codexIsRunning {
      return "Close Codex before cleanup so local databases are not touched from two places."
    }
    return nil
  }

  private func mainContent(_ report: CleanerReport) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSpacing.large) {
        if report.metrics.codexIsRunning {
          CleanupBlockedView(message: cleanupDisabledReason ?? "Cleanup is locked.")
        }

        if case .failed(let errorMessage) = scanState {
          ErrorStateView(
            title: "Scan Failed",
            message: errorMessage,
            actionTitle: "Try Again",
            action: { Task { await scan() } }
          )
        }

        if scanState == .scanning {
          ProgressPanel(progress: scanProgress)
        }

        if let cleanupError {
          ErrorStateView(
            title: "Cleanup Did Not Run",
            message: cleanupError,
            actionTitle: "Scan Again",
            action: { Task { await scan() } }
          )
        }

        MetricsStrip(metrics: report.metrics)

        HStack(alignment: .top, spacing: AppSpacing.large) {
          VStack(alignment: .leading, spacing: AppSpacing.large) {
            CleanupPlanView(plan: report.plan)
            LargestFilesView(files: report.largestFiles)
          }

          StatusPanel(metrics: report.metrics)
        }

        if let result {
          CleanupResultView(result: result)
        }
      }
      .padding(AppSpacing.page)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func scan() async {
    guard scanState != .scanning else { return }

    scanState = .scanning
    scanProgress = ScanProgress(
      title: "Preparing scan",
      detail: "Checking that the Codex home folder exists.",
      fraction: 0.12
    )
    message = "Scanning ~/.codex..."

    do {
      try await pauseForVisibleProgress()
      scanProgress = ScanProgress(
        title: "Reading local state",
        detail: "Counting sessions, archived chats, logs, and worktrees.",
        fraction: 0.38
      )

      let newReport = try await Task.detached {
        try CodexCleaner().scan()
      }.value

      cleanupError = nil
      scanProgress = ScanProgress(
        title: "Preparing report",
        detail: "Building cleanup plan and readiness checks.",
        fraction: 0.82
      )
      try await pauseForVisibleProgress()

      report = newReport
      scanState = .idle
      scanProgress = ScanProgress(
        title: "Scan complete",
        detail: "Cleanup report is ready.",
        fraction: 1
      )
      message = newReport.metrics.codexIsRunning
        ? "Cleanup locked. Close Codex to continue."
        : "Scan complete. One-button cleanup is ready."
    } catch {
      scanState = .failed(error.localizedDescription)
      scanProgress = ScanProgress(
        title: "Scan failed",
        detail: error.localizedDescription,
        fraction: 1
      )
      message = "Scan failed."
    }
  }

  private func clean() async {
    if let cleanupDisabledReason {
      cleanupError = cleanupDisabledReason
      message = "Cleanup locked. Close Codex to continue."
      return
    }

    isCleaning = true
    defer { isCleaning = false }
    cleanupError = nil
    message = "Running cleanup..."

    do {
      let cleanup = try await Task.detached {
        try CodexCleaner().clean()
      }.value
      result = cleanup
      message = "Cleanup complete. Codex has less active history to carry."
      await scan()
    } catch {
      cleanupError = error.localizedDescription
      message = error.localizedDescription
    }
  }

  private func pauseForVisibleProgress() async throws {
    try await Task.sleep(for: .milliseconds(180))
  }
}
