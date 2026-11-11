// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PetaCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PetaCore", targets: ["PetaCore"]),
    ],
    targets: [
        .target(name: "PetaCore"),
        .testTarget(name: "PetaCoreTests", dependencies: ["PetaCore"]),
    ]
)
