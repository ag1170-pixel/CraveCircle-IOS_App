// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AICookBook",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AICookBook", targets: ["AICookBook"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AICookBook",
            dependencies: [],
            path: "AICookBook",
            exclude: ["Resources/Assets.xcassets"],
            resources: [
                .copy("Resources/usda_sr.json"),
                .copy("Resources/ifct_2017.json"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("XTOOL_WSL"),
            ]
        ),
    ]
)
