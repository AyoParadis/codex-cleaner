import SwiftUI

enum AppSpacing {
  static let page: CGFloat = 24
  static let large: CGFloat = 18
  static let medium: CGFloat = 12
  static let small: CGFloat = 8
}

struct AppSidebar: View {
  let codexHome: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      brand

      SidebarItem(
        "Overview",
        icon: "gauge.with.dots.needle.bottom.50percent",
        isSelected: true
      )
      SidebarItem("Archives", icon: "archivebox")
      SidebarItem("Logs", icon: "doc.text.magnifyingglass")
      SidebarItem("Config", icon: "gearshape")

      Spacer()

      codexHomeCard
    }
    .frame(width: 236)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var brand: some View {
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
  }

  private var codexHomeCard: some View {
    VStack(alignment: .leading, spacing: AppSpacing.small) {
      Text("Codex Home")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
      Text(codexHome?.path ?? "~/.codex")
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
}

struct AppToolbar: View {
  let message: String
  let isScanning: Bool
  let progress: ScanProgress
  let cleanupIsDisabled: Bool
  let cleanupDisabledReason: String?
  let onReveal: () -> Void
  let onScan: () -> Void
  let onClean: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Overview")
          .font(.system(size: 24, weight: .semibold))
        Text(message)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
        ProgressView(value: isScanning ? progress.fraction : 0)
          .progressViewStyle(.linear)
          .frame(width: 260, height: 4)
          .opacity(isScanning ? 1 : 0)
      }
      .frame(height: 62, alignment: .center)

      Spacer()

      Button(action: onReveal) {
        Label("Reveal", systemImage: "folder")
          .frame(width: 92)
      }
      .buttonStyle(UtilityButtonStyle())

      Button(action: onScan) {
        Label(isScanning ? "Scanning" : "Scan", systemImage: "arrow.clockwise")
          .frame(width: 92)
      }
      .buttonStyle(UtilityButtonStyle())
      .disabled(isScanning)

      Button(action: onClean) {
        Label(cleanupButtonTitle, systemImage: cleanupButtonIcon)
          .frame(width: 142)
      }
      .buttonStyle(PrimaryButtonStyle())
      .disabled(cleanupIsDisabled)
      .help(cleanupDisabledReason ?? "Run Codex cleanup")
    }
    .padding(.horizontal, AppSpacing.page)
    .frame(height: 94)
    .background(.regularMaterial)
  }

  private var cleanupButtonTitle: String {
    if cleanupIsDisabled, cleanupDisabledReason != nil, !isScanning {
      return "Cleanup Locked"
    }
    return "Run Cleanup"
  }

  private var cleanupButtonIcon: String {
    if cleanupIsDisabled, cleanupDisabledReason != nil, !isScanning {
      return "lock.fill"
    }
    return "play.fill"
  }
}

struct SidebarItem: View {
  let title: String
  let icon: String
  let isSelected: Bool

  init(_ title: String, icon: String, isSelected: Bool = false) {
    self.title = title
    self.icon = icon
    self.isSelected = isSelected
  }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .medium))
        .frame(width: 20)
      Text(title)
        .font(.system(size: 13, weight: .medium))
      Spacer()
    }
    .foregroundStyle(isSelected ? .primary : .secondary)
    .padding(.horizontal, AppSpacing.medium)
    .padding(.vertical, AppSpacing.small)
    .background(isSelected ? Color.blue.opacity(0.12) : .clear)
    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    .padding(.horizontal, AppSpacing.medium)
  }
}

struct EmptyScanView: View {
  let message: String

  var body: some View {
    VStack(spacing: 14) {
      ProgressView()
        .controlSize(.large)
      Text(message)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 420)
  }
}

struct ActionStatusPanel: View {
  let title: String
  let message: String
  let icon: String
  let tint: Color
  let progress: Double?
  let actionTitle: String?
  let action: (() -> Void)?

  var body: some View {
    HStack(alignment: .top, spacing: AppSpacing.medium) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(tint)
        .frame(width: 34, height: 34)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

      VStack(alignment: .leading, spacing: 7) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
        Text(message)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)

        ProgressView(value: progress ?? 0)
          .progressViewStyle(.linear)
          .frame(maxWidth: 360)
          .opacity(progress == nil ? 0 : 1)
      }

      Spacer()

      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .buttonStyle(UtilityButtonStyle())
          .frame(width: 112)
      } else {
        Color.clear
          .frame(width: 112, height: 1)
      }
    }
    .padding(AppSpacing.medium)
    .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .leading)
    .background(tint.opacity(0.06))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(tint.opacity(0.18))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}

struct CleanupBlockedView: View {
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: AppSpacing.medium) {
      Image(systemName: "lock.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.orange)
        .frame(width: 34, height: 34)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text("Cleanup Locked")
          .font(.system(size: 14, weight: .semibold))
        Text(message)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
        Text("Quit the Codex desktop app, reopen Codex Cleaner from Applications, then run cleanup.")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(AppSpacing.medium)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.07))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.orange.opacity(0.2))
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }
}
