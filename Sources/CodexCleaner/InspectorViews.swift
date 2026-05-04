import SwiftUI

struct InspectorGroup<Content: View>: View {
  let title: String
  let subtitle: String
  let content: Content

  init(
    _ title: String,
    subtitle: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.content = content()
  }

  var body: some View {
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
      .padding(AppSpacing.medium)

      Divider()

      content
    }
    .panelBackground()
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, AppSpacing.medium)
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
      .background(background(configuration))
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Color(nsColor: .separatorColor).opacity(0.6))
      }
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }

  private func background(_ configuration: Configuration) -> Color {
    if configuration.isPressed {
      return Color(nsColor: .separatorColor).opacity(0.34)
    }
    return Color(nsColor: .controlBackgroundColor)
  }
}

extension View {
  func panelBackground() -> some View {
    background(Color(nsColor: .controlBackgroundColor))
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(Color(nsColor: .separatorColor).opacity(0.45))
      }
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  func panelPadding() -> some View {
    padding(AppSpacing.medium)
  }
}
