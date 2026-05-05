import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = rootURL
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("MenuBarIconTemplate.png")

let pixels = 128
let size = NSSize(width: pixels, height: pixels)
let image = NSImage(size: size)

func path(_ build: (NSBezierPath) -> Void) -> NSBezierPath {
    let value = NSBezierPath()
    build(value)
    return value
}

func stroke(_ path: NSBezierPath, width: CGFloat) {
    NSColor.black.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

image.lockFocus()
NSGraphicsContext.current?.shouldAntialias = true
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(origin: .zero, size: size).fill()

let bounds = NSRect(x: 13, y: 13, width: 102, height: 102)
let outline = NSBezierPath(roundedRect: bounds, xRadius: 25, yRadius: 25)
stroke(outline, width: 6)

let orb = NSBezierPath(ovalIn: NSRect(x: 80, y: 83, width: 15, height: 15))
NSColor.black.setFill()
orb.fill()

let upperWave = path {
    $0.move(to: NSPoint(x: 24, y: 52))
    $0.curve(
        to: NSPoint(x: 104, y: 56),
        controlPoint1: NSPoint(x: 45, y: 64),
        controlPoint2: NSPoint(x: 67, y: 39)
    )
}

let middleWave = path {
    $0.move(to: NSPoint(x: 24, y: 39))
    $0.curve(
        to: NSPoint(x: 104, y: 43),
        controlPoint1: NSPoint(x: 45, y: 51),
        controlPoint2: NSPoint(x: 67, y: 27)
    )
}

let lowerWave = path {
    $0.move(to: NSPoint(x: 24, y: 27))
    $0.curve(
        to: NSPoint(x: 104, y: 30),
        controlPoint1: NSPoint(x: 45, y: 38),
        controlPoint2: NSPoint(x: 67, y: 16)
    )
}

stroke(upperWave, width: 8)
stroke(middleWave, width: 8)
stroke(lowerWave, width: 8)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
else {
    throw NSError(
        domain: "CommandShelfMenuBarIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to create menu bar template PNG"]
    )
}

try data.write(to: outputURL, options: .atomic)
print("Wrote \(outputURL.path)")
