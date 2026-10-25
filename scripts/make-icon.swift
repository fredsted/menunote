#!/usr/bin/env swift
// Draws the MenuNote app icon and writes every macOS size into AppIcon.appiconset.
//
// Usage: swift scripts/make-icon.swift

import AppKit

let iconSet = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "MenuNote/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Draws the icon on a 1024×1024 canvas (origin bottom-left).
func drawIcon() {
    // macOS icon grid: 824pt body centred on the canvas, leaving room for the shadow.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let radius: CGFloat = 185
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    // Drop shadow.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.30)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    color(0xFFD45C).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()

    // Sticky-note paper.
    NSGradient(starting: color(0xFFE58A), ending: color(0xFFC53D))!.draw(in: body, angle: -90)

    // Menu bar strip across the top.
    let barHeight: CGFloat = 196
    let bar = NSRect(x: body.minX, y: body.maxY - barHeight, width: body.width, height: barHeight)
    NSGradient(starting: color(0x3A3A3F), ending: color(0x232326))!.draw(in: bar, angle: -90)

    // ••• on the right of the bar, as in the note window.
    let dotSize: CGFloat = 48
    let dotGap: CGFloat = 30
    color(0xFFFFFF, 0.92).setFill()
    for i in 0..<3 {
        let x = body.maxX - 110 - CGFloat(2 - i) * (dotSize + dotGap) - dotSize
        NSBezierPath(ovalIn: NSRect(x: x, y: bar.midY - dotSize / 2, width: dotSize, height: dotSize)).fill()
    }

    // Lines of "text" on the note.
    let lineHeight: CGFloat = 52
    let lineWidths: [CGFloat] = [560, 470, 600, 340]
    color(0x8A5A00, 0.55).setFill()
    for (i, width) in lineWidths.enumerated() {
        let y = bar.minY - 130 - CGFloat(i) * 118
        NSBezierPath(roundedRect: NSRect(x: body.minX + 110, y: y, width: width, height: lineHeight),
                     xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
    }

    // Subtle highlight along the top edge of the paper.
    color(0xFFFFFF, 0.35).setFill()
    NSRect(x: body.minX, y: bar.minY - 6, width: body.width, height: 6).fill()

    NSGraphicsContext.restoreGraphicsState()

    // Fine edge so the icon holds up on light backgrounds.
    color(0x000000, 0.12).setStroke()
    let edge = NSBezierPath(roundedRect: body.insetBy(dx: 1, dy: 1), xRadius: radius - 1, yRadius: radius - 1)
    edge.lineWidth = 2
    edge.stroke()
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let scale = CGFloat(pixels) / 1024
    NSAffineTransform(transform: .init(scale: scale)).concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try renderPNG(pixels: size * scale).write(to: iconSet.appending(path: filename))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appending(path: "Contents.json"))
print("Wrote \(images.count) icons to \(iconSet.path)")
