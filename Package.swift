// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NeuralEnginePro",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "NeuralEnginePro", targets: ["NeuralEnginePro"])
    ],
    dependencies: [
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm", from: "2.41.0")
    ],
    targets: [
        .binaryTarget(
            name: "NeuralEnginePro",
            url: "https://github.com/skynetbee/NeuralEnginePro/releases/download/1.1.2/NeuralEnginePro.xcframework.zip",
            checksum: "2432cacc7524010bd0936b1874e12dcc9f7dc8570298db0ffa3b26960b89c689"
        )
    ]
)
