// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CodexCleaner",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "codex-cleaner", targets: ["CodexCleaner"])
  ],
  targets: [
    .executableTarget(
      name: "CodexCleaner",
      path: "Sources/CodexCleaner"
    )
  ]
)
