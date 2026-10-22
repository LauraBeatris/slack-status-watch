// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SlackStatusKit",
  platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("26.0")],
  products: [
    .library(name: "SlackStatusKit", targets: ["SlackStatusKit"])
  ],
  targets: [
    .target(
      name: "SlackStatusKit",
      swiftSettings: [
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
      ]
    ),
    .testTarget(
      name: "SlackStatusKitTests",
      dependencies: ["SlackStatusKit"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
