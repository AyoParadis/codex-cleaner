import SwiftUI

struct ContentView: View {
  @State private var report: CleanerReport?
  @State private var result: CleanupResult?
  @State private var isWorking = false
  @State private var message = "Ready to scan ~/.codex."

  private let cleaner = CodexCleaner()

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.05, green: 0.06, blue: 0.07),
          Color(red: 0.12, green: 0.10, blue: 0.08),
          Color(red: 0.04, green: 0.08, blue: 0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        header

        ScrollView {
          VStack(spacing: 22) {
            if let report {
              metricsGrid(report.metrics)
              planList(report.plan)
              largestFiles(report.largestFiles)
            } else {
              emptyState
            }

            if let result {
              resultView(result)
            }
          }
          .padding(28)
        }
      }
    }
    .foregroundStyle(.white)
    .task {
      await scan()
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Codex Cleaner")
          .font(.system(size: 42, weight: .black, design: .rounded))
        Text("Archive stale chats, rotate huge logs, back up first, and keep Codex light.")
          .font(.system(size: 15, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.72))
      }

      Spacer()

      Button {
        cleaner.revealCodexHome()
      } label: {
        Label("Reveal", systemImage: "folder")
      }
      .buttonStyle(QuietButtonStyle())

      Button {
        Task { await scan() }
      } label: {
        Label("Scan", systemImage: "waveform.path.ecg")
      }
      .buttonStyle(QuietButtonStyle())
      .disabled(isWorking)

      Button {
        Task { await clean() }
      } label: {
        Label("Run Cleanup", systemImage: "sparkles")
          .frame(minWidth: 136)
      }
      .buttonStyle(PrimaryButtonStyle())
      .disabled(isWorking || (report?.metrics.codexIsRunning ?? true))
    }
    .padding(.horizontal, 28)
    .padding(.top, 26)
    .padding(.bottom, 22)
    .background(.black.opacity(0.28))
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.08))
        .frame(height: 1)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 18) {
      Image(systemName: "externaldrive.badge.icloud")
        .font(.system(size: 54, weight: .thin))
        .foregroundStyle(.teal)
      Text(message)
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.8))
    }
    .frame(maxWidth: .infinity, minHeight: 380)
  }

  private func metricsGrid(_ metrics: CleanerMetrics) -> some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
      ],
      spacing: 14
    ) {
      metric("Total", formatBytes(metrics.totalBytes), "internaldrive")
      metric("Active chats", formatBytes(metrics.activeSessionBytes), "text.bubble")
      metric("Logs", formatBytes(metrics.logBytes), "doc.text.magnifyingglass")
      metric(
        metrics.codexIsRunning ? "Blocked" : "Ready",
        metrics.codexIsRunning ? "Close Codex" : "Cleanable",
        metrics.codexIsRunning ? "lock" : "checkmark.seal"
      )
    }
  }

  private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.teal)
      VStack(alignment: .leading, spacing: 4) {
        Text(title.uppercased())
          .font(.system(size: 11, weight: .bold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.48))
        Text(value)
          .font(.system(size: 23, weight: .heavy, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.65)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(.white.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private func planList(_ plan: [CleanupPlanItem]) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle("Cleanup Plan", subtitle: message)

      VStack(spacing: 10) {
        ForEach(plan) { item in
          HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.isBlocked ? "exclamationmark.triangle" : "checkmark")
              .font(.system(size: 13, weight: .black))
              .foregroundStyle(item.isBlocked ? .orange : .teal)
              .frame(width: 28, height: 28)
              .background(.white.opacity(0.08))
              .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
              Text(item.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
              Text(item.detail)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Text(item.impact)
              .font(.system(size: 12, weight: .bold, design: .monospaced))
              .foregroundStyle(.white.opacity(0.7))
              .padding(.horizontal, 10)
              .padding(.vertical, 7)
              .background(.black.opacity(0.2))
              .clipShape(Capsule())
          }
          .padding(14)
          .background(.white.opacity(item.isBlocked ? 0.1 : 0.06))
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
      }
    }
  }

  private func largestFiles(_ files: [FileRecord]) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle("Largest Hot Files", subtitle: "Useful for spotting oversized chats and logs.")

      VStack(spacing: 8) {
        ForEach(files) { file in
          HStack(spacing: 12) {
            Text(formatBytes(file.bytes))
              .font(.system(size: 12, weight: .bold, design: .monospaced))
              .foregroundStyle(.teal)
              .frame(width: 86, alignment: .leading)
            Text(file.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
              .font(.system(size: 12, weight: .medium, design: .monospaced))
              .foregroundStyle(.white.opacity(0.68))
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(.black.opacity(0.18))
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
      }
    }
  }

  private func resultView(_ result: CleanupResult) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionTitle(
        "Last Cleanup",
        subtitle: "Moved \(formatBytes(result.bytesMoved)); backup: \(result.backupDirectory?.path ?? "none")."
      )

      HStack(spacing: 10) {
        resultPill("\(result.archivedSessions)", "Chats")
        resultPill("\(result.archivedWorktrees)", "Worktrees")
        resultPill("\(result.rotatedLogs)", "Logs")
        resultPill("\(result.prunedProjects)", "Projects")
      }

      ForEach(result.verificationNotes, id: \.self) { note in
        Label(note, systemImage: "checkmark.seal")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.72))
      }
    }
  }

  private func resultPill(_ value: String, _ label: String) -> some View {
    HStack(spacing: 7) {
      Text(value)
        .font(.system(size: 18, weight: .black, design: .rounded))
      Text(label)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.58))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(.white.opacity(0.08))
    .clipShape(Capsule())
  }

  private func sectionTitle(_ title: String, subtitle: String) -> some View {
    HStack(alignment: .lastTextBaseline) {
      Text(title)
        .font(.system(size: 22, weight: .black, design: .rounded))
      Text(subtitle)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.52))
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
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

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .black, design: .rounded))
      .foregroundStyle(.black)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .background(configuration.isPressed ? Color.teal.opacity(0.7) : Color.teal)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

struct QuietButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .bold, design: .rounded))
      .foregroundStyle(.white.opacity(configuration.isPressed ? 0.62 : 0.86))
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(.white.opacity(configuration.isPressed ? 0.05 : 0.1))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}
