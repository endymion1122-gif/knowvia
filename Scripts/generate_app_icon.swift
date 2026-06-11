import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift Scripts/generate_app_icon.swift <output-directory>")
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func color(_ hex: String) -> NSColor {
    var value: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&value)
    return NSColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
}

let deepIndigo = color("1B1E5F")
let softViolet = color("7B60FF")
let orbitBlue = color("449CFF")
let pathTeal = color("21C7C2")

func point(_ x: CGFloat, _ y: CGFloat, side: CGFloat) -> NSPoint {
    NSPoint(x: side * x, y: side * y)
}

func drawPath(_ path: NSBezierPath, color: NSColor, lineWidth: CGFloat) {
    path.lineWidth = lineWidth
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

func drawNode(at center: NSPoint, radius: CGFloat, color: NSColor, borderColor: NSColor? = nil, borderWidth: CGFloat = 0) {
    color.setFill()
    let node = NSBezierPath(
        ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    )
    node.fill()
    if let borderColor {
        borderColor.setStroke()
        node.lineWidth = borderWidth
        node.stroke()
    }
}

func drawSparkle(at center: NSPoint, radius: CGFloat, color: NSColor) {
    let sparkle = NSBezierPath()
    sparkle.move(to: NSPoint(x: center.x, y: center.y + radius))
    sparkle.line(to: NSPoint(x: center.x + radius * 0.2, y: center.y + radius * 0.2))
    sparkle.line(to: NSPoint(x: center.x + radius, y: center.y))
    sparkle.line(to: NSPoint(x: center.x + radius * 0.2, y: center.y - radius * 0.2))
    sparkle.line(to: NSPoint(x: center.x, y: center.y - radius))
    sparkle.line(to: NSPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.2))
    sparkle.line(to: NSPoint(x: center.x - radius, y: center.y))
    sparkle.line(to: NSPoint(x: center.x - radius * 0.2, y: center.y + radius * 0.2))
    sparkle.close()
    color.setFill()
    sparkle.fill()
}

func renderIcon(side: Int, filename: String) throws {
    let dimension = CGFloat(side)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create bitmap for \(filename)")
    }

    bitmap.size = NSSize(width: dimension, height: dimension)
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create graphics context for \(filename)")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    deepIndigo.setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: dimension, height: dimension),
        xRadius: dimension * 0.22,
        yRadius: dimension * 0.22
    ).fill()

    let orbitRect = NSRect(
        x: dimension * 0.06,
        y: dimension * 0.31,
        width: dimension * 0.88,
        height: dimension * 0.34
    )
    let orbit = NSBezierPath(ovalIn: orbitRect)
    var orbitTransform = AffineTransform(translationByX: dimension * 0.50, byY: dimension * 0.48)
    orbitTransform.rotate(byDegrees: -14)
    orbitTransform.translate(x: -dimension * 0.50, y: -dimension * 0.48)
    orbit.transform(using: orbitTransform)
    drawPath(orbit, color: softViolet, lineWidth: max(2, dimension * 0.036))

    let arch = NSBezierPath()
    arch.move(to: point(0.30, 0.19, side: dimension))
    arch.line(to: point(0.30, 0.66, side: dimension))
    arch.curve(
        to: point(0.68, 0.66, side: dimension),
        controlPoint1: point(0.30, 0.87, side: dimension),
        controlPoint2: point(0.68, 0.87, side: dimension)
    )
    arch.line(to: point(0.68, 0.52, side: dimension))
    drawPath(arch, color: orbitBlue, lineWidth: max(3, dimension * 0.105))

    let diagonal = NSBezierPath()
    diagonal.move(to: point(0.31, 0.30, side: dimension))
    diagonal.line(to: point(0.52, 0.45, side: dimension))
    diagonal.line(to: point(0.78, 0.18, side: dimension))
    drawPath(diagonal, color: pathTeal, lineWidth: max(3, dimension * 0.105))

    drawSparkle(at: point(0.43, 0.65, side: dimension), radius: dimension * 0.095, color: NSColor.white)
    drawNode(
        at: point(0.81, 0.54, side: dimension),
        radius: dimension * 0.055,
        color: pathTeal,
        borderColor: NSColor.white,
        borderWidth: max(1, dimension * 0.014)
    )

    graphicsContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(filename)")
    }

    try png.write(to: outputDirectory.appendingPathComponent(filename))
}

let icons = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for icon in icons {
    try renderIcon(side: icon.0, filename: icon.1)
}
