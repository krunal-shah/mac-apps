import AppKit
import Foundation

struct IconSpec {
    let filename: String
    let pixels: Int
}

let specs: [IconSpec] = [
    .init(filename: "icon_48.tiff", pixels: 48),
    .init(filename: "icon_32.tiff", pixels: 32),
    .init(filename: "icon_16.tiff", pixels: 16),
    .init(filename: "icon_128.tiff", pixels: 128),
    .init(filename: "icon_256.tiff", pixels: 256),
    .init(filename: "icon_512.tiff", pixels: 512),
    .init(filename: "icon_1024.tiff", pixels: 1024)
]

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let sourcePNGURL = resourcesURL.appendingPathComponent("AppIcon.png")
let buildURL = resourcesURL.appendingPathComponent("AppIcon.build", isDirectory: true)
let tiffURL = buildURL.appendingPathComponent("AppIcon.tiff")
let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")

guard let sourceImage = NSImage(contentsOf: sourcePNGURL) else {
    throw NSError(
        domain: "CommandShelfIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing or unreadable icon source: \(sourcePNGURL.path)"]
    )
}

func resizedTIFFData(pixels: Int) throws -> Data {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1
    )
    image.unlockFocus()

    guard let data = image.tiffRepresentation else {
        throw NSError(
            domain: "CommandShelfIcon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create \(pixels)x\(pixels) TIFF representation"]
        )
    }

    return data
}

func pngData(pixels: Int) throws -> Data {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(origin: .zero, size: size),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1
    )
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "CommandShelfIcon",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create \(pixels)x\(pixels) PNG representation"]
        )
    }

    return data
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        throw NSError(
            domain: "CommandShelfIcon",
            code: Int(process.terminationStatus),
            userInfo: [NSLocalizedDescriptionKey: "\(executable) failed with status \(process.terminationStatus)\n\(output)\(error)"]
        )
    }
}

func appendASCII(_ value: String, to data: inout Data) {
    data.append(value.data(using: .ascii)!)
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

func hasElement(_ type: String, in data: Data) -> Bool {
    guard data.count >= 8 else { return false }

    var offset = 8
    while offset + 8 <= data.count {
        let elementType = String(data: data[offset..<offset + 4], encoding: .ascii)

        var length: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &length) { buffer in
            data[offset + 4..<offset + 8].copyBytes(to: buffer)
        }
        length = UInt32(bigEndian: length)

        if elementType == type {
            return true
        }
        if length < 8 {
            return false
        }

        offset += Int(length)
    }

    return false
}

func appendIconElement(type: String, elementData: Data, to url: URL) throws {
    var file = try Data(contentsOf: url)
    guard file.count >= 8, String(data: file[0..<4], encoding: .ascii) == "icns" else {
        throw NSError(
            domain: "CommandShelfIcon",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS output"]
        )
    }

    guard !hasElement(type, in: file) else { return }

    let newLength = UInt32(file.count + 8 + elementData.count)
    var lengthBytes = Data()
    appendUInt32(newLength, to: &lengthBytes)
    file.replaceSubrange(4..<8, with: lengthBytes)

    appendASCII(type, to: &file)
    appendUInt32(UInt32(8 + elementData.count), to: &file)
    file.append(elementData)
    try file.write(to: url, options: .atomic)
}

try? FileManager.default.removeItem(at: buildURL)
try FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true)

var tiffPaths: [String] = []
for spec in specs {
    let fileURL = buildURL.appendingPathComponent(spec.filename)
    try resizedTIFFData(pixels: spec.pixels).write(to: fileURL, options: .atomic)
    tiffPaths.append(fileURL.path)
}

try run("/usr/bin/tiffutil", ["-cat"] + tiffPaths + ["-out", tiffURL.path])
try run("/usr/bin/tiff2icns", [tiffURL.path, outputURL.path])
try appendIconElement(type: "ic10", elementData: try pngData(pixels: 1024), to: outputURL)
try? FileManager.default.removeItem(at: buildURL)

print("Wrote \(outputURL.path) from \(sourcePNGURL.path)")
