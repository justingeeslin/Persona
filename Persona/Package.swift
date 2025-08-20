// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Persona",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Persona", targets: ["Persona"]),
    ],
    targets: [
        .executableTarget(
            name: "Persona",
            path: "Sources/Persona"
        ),
        .testTarget(
            name: "PersonaTests",
            dependencies: ["Persona"],
            path: "Tests/PersonaTests"
        ),
    ]
)