import PackageDescription

let package = Package(
    name: "Parcel",
    dependencies: [
        .Package(url: "https://github.com/vapor/socks.git", majorVersion: 1),
        .Package(url: "https://github.com/antitypical/Result.git", majorVersion: 3),
        .Package(url: "https://github.com/Thomvis/BrightFutures.git", majorVersion: 5),
    ]
)
