// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FullCopyMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "FullCopy", targets: ["FullCopy"])
    ],
    targets: [
        .executableTarget(
            name: "FullCopy",
            path: "Sources/FullCopy",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
