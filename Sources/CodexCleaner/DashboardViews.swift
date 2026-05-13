import SwiftUI

struct MetricsStrip: View {
  let metrics: CleanerMetrics

  var body: some View {
    HStack(spacing: AppSpacing.medium) {
      MetricTile("Total", value: formatBytes(metrics.totalBytes), icon: "internaldrive")
      MetricTile(
        "Active Chats",
        value: formatBytes(metrics.activeSessionBytes),
        icon: "text.bubble"
      )
      MetricTile("Logs", value: formatBytes(metrics.logBytes), icon: "doc.text")
      MetricTile(
        metrics.codexIsRunning ? "Blocked" : "Ready",
        value: metrics.codexIsRunning ? "Close Codex" : "Cleanable",
        icon: metrics.codexIsRunning ? "lock" : "checkmark.seal"
      )
    }
  }
}

struct MetricTile: View {
  let title: String
  let value: String
  let icon: String

  init(_ title: String, value: String, icon: String) {
    self.title = title
    self.value = value
    self.icon = icon
  }

  var body: some View {
    HStack(spacing: AppSpacing.medium) {
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
    .panelPadding()
    .panelBackground()
  }
}

struct CleanupPlanView: View {
  let plan: [CleanupPlanItem]

  var body: some View {
    InspectorGroup("Cleanup Plan", subtitle: "Actions prepared from the scan.") {
      VStack(spacing: 0) {
        ForEach(Array(plan.enumerated()), id: \.element.id) { index, item in
          CleanupPlanRow(item: item)
          if index < plan.count - 1 {
            Divider()
              .padding(.leading, 48)
          }
        }
      }
    }
  }
}

struct CleanupPlanRow: View {
  let item: CleanupPlanItem

  var body: some View {
    HStack(alignment: .top, spacing: AppSpacing.medium) {
      Image(systemName: item.isBlocked ? "exclamationmark.triangle.fill" : "checkmark")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(item.isBlocked ? .orange : .green)
        .frame(width: 28, height: 28)
        .background(statusColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.system(size: 13, weight: .semibold))
        Text(item.detail)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: AppSpacing.medium)

      Text(item.impact)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, AppSpacing.small)
        .padding(.vertical, 5)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
    .panelPadding()
  }

  private var statusColor: Color {
    item.isBlocked ? .orange : .green
  }
}

struct LargestFilesView: View {
  let files: [FileRecord]

  var body: some View {
    InspectorGroup("Largest Hot Files", subtitle: "Active chats and logs by size.") {
      if files.isEmpty {
        Text("No active chat or log files were found in this scan.")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .panelPadding()
      } else {
        VStack(spacing: 0) {
          ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
            FileRecordRow(file: file)
            if index < files.count - 1 {
              Divider()
                .padding(.leading, 106)
            }
          }
        }
      }
    }
  }
}

struct FileRecordRow: View {
  let file: FileRecord

  var body: some View {
    HStack(spacing: AppSpacing.medium) {
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
    .padding(.horizontal, AppSpacing.medium)
    .padding(.vertical, 9)
  }
}

struct StatusPanel: View {
  let metrics: CleanerMetrics

  var body: some View {
    InspectorGroup("Status", subtitle: "Current cleanup readiness.") {
      VStack(alignment: .leading, spacing: 14) {
        StatusLine(
          "Active sessions",
          value: "\(metrics.activeSessionCount)",
          icon: "bubble.left.and.bubble.right"
        )
        StatusLine(
          "Stale sessions",
          value: "\(metrics.staleSessionCount)",
          icon: "tray.and.arrow.down"
        )
        StatusLine(
          "Stale worktrees",
          value: "\(metrics.staleWorktreeCount)",
          icon: "point.3.connected.trianglepath.dotted"
        )
        StatusLine(
          "Oversized logs",
          value: "\(metrics.largeLogCount)",
          icon: "doc.badge.gearshape"
        )
        StatusLine(
          "Missing projects",
          value: "\(metrics.missingProjectCount)",
          icon: "folder.badge.questionmark"
        )
      }
      .padding(14)
    }
    .frame(width: 280)
  }
}

struct StatusLine: View {
  let title: String
  let value: String
  let icon: String

  init(_ title: String, value: String, icon: String) {
    self.title = title
    self.value = value
    self.icon = icon
  }

  var body: some View {
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
}

struct CleanupResultView: View {
  let result: CleanupResult

  var body: some View {
    InspectorGroup(
      "Cleanup Results",
      subtitle: "Moved \(formatBytes(result.bytesMoved)); backup: \(backupPath)."
    ) {
      VStack(alignment: .leading, spacing: AppSpacing.medium) {
        HStack(spacing: AppSpacing.small) {
          ResultPill("\(result.archivedSessions)", "Chats")
          ResultPill("\(result.archivedWorktrees)", "Worktrees")
          ResultPill("\(result.rotatedLogs)", "Logs")
          ResultPill("\(result.prunedProjects)", "Projects")
        }

        VStack(spacing: 0) {
          ComparisonRow(
            title: "Active chat size",
            before: formatBytes(result.before.metrics.activeSessionBytes),
            after: formatBytes(result.after.metrics.activeSessionBytes)
          )
          ComparisonRow(
            title: "Log size",
            before: formatBytes(result.before.metrics.logBytes),
            after: formatBytes(result.after.metrics.logBytes)
          )
          ComparisonRow(
            title: "Stale sessions",
            before: "\(result.before.metrics.staleSessionCount)",
            after: "\(result.after.metrics.staleSessionCount)"
          )
          ComparisonRow(
            title: "Stale worktrees",
            before: "\(result.before.metrics.staleWorktreeCount)",
            after: "\(result.after.metrics.staleWorktreeCount)"
          )
          ComparisonRow(
            title: "Oversized logs",
            before: "\(result.before.metrics.largeLogCount)",
            after: "\(result.after.metrics.largeLogCount)"
          )
          ComparisonRow(
            title: "Missing projects",
            before: "\(result.before.metrics.missingProjectCount)",
            after: "\(result.after.metrics.missingProjectCount)"
          )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

        ForEach(result.verificationNotes, id: \.self) { note in
          Label(note, systemImage: "checkmark.seal.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }
      .panelPadding()
    }
  }

  private var backupPath: String {
    result.backupDirectory?.path ?? "none"
  }
}

struct ComparisonRow: View {
  let title: String
  let before: String
  let after: String

  var body: some View {
    HStack(spacing: AppSpacing.medium) {
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)

      Spacer()

      Text(before)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .frame(width: 96, alignment: .trailing)
      Image(systemName: "arrow.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(after)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .frame(width: 96, alignment: .trailing)
    }
    .padding(.horizontal, AppSpacing.medium)
    .padding(.vertical, 8)
    .background(Color(nsColor: .textBackgroundColor))
  }
}

struct ResultPill: View {
  let value: String
  let label: String

  init(_ value: String, _ label: String) {
    self.value = value
    self.label = label
  }

  var body: some View {
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
}
