// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IRIS-I",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "IRIS_ICore",
            targets: ["IRIS_ICore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "IRIS_ICore",
            dependencies: [],
            path: "IRIS-I",
            exclude: ["Resources", "App"],
            cSettings: [
                .headerSearchPath("Bridge")
            ]
        ),
        .testTarget(
            name: "IRIS_ITests",
            dependencies: ["IRIS_ICore"],
            path: "Tests/IRIS_ITests"
        )
    ]
)
