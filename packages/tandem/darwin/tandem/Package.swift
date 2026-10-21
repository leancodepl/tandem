// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "tandem",
  platforms: [.iOS(.v13), .macOS(.v10_15)],
  products: [.library(name: "tandem", targets: ["tandem"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [.target(name: "tandem", dependencies: [
    .product(name: "FlutterFramework", package: "FlutterFramework")
  ])]
)
