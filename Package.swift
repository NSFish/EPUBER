// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "EPUBER",
    platforms: [
    .macOS(.v10_15)
    ],
    dependencies: [
//        .package(url: "https://github.com/NSFish/SwiftyXML", from: "3.0.2"),
        .package(path: "../SwiftyXML"),
        .package(path: "../PTSwift")
    ],
    targets: [
        .target(
            name: "EPUBER",
            dependencies: ["PTSwift", "SwiftyXML"]),
        .testTarget(
            name: "EPUBERTests",
            dependencies: ["EPUBER"]),
    ]
)
