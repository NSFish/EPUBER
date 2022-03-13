// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "EPUBER",
    platforms: [
    .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/NSFish/SwiftyXML.git", .branch("nsfish")),
        .package(path: "../PTSwift"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "1.7.4"),
    ],
    targets: [
        .target(
            name: "EPUBER",
            dependencies: ["PTSwift", "SwiftyXML", "SwiftSoup"]),
        .testTarget(
            name: "EPUBERTests",
            dependencies: ["EPUBER"]),
    ]
)
