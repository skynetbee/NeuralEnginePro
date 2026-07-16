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
            url: "https://github.com/skynetbee/NeuralEnginePro/releases/download/1.0.0/NeuralEnginePro.xcframework.zip",
            checksum: "fbf9f4dd489255f4a7f26e6e99152f268a7875fde819a2913a81ae8e9bec2ca5"
        )
    ]
)
