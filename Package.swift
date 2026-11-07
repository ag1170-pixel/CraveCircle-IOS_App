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
            exclude: ["Assets.xcassets"],
            resources: [
                .copy("usda_sr.json"),
                .copy("ifct_2017.json"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("XTOOL_WSL"),
            ]
        ),
    ]
)
