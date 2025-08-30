// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Persona",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Library product so other apps can import Persona
        .library(name: "Persona", targets: ["Persona"]),
    ],
    targets: [
        // Library target (module name = "Persona")
        .target(
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