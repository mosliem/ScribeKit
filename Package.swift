// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "SwiftyEditor",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    .library(
      name: "SwiftyEditor",
      targets: ["SwiftyEditor"]
    )
  ],
  targets: [
    .target(
      name: "SwiftyEditor",
      path: "Sources/SwiftyEditor"
    ),
    .testTarget(
      name: "SwiftyEditorTests",
      dependencies: ["SwiftyEditor"],
      path: "Tests/SwiftyEditorTests"
    ),
  ]
)
