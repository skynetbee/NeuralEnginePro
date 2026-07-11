// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NeuralEnginePro”,
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "NeuralEnginePro", targets: ["NeuralEnginePro"])
    ],
    targets: [
        .binaryTarget(
            name: "NeuralEnginePro",
            url: “https://github.com/skynetbee/NeuralEnginePro.git”,
            checksum: "f7f8e2c756a214b7aa682e15a77e144a69dc2364bcfc4b7838c5a622ff0bce89"
        )
    ]
)

