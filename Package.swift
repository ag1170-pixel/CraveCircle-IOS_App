// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AICookBook",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "AICookBook", targets: ["AICookBook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.0"),
    ],
    targets: [
        .target(
            name: "AICookBook",
            dependencies: [
                .product(name: "Lottie", package: "lottie-spm"),
            ],
            path: "AICookBook",
            exclude: ["Assets.xcassets"],
            resources: [
                .copy("usda_sr.json"),
                .copy("ifct_2017.json"),
                .copy("Flow_4.json"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .define("XTOOL_WSL"),
            ]
        ),
    ]
)
