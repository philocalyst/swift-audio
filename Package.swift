// swift-tools-version:5.8
import PackageDescription

let package = Package(
  name: "SwiftAudio",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .library(
      name: "SwiftAudio",
      targets: ["SwiftAudio"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
  ],
  targets: [
    .target(
      name: "SwiftAudio",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "SwiftAudio",
    )
  ]
)
