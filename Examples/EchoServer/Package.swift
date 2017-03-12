import PackageDescription

let package = Package(
    name: "EchoServer",
    dependencies: [
        .Package(url: "https://github.com/szktty/parcel.git", majorVersion: 0),
    ]
)
