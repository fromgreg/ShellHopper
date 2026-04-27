// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShellHopper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ShellHopper",
            path: "Sources/ShellHopper"
        )
    ]
)
