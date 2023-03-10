// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BPBleOTA",
    platforms: [.iOS(.v9)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BPBleOTA",
            targets: ["BPBleOTA"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/zhxf2012/IOS-nRF-Connect-Device-Manager.git",
                 branch:"master"
                ),
        
        .package(
            url: "https://github.com/NordicSemiconductor/IOS-DFU-Library",exact:"4.13.0"
                     )
        
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BPBleOTA",
            dependencies: [
                //"iOSMcuManagerLibrary",
                //"NordicDFU"
               .product(name: "iOSMcuManagerLibrary", package: "IOS-nRF-Connect-Device-Manager"),
               .product(name: "NordicDFU", package: "IOS-DFU-Library"),
            ],
            path: "Sources"//,
           // exclude:["Info.plist"]
        ),
        .testTarget(
            name: "BPBleOTATests",
            dependencies: ["BPBleOTA"]),
    ]
)
