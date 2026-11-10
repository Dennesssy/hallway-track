// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "hallway-track",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "hallway-track", targets: ["App"]),
        .executable(name: "hallway-index", targets: ["Indexer"]),
        .library(name: "HallwayCore", targets: ["HallwayCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.101.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.35.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.36.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "2.8.0"),
        .package(url: "https://github.com/swift-otel/swift-otel.git", from: "1.0.0", traits: ["OTLPHTTP"]),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "HallwayCore",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "NIOHTTPCompression", package: "swift-nio-extras"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "Tracing", package: "swift-distributed-tracing"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ]
        ),
        .executableTarget(
            name: "App",
            dependencies: [
                "HallwayCore",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle")
            ],
            path: "Sources/App"
        ),
        .executableTarget(
            name: "Indexer",
            dependencies: [
                "HallwayCore",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/Indexer"
        ),
        .testTarget(
            name: "HallwayTests",
            dependencies: [
                "HallwayCore",
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOEmbedded", package: "swift-nio")
            ],
            path: "Tests"
        )
    ]
    ,
    swiftLanguageModes: [.v5]
)
