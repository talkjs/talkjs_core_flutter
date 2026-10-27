// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "talkjs_core_flutter",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "talkjs-core-flutter", targets: ["talkjs_core_flutter"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
    .package(url: "https://github.com/talkjs/talkjs-core-swift.git", from: "0.0.4"),
  ],
  targets: [
    .target(
      name: "talkjs_core_flutter",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
        .product(name: "talkjs-core-swift", package: "talkjs-core-swift"),
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)
