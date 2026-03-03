// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "better-cmux",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "better-cmux", targets: ["BetterCmuxApp"])
  ],
  dependencies: [
    .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
  ],
  targets: [
    .executableTarget(
      name: "BetterCmuxApp",
      dependencies: ["SwiftTerm"]
    ),
    .testTarget(
      name: "BetterCmuxAppTests",
      dependencies: ["BetterCmuxApp"]
    ),
  ]
)
