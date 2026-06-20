// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "google_places_sdk_plus_ios",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "google-places-sdk-plus-ios",
            targets: ["google_places_sdk_plus_ios"]
        )
    ],
    dependencies: [
        // Google Places SDK for iOS. The `GooglePlaces` product is the
        // Objective-C wrapper API (GMSPlacesClient, GMSPlace, …) used by this
        // plugin, mirroring the CocoaPods `GooglePlaces` dependency in the
        // podspec so both build systems link the same SDK.
        .package(url: "https://github.com/googlemaps/ios-places-sdk", from: "10.1.0")
    ],
    targets: [
        .target(
            name: "google_places_sdk_plus_ios",
            dependencies: [
                .product(name: "GooglePlaces", package: "ios-places-sdk")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it
                // uses any required reason APIs, update the PrivacyInfo.xcprivacy
                // file to describe your plugin's privacy impact, and then
                // uncomment this line. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
