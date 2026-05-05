import AppKit
import Foundation

struct IconSpec {
    let name: String
    let pixels: Int
}

let specs: [IconSpec] = [
    .init(name: "icon_48.tiff", pixels: 48),
    .init(name: "icon_32.tiff", pixels: 32),
    .init(name: "icon_16.tiff", pixels: 16),
    .init(name: "icon_128.tiff", pixels: 128),
    .init(name: "icon_256.tiff", pixels: 256),
    .init(name: "icon_512.tiff", pixels: 512),
    .init(name: "icon_1024.tiff", pixels: 1024)
]

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let buildURL = resourcesURL.appendingPathComponent("AppIcon.build", isDirectory: true)
let tiffURL = buildURL.appendingPathComponent("AppIcon.tiff")
let pngURL = resourcesURL.appendingPathComponent("AppIcon.png")
let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

func shadow(color: NSColor, blur: CGFloat, offset: NSSize) -> NSShadow {
    let value = NSShadow()
    value.shadowColor = color
    value.shadowBlurRadius = blur
    value.shadowOffset = offset
    return value
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ path: NSBezierPath, color: NSColor, shadow: NSShadow? = nil) {
    NSGraphicsContext.saveGraphicsState()
    shadow?.set()
    color.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}

func fill(_ path: NSBezierPath, gradient: NSGradient, bounds: NSRect, angle: CGFloat, shadow: NSShadow? = nil) {
    NSGraphicsContext.saveGraphicsState()
    shadow?.set()
    path.addClip()
    gradient.draw(in: bounds, angle: angle)
    NSGraphicsContext.restoreGraphicsState()
}

func stroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func bandPath(
    pixels: CGFloat,
    topLeft: CGFloat,
    topRight: CGFloat,
    bottomLeft: CGFloat,
    bottomRight: CGFloat
) -> NSBezierPath {
    let left = -pixels * 0.10
    let right = pixels * 1.10

    let path = NSBezierPath()
    path.move(to: NSPoint(x: left, y: topLeft))
    path.curve(
        to: NSPoint(x: right, y: topRight),
        controlPoint1: NSPoint(x: pixels * 0.24, y: topLeft + pixels * 0.038),
        controlPoint2: NSPoint(x: pixels * 0.69, y: topRight - pixels * 0.070)
    )
    path.line(to: NSPoint(x: right, y: bottomRight))
    path.curve(
        to: NSPoint(x: left, y: bottomLeft),
        controlPoint1: NSPoint(x: pixels * 0.70, y: bottomRight - pixels * 0.060),
        controlPoint2: NSPoint(x: pixels * 0.24, y: bottomLeft + pixels * 0.035)
    )
    path.close()
    return path
}

func bandTopPath(pixels: CGFloat, topLeft: CGFloat, topRight: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: -pixels * 0.08, y: topLeft))
    path.curve(
        to: NSPoint(x: pixels * 1.08, y: topRight),
        controlPoint1: NSPoint(x: pixels * 0.24, y: topLeft + pixels * 0.038),
        controlPoint2: NSPoint(x: pixels * 0.69, y: topRight - pixels * 0.070)
    )
    return path
}

func drawBackground(bounds: NSRect, iconRect: NSRect, radius: CGFloat, pixels: CGFloat) {
    let basePath = roundedRect(iconRect, radius: radius)

    fill(
        basePath,
        color: color(0x05040b, alpha: 0.30),
        shadow: shadow(
            color: color(0x000000, alpha: 0.42),
            blur: pixels * 0.070,
            offset: NSSize(width: 0, height: -pixels * 0.020)
        )
    )

    fill(
        basePath,
        gradient: NSGradient(colors: [
            color(0x17142e),
            color(0x2b1e5c),
            color(0x4b2c85)
        ])!,
        bounds: iconRect,
        angle: -90
    )

    NSGraphicsContext.saveGraphicsState()
    basePath.addClip()

    NSGradient(colors: [
        color(0xa998ff, alpha: 0.14),
        color(0xa998ff, alpha: 0.00)
    ])?.draw(
        fromCenter: NSPoint(x: iconRect.midX, y: iconRect.maxY - pixels * 0.05),
        radius: 0,
        toCenter: NSPoint(x: iconRect.midX, y: iconRect.maxY - pixels * 0.05),
        radius: pixels * 0.70,
        options: []
    )

    NSGradient(colors: [
        color(0x7d66d8, alpha: 0.17),
        color(0x7d66d8, alpha: 0.00)
    ])?.draw(
        fromCenter: NSPoint(x: iconRect.maxX - pixels * 0.14, y: iconRect.maxY - pixels * 0.27),
        radius: 0,
        toCenter: NSPoint(x: iconRect.maxX - pixels * 0.14, y: iconRect.maxY - pixels * 0.27),
        radius: pixels * 0.34,
        options: []
    )

    NSGraphicsContext.restoreGraphicsState()

    stroke(basePath, color: color(0xffffff, alpha: 0.13), width: max(1, pixels * 0.009))
    stroke(roundedRect(iconRect.insetBy(dx: pixels * 0.010, dy: pixels * 0.010), radius: radius * 0.95), color: color(0x000000, alpha: 0.20), width: max(1, pixels * 0.010))
}

