// swift-tools-version:5.8
import PackageDescription

let package = Package(
  name: "AudioDeviceManager",
  platforms: [
    .macOS(.v12)
  ],
  products: [
    .library(
      name: "AudioDeviceManager",
      targets: ["AudioDeviceManager"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
  ],
  targets: [
    .target(
      name: "AudioDeviceManager",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      path: "Sources/AudioDeviceManager")
  ]
)
