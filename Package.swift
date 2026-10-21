// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiskPulse",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "diskpulse", targets: ["DiskPulseCLI"]),
        .executable(name: "DiskPulseApp", targets: ["DiskPulseApp"]),
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
        ),
        .executableTarget(
            name: "DiskPulseApp",
            dependencies: ["DiskPulseCore"]
        ),
        .executableTarget(
            name: "DiskPulseSelfTest",
            dependencies: ["DiskPulseCore"],
            path: "Tests/DiskPulseCoreTests"
        )
    ]
)
