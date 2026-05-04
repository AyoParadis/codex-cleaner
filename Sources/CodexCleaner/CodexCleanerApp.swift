import SwiftUI

@main
struct CodexCleanerApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .frame(minWidth: 980, minHeight: 680)
    }
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}