func drawBands(iconRect: NSRect, pixels: CGFloat) {
    let clipPath = roundedRect(iconRect, radius: pixels * 0.21)
    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()

    let bands = [
        (
            topLeft: pixels * 0.480,
            topRight: pixels * 0.535,
            bottomLeft: pixels * 0.375,
            bottomRight: pixels * 0.420,
            top: color(0x7d66d8),
            bottom: color(0x5841a2),
            highlight: color(0xd8ceff, alpha: 0.42)
        ),
        (
            topLeft: pixels * 0.388,
            topRight: pixels * 0.468,
            bottomLeft: pixels * 0.278,
            bottomRight: pixels * 0.342,
            top: color(0x6e55c2),
            bottom: color(0x49368f),
            highlight: color(0xcbbcff, alpha: 0.34)
        ),
        (
            topLeft: pixels * 0.292,
            topRight: pixels * 0.382,
            bottomLeft: pixels * 0.168,
            bottomRight: pixels * 0.250,
            top: color(0x5d45a8),
            bottom: color(0x392a76),
            highlight: color(0xbaadff, alpha: 0.28)
        ),
        (
            topLeft: pixels * 0.205,
            topRight: pixels * 0.298,
            bottomLeft: -pixels * 0.050,
            bottomRight: pixels * 0.012,
            top: color(0x4d3a93),
            bottom: color(0x25194d),
            highlight: color(0xa798ff, alpha: 0.22)
        )
    ]

    for band in bands {
        let path = bandPath(
            pixels: pixels,
            topLeft: band.topLeft,
            topRight: band.topRight,
            bottomLeft: band.bottomLeft,
            bottomRight: band.bottomRight
        )

        fill(
            path,
            gradient: NSGradient(colors: [band.top, band.bottom])!,
            bounds: path.bounds,
            angle: -88,
            shadow: shadow(
                color: color(0x070412, alpha: 0.34),
                blur: pixels * 0.026,
                offset: NSSize(width: 0, height: -pixels * 0.012)
            )
        )

        stroke(bandTopPath(pixels: pixels, topLeft: band.topLeft, topRight: band.topRight), color: band.highlight, width: max(1, pixels * 0.010))
        stroke(bandTopPath(pixels: pixels, topLeft: band.topLeft - pixels * 0.012, topRight: band.topRight - pixels * 0.012), color: color(0x160f35, alpha: 0.20), width: max(1, pixels * 0.006))
    }

    NSGraphicsContext.restoreGraphicsState()
}

func drawOrb(pixels: CGFloat) {
    let center = NSPoint(x: pixels * 0.690, y: pixels * 0.690)
    let radius = pixels * 0.060
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    let orbPath = NSBezierPath(ovalIn: rect)

    NSGradient(colors: [
        color(0xf1eee7, alpha: 0.30),
        color(0xf1eee7, alpha: 0.00)
    ])?.draw(
        fromCenter: center,
        radius: radius * 0.10,
        toCenter: center,
        radius: radius * 2.45,
        options: []
    )

    fill(
        orbPath,
        gradient: NSGradient(colors: [
            color(0xffffff),
            color(0xf1eee7),
            color(0xc9c2b7)
        ])!,
        bounds: rect,
        angle: -45,
        shadow: shadow(
            color: color(0x05030d, alpha: 0.34),
            blur: pixels * 0.028,
            offset: NSSize(width: pixels * 0.010, height: -pixels * 0.012)
        )
    )

    fill(
        NSBezierPath(ovalIn: NSRect(
            x: center.x - radius * 0.44,
            y: center.y + radius * 0.18,
            width: radius * 0.44,
            height: radius * 0.32
        )),
        color: color(0xffffff, alpha: 0.52)
    )

    stroke(orbPath, color: color(0xffffff, alpha: 0.34), width: max(1, pixels * 0.006))
}

func renderIcon(pixels: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "CommandShelfIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap"])
    }

    let size = NSSize(width: pixels, height: pixels)
    bitmap.size = size

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current = context
    context?.shouldAntialias = true
    context?.imageInterpolation = .high

    let bounds = NSRect(origin: .zero, size: size)
    color(0x000000, alpha: 0).setFill()
    bounds.fill()

    let scale = CGFloat(pixels)
    let iconRect = bounds.insetBy(dx: scale * 0.045, dy: scale * 0.045)
    drawBackground(bounds: bounds, iconRect: iconRect, radius: scale * 0.210, pixels: scale)
    drawBands(iconRect: iconRect, pixels: scale)
    drawOrb(pixels: scale)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func pngData(for pixels: Int) throws -> Data {
    guard let data = try renderIcon(pixels: pixels).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CommandShelfIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }
    return data
}

func tiffData(for pixels: Int) throws -> Data {
    guard let data = try renderIcon(pixels: pixels).tiffRepresentation else {
        throw NSError(domain: "CommandShelfIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create TIFF data"])
    }
    return data
}

func appendASCII(_ value: String, to data: inout Data) {
    data.append(value.data(using: .ascii)!)
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
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

func hasElement(_ type: String, in data: Data) -> Bool {
    guard data.count >= 8 else { return false }

    var offset = 8
    while offset + 8 <= data.count {
        let typeData = data[offset..<offset + 4]
        let elementType = String(data: typeData, encoding: .ascii)

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
        throw NSError(domain: "CommandShelfIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid ICNS output"])
    }

    guard !hasElement(type, in: file) else {
        return
    }

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

try pngData(for: 1024).write(to: pngURL, options: .atomic)

var tiffPaths: [String] = []
for spec in specs {
    let fileURL = buildURL.appendingPathComponent(spec.name)
    try tiffData(for: spec.pixels).write(to: fileURL, options: .atomic)
    tiffPaths.append(fileURL.path)
}

try run("/usr/bin/tiffutil", ["-cat"] + tiffPaths + ["-out", tiffURL.path])
try run("/usr/bin/tiff2icns", [tiffURL.path, outputURL.path])
try appendIconElement(type: "ic10", elementData: try pngData(for: 1024), to: outputURL)
try? FileManager.default.removeItem(at: buildURL)

print("Wrote \(pngURL.path)")
print("Wrote \(outputURL.path)")
