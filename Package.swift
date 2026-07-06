// swift-tools-version: 6.0
//
// Chronicle — a privacy-first activity journal for macOS.
//
// Architecture: Clean Architecture with dependencies pointing inward.
//   Kernel        -> ChronicleModels, ChronicleCore        (no external deps)
//   Infrastructure-> ChronicleStorage, ChronicleConfig, ChronicleLogging
//   Domain        -> ChroniclePipeline, ChronicleCollectors, ChronicleQuery,
//                    ChronicleAI, ChronicleIPC
//   Application   -> ChronicleDaemon, ChronicleCLI  (+ executables)
//
// Concrete types meet only in the executable composition roots
// (Sources/chronicle, Sources/chronicled). No DI framework is used.

import PackageDescription

let strictConcurrency: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
]

let package = Package(
    name: "Chronicle",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "chronicle", targets: ["chronicle"]),
        .executable(name: "chronicled", targets: ["chronicled"]),
        .library(name: "ChronicleModels", targets: ["ChronicleModels"]),
        .library(name: "ChronicleCore", targets: ["ChronicleCore"]),
        .library(name: "ChronicleLogging", targets: ["ChronicleLogging"]),
        .library(name: "ChronicleConfig", targets: ["ChronicleConfig"]),
        .library(name: "ChronicleStorage", targets: ["ChronicleStorage"]),
        .library(name: "ChroniclePipeline", targets: ["ChroniclePipeline"]),
        .library(name: "ChronicleCollectors", targets: ["ChronicleCollectors"]),
        .library(name: "ChronicleIPC", targets: ["ChronicleIPC"]),
        .library(name: "ChronicleDaemon", targets: ["ChronicleDaemon"]),
        .library(name: "ChronicleQuery", targets: ["ChronicleQuery"]),
        .library(name: "ChronicleAI", targets: ["ChronicleAI"]),
        .library(name: "ChronicleCLI", targets: ["ChronicleCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: package_targets()
)

// MARK: - Target definitions

func package_targets() -> [Target] {
    let common = strictConcurrency

    return [
        // Kernel
        .target(
            name: "ChronicleModels",
            swiftSettings: common
        ),
        .target(
            name: "ChronicleCore",
            dependencies: ["ChronicleModels"],
            swiftSettings: common
        ),

        // Infrastructure
        .target(
            name: "ChronicleLogging",
            dependencies: [
                "ChronicleCore",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleConfig",
            dependencies: [
                "ChronicleCore",
                .product(name: "TOMLKit", package: "TOMLKit"),
            ],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleStorage",
            dependencies: [
                "ChronicleCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            swiftSettings: common
        ),

        // Domain services
        .target(
            name: "ChroniclePipeline",
            dependencies: ["ChronicleCore", "ChronicleLogging"],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleCollectors",
            dependencies: ["ChronicleCore", "ChronicleConfig", "ChronicleLogging"],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleIPC",
            dependencies: ["ChronicleCore"],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleQuery",
            dependencies: ["ChronicleCore", "ChronicleStorage"],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleAI",
            dependencies: ["ChronicleCore", "ChronicleStorage"],
            swiftSettings: common
        ),

        // Application
        .target(
            name: "ChronicleDaemon",
            dependencies: [
                "ChronicleModels",
                "ChronicleCore",
                "ChronicleLogging",
                "ChronicleConfig",
                "ChronicleStorage",
                "ChroniclePipeline",
                "ChronicleCollectors",
                "ChronicleIPC",
            ],
            swiftSettings: common
        ),
        .target(
            name: "ChronicleCLI",
            dependencies: [
                "ChronicleCore",
                "ChronicleConfig",
                "ChronicleStorage",
                "ChronicleQuery",
                "ChronicleAI",
                "ChronicleIPC",
                "ChronicleLogging",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: common
        ),

        // Test support
        .target(
            name: "ChronicleTestSupport",
            dependencies: ["ChronicleCore", "ChronicleModels"],
            swiftSettings: common
        ),

        // Executables (composition roots)
        .executableTarget(
            name: "chronicle",
            dependencies: ["ChronicleCLI"],
            swiftSettings: common
        ),
        .executableTarget(
            name: "chronicled",
            dependencies: [
                "ChronicleDaemon",
                "ChronicleLogging",
                "ChronicleConfig",
                "ChronicleStorage",
                "ChronicleCore",
            ],
            swiftSettings: common
        ),
        .executableTarget(
            name: "chronicle-bench",
            dependencies: ["ChronicleStorage", "ChroniclePipeline", "ChronicleQuery"],
            path: "Benchmarks",
            swiftSettings: common
        ),

        // Test targets
        .testTarget(
            name: "ChronicleModelsTests",
            dependencies: ["ChronicleModels", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleCoreTests",
            dependencies: ["ChronicleCore", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleLoggingTests",
            dependencies: ["ChronicleLogging", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleConfigTests",
            dependencies: ["ChronicleConfig", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleStorageTests",
            dependencies: ["ChronicleStorage", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChroniclePipelineTests",
            dependencies: ["ChroniclePipeline", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleCollectorsTests",
            dependencies: ["ChronicleCollectors", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleIPCTests",
            dependencies: ["ChronicleIPC", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleQueryTests",
            dependencies: ["ChronicleQuery", "ChronicleStorage", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleAITests",
            dependencies: ["ChronicleAI", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleCLITests",
            dependencies: [
                "ChronicleCLI",
                "ChronicleTestSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            swiftSettings: common
        ),
        .testTarget(
            name: "ChronicleDaemonTests",
            dependencies: ["ChronicleDaemon", "ChronicleTestSupport"],
            swiftSettings: common
        ),
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "ChronicleModels",
                "ChronicleCore",
                "ChronicleConfig",
                "ChronicleDaemon",
                "ChronicleStorage",
                "ChronicleQuery",
                "ChronicleIPC",
                "ChronicleTestSupport",
            ],
            swiftSettings: common
        ),
    ]
}
