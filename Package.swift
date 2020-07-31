// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "TFFPublishers",
  platforms: [.macOS(.v10_15), .iOS(.v13), .watchOS(.v6)],
  products: [
    .library(name: "TFFPublishers", targets: ["TFFPublishers"]),
  ],
  dependencies: [
    .package(url: "https://github.com/glessard/CurrentQoS", from: "1.2.0"),
  ],
  targets: [
    .target(
      name: "TFFPublishers",
      dependencies: ["CurrentQoS"]),
    .testTarget(
      name: "TFFPublishersTests",
      dependencies: ["TFFPublishers"]),
  ]
)
