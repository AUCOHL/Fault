// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Fault",
    platforms: [
        .macOS(.v10_13) // executableURL and a bunch of other things are not available before High Sierra
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/lukaskubanek/OrderedDictionary.git", from: "3.0.1"),
        .package(url: "https://github.com/pvieito/PythonKit", .branch("master")),
        .package(url: "https://github.com/pvieito/CommandLineKit", .branch("master")),
        .package(url: "https://github.com/donn/Defile.git", from: "5.2.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Fault",
            dependencies: ["PythonKit", "CommandLineKit", "Defile", "OrderedDictionary", "BigInt"],
            path: "Sources"
        ),
        .testTarget(
            name: "FaultTests",
            dependencies: ["Fault"]
        )
    ]
)
