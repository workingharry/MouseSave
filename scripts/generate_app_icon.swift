import AppKit
import CoreGraphics
import Foundation

func createSquirclePath(in rect: CGRect, cornerRadius: CGFloat) -> NSBezierPath {
    return NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
}

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let scale = size / 1024.0

    // Canvas bounds
    let canvasRect = CGRect(x: 0, y: 0, width: size, height: size)
    ctx.clear(canvasRect)

    // 1. macOS Squircle Container with subtle shadow
    let iconInset: CGFloat = 80.0 * scale
    let iconRect = canvasRect.insetBy(dx: iconInset, dy: iconInset)
    let cornerRadius: CGFloat = 224.0 * scale

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -18.0 * scale),
        blur: 32.0 * scale,
        color: NSColor(white: 0.0, alpha: 0.45).cgColor
    )

    let squirclePath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(squirclePath)
    ctx.clip()

    // 2. Premium Dark Sapphire Gradient Background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(red: 0.06, green: 0.08, blue: 0.13, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: iconRect.midX, y: iconRect.maxY),
            end: CGPoint(x: iconRect.midX, y: iconRect.minY),
            options: []
        )
    }

    // 3. Subtle Metallic Rim Lighting
    ctx.addPath(squirclePath)
    ctx.setLineWidth(3.0 * scale)
    ctx.setStrokeColor(NSColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 0.35).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Center Ergonomic Mouse Illustration
    let mouseCenterX = iconRect.midX
    let mouseCenterY = iconRect.midY - 15.0 * scale
    let mouseWidth: CGFloat = 340.0 * scale
    let mouseHeight: CGFloat = 520.0 * scale
    let mouseRect = CGRect(
        x: mouseCenterX - mouseWidth / 2.0,
        y: mouseCenterY - mouseHeight / 2.0,
        width: mouseWidth,
        height: mouseHeight
    )

    // Mouse Body Shape (Sculpted Ergonomic Silhouette)
    let mouseBodyPath = CGMutablePath()
    let rTop: CGFloat = 130.0 * scale
    let rBottom: CGFloat = 100.0 * scale
    mouseBodyPath.addRoundedRect(in: mouseRect, cornerWidth: rTop, cornerHeight: rBottom)

    // Outer Glow / Ambient Lighting under the mouse
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: 0),
        blur: 40.0 * scale,
        color: NSColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 0.4).cgColor
    )
    ctx.addPath(mouseBodyPath)
    ctx.setFillColor(NSColor(red: 0.16, green: 0.20, blue: 0.28, alpha: 0.95).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Mouse Surface Gradient
    ctx.saveGState()
    ctx.addPath(mouseBodyPath)
    ctx.clip()

    let mouseColors = [
        NSColor(red: 0.22, green: 0.27, blue: 0.38, alpha: 1.0).cgColor,
        NSColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0).cgColor
    ] as CFArray
    if let mouseGrad = CGGradient(colorsSpace: colorSpace, colors: mouseColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            mouseGrad,
            start: CGPoint(x: mouseRect.midX, y: mouseRect.maxY),
            end: CGPoint(x: mouseRect.midX, y: mouseRect.minY),
            options: []
        )
    }

    // Top seam dividing Left and Right Click buttons
    let seamYStart = mouseRect.maxY - 200.0 * scale
    let seamPath = CGMutablePath()
    seamPath.move(to: CGPoint(x: mouseCenterX, y: mouseRect.maxY - 15.0 * scale))
    seamPath.addLine(to: CGPoint(x: mouseCenterX, y: seamYStart))
    ctx.addPath(seamPath)
    ctx.setLineWidth(2.5 * scale)
    ctx.setStrokeColor(NSColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 0.9).cgColor)
    ctx.strokePath()

    // Glowing Neon Scroll Wheel
    let wheelWidth: CGFloat = 36.0 * scale
    let wheelHeight: CGFloat = 90.0 * scale
    let wheelRect = CGRect(
        x: mouseCenterX - wheelWidth / 2.0,
        y: mouseRect.maxY - 145.0 * scale,
        width: wheelWidth,
        height: wheelHeight
    )
    let wheelPath = CGPath(roundedRect: wheelRect, cornerWidth: 16.0 * scale, cornerHeight: 16.0 * scale, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: .zero,
        blur: 16.0 * scale,
        color: NSColor(red: 0.1, green: 0.9, blue: 0.95, alpha: 0.8).cgColor
    )
    ctx.addPath(wheelPath)
    ctx.setFillColor(NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Mouse Body Outline Accent
    ctx.addPath(mouseBodyPath)
    ctx.setLineWidth(2.0 * scale)
    ctx.setStrokeColor(NSColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 0.5).cgColor)
    ctx.strokePath()

    ctx.restoreGState()

    // 5. Dynamic Gesture Motion Arcs (Symbolizing 3-Finger Space Switching)
    let arcRadius: CGFloat = 260.0 * scale

    // Left Swipe Arc
    ctx.saveGState()
    ctx.setShadow(
        offset: .zero,
        blur: 18.0 * scale,
        color: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.7).cgColor
    )
    let leftArc = CGMutablePath()
    leftArc.addArc(
        center: CGPoint(x: mouseCenterX, y: mouseCenterY),
        radius: arcRadius,
        startAngle: CGFloat.pi * 0.75,
        endAngle: CGFloat.pi * 1.15,
        clockwise: false
    )
    ctx.addPath(leftArc)
    ctx.setLineWidth(8.0 * scale)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor(red: 0.15, green: 0.85, blue: 1.0, alpha: 0.9).cgColor)
    ctx.strokePath()

    // Right Swipe Arc
    let rightArc = CGMutablePath()
    rightArc.addArc(
        center: CGPoint(x: mouseCenterX, y: mouseCenterY),
        radius: arcRadius,
        startAngle: -CGFloat.pi * 0.15,
        endAngle: CGFloat.pi * 0.25,
        clockwise: false
    )
    ctx.addPath(rightArc)
    ctx.setLineWidth(8.0 * scale)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(NSColor(red: 0.35, green: 0.75, blue: 1.0, alpha: 0.9).cgColor)
    ctx.strokePath()
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData),
          let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(path)")
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
}

// Generate full iconset
let fileManager = FileManager.default
let iconsetDir = "AppIcon.iconset"
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

for (baseSize, scale) in sizes {
    let pixelSize = CGFloat(baseSize * scale)
    let img = drawAppIcon(size: pixelSize)
    let filename = scale == 1 ? "icon_\(baseSize)x\(baseSize).png" : "icon_\(baseSize)x\(baseSize)@2x.png"
    savePNG(image: img, path: "\(iconsetDir)/\(filename)")
}

print("✅ AppIcon.iconset generated successfully.")
