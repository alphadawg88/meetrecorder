#!/usr/bin/env swift
//
// render_icons.swift — generate AppIcon PNGs from the "Capture" design.
//
// macOS app icons must be PNG (actool ignores SVG in an .appiconset), and no
// SVG rasterizer (rsvg/cairo/inkscape) is installed. This reproduces the exact
// geometry of design AppIcon.svg with Core Graphics and exports every required
// size. If the SVG design changes substantially, update the constants below or
// rasterize the SVG with a dedicated tool instead.
//
// Usage: swift tools/render_icons.swift <output-dir>

import AppKit

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "MeetRecorder/Assets.xcassets/AppIcon.appiconset"

// (filename, pixel size) — matches AppIcon.appiconset/Contents.json
let targets: [(String, Int)] = [
    ("icon_16.png", 16),   ("icon_16@2x.png", 32),
    ("icon_32.png", 32),   ("icon_32@2x.png", 64),
    ("icon_128.png", 128), ("icon_128@2x.png", 256),
    ("icon_256.png", 256), ("icon_256@2x.png", 512),
    ("icon_512.png", 512), ("icon_512@2x.png", 1024),
]

func draw(size n: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Map 1024-unit, y-down SVG space into the y-up device of size n.
    let scale = CGFloat(n) / 1024.0
    cg.translateBy(x: 0, y: CGFloat(n))
    cg.scaleBy(x: scale, y: -scale)

    // Rounded-rect background with vertical gradient (#2C2C2E -> #1C1C1E).
    let bgRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 200, cornerHeight: 200, transform: nil)
    cg.saveGState()
    cg.addPath(bgPath)
    cg.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        NSColor(srgbRed: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1).cgColor,
        NSColor(srgbRed: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 1024), options: [])
    // Subtle top highlight for depth.
    let hl = CGGradient(colorsSpace: cs, colors: [
        NSColor(white: 1, alpha: 0.08).cgColor,
        NSColor(white: 1, alpha: 0).cgColor,
    ] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(hl, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 1024), options: [])
    cg.restoreGState()

    let white = NSColor(white: 1, alpha: 0.95).cgColor

    // Capture circle: center (512,512), r=340, stroke 24.
    cg.setStrokeColor(white)
    cg.setLineWidth(24)
    cg.strokeEllipse(in: CGRect(x: 512 - 340, y: 512 - 340, width: 680, height: 680))

    // Waveform: two cubic beziers.
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: 300, y: 512))
    wave.addCurve(to: CGPoint(x: 512, y: 512),
                  control1: CGPoint(x: 380, y: 380), control2: CGPoint(x: 460, y: 380))
    wave.addCurve(to: CGPoint(x: 724, y: 512),
                  control1: CGPoint(x: 564, y: 644), control2: CGPoint(x: 644, y: 644))
    cg.setLineWidth(28)
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    cg.addPath(wave)
    cg.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, n) in targets {
    guard let data = draw(size: n) else { fputs("failed: \(name)\n", stderr); continue }
    let path = (outDir as NSString).appendingPathComponent(name)
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(name) (\(n)px)")
}
print("done -> \(outDir)")
