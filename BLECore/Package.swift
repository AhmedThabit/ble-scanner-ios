// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BLECore",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "BLECore", targets: ["BLECore"])
    ],
    targets: [
        .target(name: "BLECore"),
        .testTarget(name: "BLECoreTests", dependencies: ["BLECore"])
    ]
)
