// Draws the app icon and writes `Support/AppIcon.icns`.
//
// USAGE (from the repository root):
//   swift scripts/make-icon.swift
//
// The script draws each size of the icon into `build/AppIcon.iconset`, then
// `iconutil` packs the sizes into `Support/AppIcon.icns`. It uses only AppKit
// and tools that come with Xcode. Run it again after a change to the drawing.

import AppKit

/// Draws the icon into a square of `pixels` x `pixels`.
func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // All the numbers below are for a 1024 canvas. `u` scales them.
    let u = CGFloat(pixels) / 1024.0

    // The background: a rounded square on the icon grid of macOS (824 of 1024),
    // in the indigo of the Yaseen Docs and Yaseen Draw icons.
    let body = NSRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let indigo = NSColor(srgbRed: 0.42, green: 0.40, blue: 0.88, alpha: 1)
    indigo.setFill()
    NSBezierPath(roundedRect: body, xRadius: 185 * u, yRadius: 185 * u).fill()

    // The sign of a menu bar: a white bar near the top, with three icons (dots) at its right end.
    let bar = NSRect(x: 190 * u, y: 716 * u, width: 644 * u, height: 108 * u)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()

    indigo.setFill()
    let dot = 52 * u
    for index in 0..<3 {
        let centerX = bar.maxX - (62 + 82 * CGFloat(index)) * u
        NSBezierPath(ovalIn: NSRect(x: centerX - dot / 2, y: bar.midY - dot / 2, width: dot, height: dot)).fill()
    }

    // The glyph: a "Y" in the middle of the space below the bar.
    let center = NSPoint(x: body.midX, y: 420 * u)
    let letterHeight = 360 * u
    let letterWidth = 300 * u
    let fork = NSPoint(x: center.x, y: center.y - letterHeight * 0.06)

    let letter = NSBezierPath()
    letter.lineWidth = 70 * u
    letter.lineCapStyle = .round
    letter.lineJoinStyle = .round
    letter.move(to: NSPoint(x: center.x - letterWidth / 2, y: center.y + letterHeight / 2))
    letter.line(to: fork)
    letter.move(to: NSPoint(x: center.x + letterWidth / 2, y: center.y + letterHeight / 2))
    letter.line(to: fork)
    letter.move(to: fork)
    letter.line(to: NSPoint(x: center.x, y: center.y - letterHeight / 2))
    NSColor.white.setStroke()
    letter.stroke()

    return rep
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
guard fileManager.fileExists(atPath: root.appendingPathComponent("Support/Info.plist").path) else {
    fail("run this script from the repository root: swift scripts/make-icon.swift")
}

let iconset = root.appendingPathComponent("build/AppIcon.iconset")
let output = root.appendingPathComponent("Support/AppIcon.icns")

try? fileManager.removeItem(at: iconset)
do {
    try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
} catch {
    fail("cannot make \(iconset.path): \(error)")
}

// The file names and pixel sizes that `iconutil` expects.
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for entry in entries {
    let rep = drawIcon(pixels: entry.pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fail("cannot make the PNG data for \(entry.name)")
    }
    do {
        try png.write(to: iconset.appendingPathComponent(entry.name))
    } catch {
        fail("cannot write \(entry.name): \(error)")
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", "--output", output.path, iconset.path]
do {
    try iconutil.run()
} catch {
    fail("cannot start iconutil: \(error)")
}
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fail("iconutil failed with status \(iconutil.terminationStatus)")
}

try? fileManager.removeItem(at: iconset)
print("Wrote \(output.path)")
