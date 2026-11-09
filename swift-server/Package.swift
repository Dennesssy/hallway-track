// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IaiPerk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "iaiperk", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources/App",
            sources: ["App.swift", "routes.swift", "Seeds.swift",
                      "AuthService.swift", "EventService.swift", "Security.swift", "Models"]
        )
    ]
)
