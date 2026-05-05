import AppKit
import Foundation

struct IconSpec {
    let type: String
    let pixels: CGFloat
}

let specs: [IconSpec] = [
    .init(type: "icp4", pixels: 16),
    .init(type: "icp5", pixels: 32),
    .init(type: "icp6", pixels: 64),
    .init(type: "ic07", pixels: 128),
    .init(type: "ic08", pixels: 256),
    .init(type: "ic09", pixels: 512),
    .init(type: "ic10", pixels: 1024)
]

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawSymbol(_ name: String, in rect: NSRect, color: NSColor) {
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
    let configured = symbol.withSymbolConfiguration(.init(pointSize: rect.height * 0.62, weight: .semibold))
    let image = configured ?? symbol
    image.isTemplate = true
    color.set()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}

func renderIcon(pixels: CGFloat) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    let bounds = NSRect(origin: .zero, size: size)
    let radius = pixels * 0.22
    let backgroundPath = NSBezierPath(roundedRect: bounds.insetBy(dx: pixels * 0.04, dy: pixels * 0.04), xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        color(29, 99, 216),
        color(0, 164, 151)
    ])
    gradient?.draw(in: backgroundPath, angle: -35)

    let shelfPath = NSBezierPath(roundedRect: bounds.insetBy(dx: pixels * 0.17, dy: pixels * 0.18), xRadius: pixels * 0.09, yRadius: pixels * 0.09)
    color(255, 255, 255, 0.20).setFill()
    shelfPath.fill()
    color(255, 255, 255, 0.28).setStroke()
    shelfPath.lineWidth = max(1, pixels * 0.012)
    shelfPath.stroke()

    let gap = pixels * 0.055
    let tileSize = pixels * 0.245
    let startX = pixels * 0.255
    let startY = pixels * 0.285
    let symbols = [
        ("doc.text", NSRect(x: startX, y: startY + tileSize + gap, width: tileSize, height: tileSize)),
        ("link", NSRect(x: startX + tileSize + gap, y: startY + tileSize + gap, width: tileSize, height: tileSize)),
        ("command", NSRect(x: startX, y: startY, width: tileSize, height: tileSize)),
        ("sparkles", NSRect(x: startX + tileSize + gap, y: startY, width: tileSize, height: tileSize))
    ]

    for (name, rect) in symbols {
        let tile = NSBezierPath(roundedRect: rect, xRadius: pixels * 0.045, yRadius: pixels * 0.045)
        color(255, 255, 255, 0.88).setFill()
        tile.fill()
        color(255, 255, 255, 0.70).setStroke()
        tile.lineWidth = max(1, pixels * 0.006)
        tile.stroke()
        drawSymbol(name, in: rect.insetBy(dx: pixels * 0.06, dy: pixels * 0.06), color: color(24, 75, 138))
    }

    image.unlockFocus()
    return image
}

func pngData(for image: NSImage) throws -> Data {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "CommandShelfIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
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

var elements: [(type: String, data: Data)] = []
for spec in specs {
    elements.append((spec.type, try pngData(for: renderIcon(pixels: spec.pixels))))
}

let totalLength = 8 + elements.reduce(0) { partial, element in
    partial + 8 + element.data.count
}

var icns = Data()
appendASCII("icns", to: &icns)
appendUInt32(UInt32(totalLength), to: &icns)

for element in elements {
    appendASCII(element.type, to: &icns)
    appendUInt32(UInt32(8 + element.data.count), to: &icns)
    icns.append(element.data)
}

try icns.write(to: outputURL, options: .atomic)
print("Wrote \(outputURL.path)")
