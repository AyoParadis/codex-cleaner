import SwiftUI

struct ContentView: View {
  @State private var report = CleanerReport.placeholder
  @State private var result: CleanupResult?
  @State private var scanState = ScanState.idle
  @State private var isCleaning = false
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
          cleanupIsDisabled: cleanupIsDisabled,
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

  private func mainContent(_ report: CleanerReport) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSpacing.large) {
        if case .failed(let errorMessage) = scanState {
          ErrorBanner(message: errorMessage)
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
    scanState = .scanning
    message = "Scanning ~/.codex..."

    do {
      let newReport = try await Task.detached {
        try CodexCleaner().scan()
      }.value

      report = newReport
      scanState = .idle
      message = newReport.metrics.codexIsRunning
        ? "Codex is open, so cleanup is locked. Close Codex and relaunch this app to run it."
        : "Scan complete. One-button cleanup is ready."
    } catch {
      scanState = .failed(error.localizedDescription)
      message = "Scan failed."
    }
  }

  private func clean() async {
    isCleaning = true
    defer { isCleaning = false }

    do {
      let cleanup = try await Task.detached {
        try CodexCleaner().clean()
      }.value
      result = cleanup
      message = "Cleanup complete. Codex has less active history to carry."
      await scan()
    } catch {
      message = error.localizedDescription
    }
  }
}
