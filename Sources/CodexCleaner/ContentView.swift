import SwiftUI

struct ContentView: View {
  @State private var report: CleanerReport?
  @State private var result: CleanupResult?
  @State private var isWorking = false
  @State private var message = "Ready to scan ~/.codex."

  private let cleaner = CodexCleaner()

  var body: some View {
    HStack(spacing: 0) {
      AppSidebar(codexHome: report?.metrics.codexHome)

      Divider()

      VStack(spacing: 0) {
        AppToolbar(
          message: message,
          isWorking: isWorking,
          cleanupIsDisabled: cleanupIsDisabled,
          onReveal: cleaner.revealCodexHome,
          onScan: { Task { await scan() } },
          onClean: { Task { await clean() } }
        )

        Divider()

        mainContent
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
    isWorking || (report?.metrics.codexIsRunning ?? true)
  }

  private var mainContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: AppSpacing.large) {
        if let report {
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
        } else {
          EmptyScanView(message: message)
        }
      }
      .padding(AppSpacing.page)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func scan() async {
    isWorking = true
    defer { isWorking = false }

    let newReport = await Task.detached {
      CodexCleaner().scan()
    }.value

    report = newReport
    message = newReport.metrics.codexIsRunning
      ? "Codex is open, so cleanup is locked. Close Codex and relaunch this app to run it."
      : "Scan complete. One-button cleanup is ready."
  }

  private func clean() async {
    isWorking = true
    defer { isWorking = false }

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
