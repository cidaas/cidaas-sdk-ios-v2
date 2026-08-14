// swift-tools-version:5.7

import PackageDescription

let webAuthPlatforms: [Platform] = [.iOS]
let swiftSettings: [SwiftSetting] = [.define("WEB_AUTH_PLATFORM", .when(platforms: webAuthPlatforms))]

let package = Package(
    name: "Cidaas",
    platforms: [.iOS(.v11)],
    products: [.library(name: "Cidaas", targets: ["Cidaas"])],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.8.1")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.8.1")),
        .package(url: "https://github.com/jrendel/SwiftKeychainWrapper", .upToNextMajor(from: "4.0.1")),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "Cidaas", 
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "SwiftKeychainWrapper", package: "SwiftKeychainWrapper"),
                .product(name: "AnyCodable", package: "AnyCodable")
            ],
            path: "Cidaas/Classes",
            swiftSettings: swiftSettings)
    ]
)