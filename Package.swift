// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskPulse",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "diskpulse", targets: ["DiskPulseCLI"]),
        .library(name: "DiskPulseCore", targets: ["DiskPulseCore"])
    ],
    targets: [
        .target(
            name: "DiskPulseCore",
            dependencies: []
        ),
        .executableTarget(
            name: "DiskPulseCLI",
            dependencies: ["DiskPulseCore"]
        )
    ]
)
