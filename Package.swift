// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AgentMeter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AgentMeter",
            path: "Sources/AgentMeter"
        )
    ]
)
