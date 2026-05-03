// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "catalog-tools",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "4.5.0"
        ),
    ],
    targets: [
        // Shared library — models, validation logic, loaders
        .target(
            name: "CatalogKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),

        // catalog-validate: schema validation on every PR
        .executableTarget(
            name: "catalog-validate",
            dependencies: [
                "CatalogKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // catalog-build: assemble canonical snapshot (implemented in M2)
        .executableTarget(
            name: "catalog-build",
            dependencies: [
                "CatalogKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // catalog-sign: Ed25519 sign/verify/keygen (implemented in M2)
        .executableTarget(
            name: "catalog-sign",
            dependencies: [
                "CatalogKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // catalog-publish: GitHub Releases via gh CLI (implemented in M3)
        .executableTarget(
            name: "catalog-publish",
            dependencies: [
                "CatalogKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // Unit tests (Swift Testing)
        .testTarget(
            name: "CatalogKitTests",
            dependencies: ["CatalogKit"]
        ),
    ]
)
