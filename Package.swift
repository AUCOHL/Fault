// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Fault",
  platforms: [
    .macOS(.v13)  // Regex features only available in Ventura+
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    .package(
      url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.0")
    ),
    .package(url: "https://github.com/pvieito/PythonKit", from: "0.5.0"),
    .package(url: "https://github.com/donn/Defile.git", from: "5.2.1"),
    .package(url: "https://github.com/attaswift/BigInt.git", from: "5.2.1"),
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .executableTarget(
      name: "fault",
      dependencies: [
        "PythonKit", .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Defile", .product(name: "Collections", package: "swift-collections"), "BigInt",
        "Yams",
        "CThreadPool",
      ],
      path: "Sources/Fault"
    ),
    .target(
      name: "CThreadPool",
      dependencies: [],
      path: "Sources/CThreadPool",
      sources: [
        "thpool.c"
      ],
      cSettings: [
        .headerSearchPath("Sources/CThreadPool/include")
      ]
    ),
  ]
)
