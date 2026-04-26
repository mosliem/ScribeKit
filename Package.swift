// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ScribeKit",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v18)
  ],
  products: [
    .library(
      name: "ScribeKit",
      targets: ["ScribeKit"]
    )
  ],
  targets: [
    .target(
      name: "ScribeKit",
      path: "Sources/ScribeKit",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "ScribeKitTests",
      dependencies: ["ScribeKit"],
      path: "Tests/ScribeKitTests"
    ),
  ]
)
