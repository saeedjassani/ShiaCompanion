// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "webview_flutter_wkwebview", path: "../.packages/webview_flutter_wkwebview-3.25.1"),
        .package(name: "wakelock_plus", path: "../.packages/wakelock_plus-1.5.2"),
        .package(name: "package_info_plus", path: "../.packages/package_info_plus-9.0.1"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.4.1"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "share_plus", path: "../.packages/share_plus-12.0.2"),
        .package(name: "home_widget", path: "../.packages/home_widget-0.9.1"),
        .package(name: "google_sign_in_ios", path: "../.packages/google_sign_in_ios-6.3.0"),
        .package(name: "flutter_timezone", path: "../.packages/flutter_timezone-5.0.2"),
        .package(name: "flutter_local_notifications", path: "../.packages/flutter_local_notifications-20.1.0"),
        .package(name: "firebase_database", path: "../.packages/firebase_database-12.4.1"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-4.9.0"),
        .package(name: "firebase_crashlytics", path: "../.packages/firebase_crashlytics-5.2.2"),
        .package(name: "firebase_auth", path: "../.packages/firebase_auth-6.5.1"),
        .package(name: "firebase_analytics", path: "../.packages/firebase_analytics-12.4.1"),
        .package(name: "file_picker", path: "../.packages/file_picker-11.0.2"),
        .package(name: "cloud_firestore", path: "../.packages/cloud_firestore-6.4.1"),
        .package(name: "app_links", path: "../.packages/app_links-6.4.1"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "webview-flutter-wkwebview", package: "webview_flutter_wkwebview"),
                .product(name: "wakelock-plus", package: "wakelock_plus"),
                .product(name: "package-info-plus", package: "package_info_plus"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "home-widget", package: "home_widget"),
                .product(name: "google-sign-in-ios", package: "google_sign_in_ios"),
                .product(name: "flutter-timezone", package: "flutter_timezone"),
                .product(name: "flutter-local-notifications", package: "flutter_local_notifications"),
                .product(name: "firebase-database", package: "firebase_database"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "firebase-crashlytics", package: "firebase_crashlytics"),
                .product(name: "firebase-auth", package: "firebase_auth"),
                .product(name: "firebase-analytics", package: "firebase_analytics"),
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "cloud-firestore", package: "cloud_firestore"),
                .product(name: "app-links", package: "app_links"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
