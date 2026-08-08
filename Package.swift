// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SingilanDomain",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SingilanDomain", targets: ["SingilanDomain"])],
    targets: [
        .target(
            name: "SingilanDomain",
            path: "Singilan-App",
            exclude: ["Assets.xcassets", "Design", "Features", "Networking", "PrivacyInfo.xcprivacy", "Services", "Singilan_AppApp.swift"],
            sources: ["Models", "Domain", "Repositories"]
        ),
        .testTarget(
            name: "SingilanDomainTests",
            dependencies: ["SingilanDomain"],
            path: "SingilanDomainTests"
        )
    ]
)
