// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "EPUBER",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
//        .package(url: "https://github.com/NSFish/SwiftyXML.git", .branch("nsfish")),
        .package(path: "../SwiftyXML"),
        .package(path: "../PTSwift"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "1.7.4"),
    ],
    targets: [
        .executableTarget(
            name: "EPUBER",
            dependencies: ["PTSwift", "SwiftyXML", "SwiftSoup"]),
        .testTarget(
            name: "EPUBERTests",
            dependencies: ["EPUBER"]),
    ]
)
