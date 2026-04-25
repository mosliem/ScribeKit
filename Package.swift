// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ScribeKit",
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
      path: "Sources/ScribeKit"
    ),
    .testTarget(
      name: "ScribeKitTests",
      dependencies: ["ScribeKit"],
      path: "Tests/ScribeKitTests"
    ),
  ]
)
