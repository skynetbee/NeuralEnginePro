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
            url: "https://github.com/skynetbee/NeuralEnginePro/releases/download/1.1.1/NeuralEnginePro.xcframework.zip",
            checksum: "beb6fe601133eac01fde9e58263a253e71a89e5723c3b209db573d5fa8caf299"
        )
    ]
)
