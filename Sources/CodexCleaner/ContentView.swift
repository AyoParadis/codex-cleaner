import SwiftUI

struct ContentView: View {
  @State private var report: CleanerReport?
  @State private var result: CleanupResult?
  @State private var isWorking = false
  @State private var message = "Ready to scan ~/.codex."

  private let cleaner = CodexCleaner()

  var body: some View {
    HStack(spacing: 0) {
      sidebar

      Divider()

      VStack(spacing: 0) {
        toolbar
        Divider()
        content
      }
      .background(Color(nsColor: .textBackgroundColor))
    }
    .preferredColorScheme(.light)
    .tint(.blue)
    .task {
      await scan()
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "shippingbox.and.arrow.backward")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.blue)
          .frame(width: 44, height: 44)
          .background(Color.blue.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text("Codex Cleaner")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.primary)
          Text("Local Maintenance")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 24)
      .padding(.bottom, 20)

      sidebarItem(
        "Overview",
        icon: "gauge.with.dots.needle.bottom.50percent",
        isSelected: true
      )
      sidebarItem("Archives", icon: "archivebox")
      sidebarItem("Logs", icon: "doc.text.magnifyingglass")
      sidebarItem("Config", icon: "gearshape")

      Spacer()

      VStack(alignment: .leading, spacing: 8) {
        Text("Codex Home")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(report?.metrics.codexHome.path ?? "~/.codex")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .truncationMode(.middle)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(nsColor: .controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .padding(16)
    }
    .frame(width: 236)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var toolbar: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Overview")
          .font(.system(size: 24, weight: .semibold))
        Text(message)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer()

      Button {
        cleaner.revealCodexHome()
      } label: {
        Label("Reveal", systemImage: "folder")
      }
      .buttonStyle(UtilityButtonStyle())

      Button {
        Task { await scan() }
      } label: {
        Label("Scan", systemImage: "arrow.clockwise")
      }
      .buttonStyle(UtilityButtonStyle())
      .disabled(isWorking)

      Button {
        Task { await clean() }
      } label: {
        Label("Run Cleanup", systemImage: "play.fill")
      }
      .buttonStyle(PrimaryButtonStyle())
      .disabled(isWorking || (report?.metrics.codexIsRunning ?? true))
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 14)
    .background(.regularMaterial)
  }

  private var content: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let report {
          metricsStrip(report.metrics)

          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
              planList(report.plan)
              largestFiles(report.largestFiles)
            }

            statusPanel(report.metrics)
          }

          if let result {
            resultView(result)
          }
        } else {
          emptyState
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      ProgressView()
        .controlSize(.large)
      Text(message)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 420)
  }

  private func sidebarItem(
    _ title: String,
    icon: String,
    isSelected: Bool = false
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .medium))
        .frame(width: 20)
      Text(title)
        .font(.system(size: 13, weight: .medium))
      Spacer()
    }
    .foregroundStyle(isSelected ? .primary : .secondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(isSelected ? Color.blue.opacity(0.12) : .clear)
    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    .padding(.horizontal, 12)
  }

  private func metricsStrip(_ metrics: CleanerMetrics) -> some View {
    HStack(spacing: 12) {
      metric("Total", formatBytes(metrics.totalBytes), "internaldrive")
      metric("Active Chats", formatBytes(metrics.activeSessionBytes), "text.bubble")
      metric("Logs", formatBytes(metrics.logBytes), "doc.text")
      metric(
        metrics.codexIsRunning ? "Blocked" : "Ready",
        metrics.codexIsRunning ? "Close Codex" : "Cleanable",
        metrics.codexIsRunning ? "lock" : "checkmark.seal"
      )
    }
  }

  private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.blue)
        .frame(width: 30, height: 30)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(value)
          .font(.system(size: 16, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color(nsColor: .controlBackgroundColor))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color(nsColor: .separatorColor).opacity(0.45))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  private func planList(_ plan: [CleanupPlanItem]) -> some View {
    inspectorGroup("Cleanup Plan", subtitle: "Actions prepared from the scan.") {
      VStack(spacing: 0) {
        ForEach(Array(plan.enumerated()), id: \.element.id) { index, item in
          inspectorRow(item)
          if index < plan.count - 1 {
            Divider()
              .padding(.leading, 48)
          }
        }
      }
    }
  }

  private func inspectorRow(_ item: CleanupPlanItem) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: item.isBlocked ? "exclamationmark.triangle.fill" : "checkmark")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(item.isBlocked ? .orange : .green)
        .frame(width: 28, height: 28)
        .background(
          (item.isBlocked ? Color.orange : Color.green).opacity(0.12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.system(size: 13, weight: .semibold))
        Text(item.detail)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Text(item.impact)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
    .padding(12)
  }

  private func largestFiles(_ files: [FileRecord]) -> some View {
    inspectorGroup("Largest Hot Files", subtitle: "Active chats and logs by size.") {
      VStack(spacing: 0) {
        ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
          HStack(spacing: 12) {
            Text(formatBytes(file.bytes))
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundStyle(.blue)
              .frame(width: 82, alignment: .leading)

            Text(file.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)

            Spacer()
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 9)

          if index < files.count - 1 {
            Divider()
              .padding(.leading, 106)
          }
        }
      }
    }
  }

  private func statusPanel(_ metrics: CleanerMetrics) -> some View {
    inspectorGroup("Status", subtitle: "Current cleanup readiness.") {
      VStack(alignment: .leading, spacing: 14) {
        statusLine(
          "Active sessions",
          value: "\(metrics.activeSessionCount)",
          icon: "bubble.left.and.bubble.right"
        )
        statusLine(
          "Stale sessions",
          value: "\(metrics.staleSessionCount)",
          icon: "tray.and.arrow.down"
        )
        statusLine(
          "Stale worktrees",
          value: "\(metrics.staleWorktreeCount)",
          icon: "point.3.connected.trianglepath.dotted"
        )
        statusLine(
          "Oversized logs",
          value: "\(metrics.largeLogCount)",
          icon: "doc.badge.gearshape"
        )
        statusLine(
          "Missing projects",
          value: "\(metrics.missingProjectCount)",
          icon: "folder.badge.questionmark"
        )
      }
      .padding(14)
    }
    .frame(width: 280)
  }

  private func statusLine(_ title: String, value: String, icon: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 18)
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(.primary)
    }
  }

  private func resultView(_ result: CleanupResult) -> some View {
    inspectorGroup(
      "Last Cleanup",
      subtitle: "Moved \(formatBytes(result.bytesMoved)); backup: \(result.backupDirectory?.path ?? "none")."
    ) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          resultPill("\(result.archivedSessions)", "Chats")
          resultPill("\(result.archivedWorktrees)", "Worktrees")
          resultPill("\(result.rotatedLogs)", "Logs")
          resultPill("\(result.prunedProjects)", "Projects")
        }

        ForEach(result.verificationNotes, id: \.self) { note in
          Label(note, systemImage: "checkmark.seal.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }
      .padding(12)
    }
  }

  private func resultPill(_ value: String, _ label: String) -> some View {
    HStack(spacing: 6) {
      Text(value)
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
      Text(label)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 6)
    .background(Color(nsColor: .textBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }

  private func inspectorGroup<Content: View>(
    _ title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
        Text(subtitle)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .padding(12)

      Divider()

      content()
    }
    .background(Color(nsColor: .controlBackgroundColor))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color(nsColor: .separatorColor).opacity(0.45))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(configuration.isPressed ? Color.blue.opacity(0.78) : Color.blue)
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}

struct UtilityButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(
        configuration.isPressed
          ? Color(nsColor: .separatorColor).opacity(0.34)
          : Color(nsColor: .controlBackgroundColor)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Color(nsColor: .separatorColor).opacity(0.6))
      }
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}
