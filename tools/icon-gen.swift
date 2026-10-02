// Renders RAPTOR.icns source PNGs for the macOS app bundle.
//
// The official RAPTOR distribution only ships a 16x16 and 32x32 Windows icon
// inside raptor.exe's .rsrc section, which is far too small for a Retina Mac
// icon. Rather than upscaling that blurry bitmap, this draws a clean icon in
// the macOS squircle idiom with AppKit.
//
// Usage:  swiftc -O -o icon-gen icon-gen.swift && ./icon-gen <output-dir>

import AppKit
import Foundation

let sizes = [16, 32, 64, 128, 256, 512, 1024]

func drawIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icons keep a transparent margin around the squircle body.
    let inset = s * 0.06
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    // 0.2237 * size is the corner radius Apple uses for the macOS icon grid.
    let radius = rect.width * 0.2237
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Body: deep slate fading to near-black.
    let grad = NSGradient(colors: [
        NSColor(srgbRed: 0.16, green: 0.19, blue: 0.24, alpha: 1),
        NSColor(srgbRed: 0.05, green: 0.06, blue: 0.09, alpha: 1)
    ])!
    grad.draw(in: squircle, angle: -90)

    // Top highlight, clipped to the squircle.
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    let highlight = NSGradient(colors: [
        NSColor(white: 1, alpha: 0.14), NSColor(white: 1, alpha: 0.0)
    ])!
    highlight.draw(in: NSRect(x: rect.minX, y: rect.midY,
                              width: rect.width, height: rect.height / 2), angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Accent ring.
    let ringInset = rect.width * 0.145
    let inner = rect.width - ringInset * 2
    let ring = NSBezierPath(roundedRect: rect.insetBy(dx: ringInset, dy: ringInset),
                            xRadius: inner * 0.22, yRadius: inner * 0.22)
    ring.lineWidth = max(1, s * 0.022)
    NSColor(srgbRed: 0.29, green: 0.85, blue: 0.60, alpha: 0.95).setStroke()
    ring.stroke()

    // "R" glyph.
    let fontSize = s * 0.52
    let font = NSFont(name: "Helvetica-Bold", size: fontSize)
        ?? NSFont.boldSystemFont(ofSize: fontSize)
    let str = NSAttributedString(string: "R", attributes: [
        .font: font,
        .foregroundColor: NSColor.white
    ])
    let textSize = str.size()
    str.draw(at: NSPoint(x: (s - textSize.width) / 2,
                         y: (s - textSize.height) / 2 + s * 0.01))

    // Accent underline.
    let barWidth = s * 0.30
    let barHeight = max(1.0, s * 0.035)
    let bar = NSRect(x: (s - barWidth) / 2, y: s * 0.215,
                     width: barWidth, height: barHeight)
    NSColor(srgbRed: 0.29, green: 0.85, blue: 0.60, alpha: 1).setFill()
    NSBezierPath(roundedRect: bar, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: icon-gen <output-dir>\n".data(using: .utf8)!)
    exit(2)
}
let outDir = args[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for size in sizes {
    let rep = drawIcon(size: size)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("failed to render \(size)px\n".data(using: .utf8)!)
        exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(size).png"))
}
