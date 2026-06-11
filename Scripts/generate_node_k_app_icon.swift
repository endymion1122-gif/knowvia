import AppKit
import CoreGraphics
import Foundation
import ImageIO

private let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? "Knowvia/Resources/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)

private let sizes: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

private struct RGB {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

private let deepIndigo = RGB(red: 0x1B / 255, green: 0x1E / 255, blue: 0x5F / 255)
private let softViolet = RGB(red: 0x7B / 255, green: 0x66 / 255, blue: 0xFF / 255)
private let pathTeal = RGB(red: 0x21 / 255, green: 0xC7 / 255, blue: 0xC2 / 255)
private let warmWhite = RGB(red: 0xFA / 255, green: 0xFA / 255, blue: 0xF8 / 255)

private func point(_ x: CGFloat, _ y: CGFloat, size: CGFloat) -> CGPoint {
    CGPoint(x: size * x, y: size * y)
}

private func drawGradientStroke(
    context: CGContext,
    path: CGPath,
    width: CGFloat,
    start: CGPoint,
    end: CGPoint,
    colors: [CGColor]
) {
    context.saveGState()
    context.addPath(path)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: nil
    )!
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

private func drawIcon(pixels: Int, to url: URL) throws {
    let size = CGFloat(pixels)
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: pixels * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "KnowviaIcon", code: 1)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let inset = size * 0.035
    let background = CGPath(
        roundedRect: CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
        cornerWidth: size * 0.205,
        cornerHeight: size * 0.205,
        transform: nil
    )
    context.addPath(background)
    context.setFillColor(warmWhite.cgColor)
    context.fillPath()

    let center = point(0.46, 0.52, size: size)
    let topLeft = point(0.24, 0.77, size: size)
    let bottomLeft = point(0.24, 0.26, size: size)
    let topRight = point(0.73, 0.75, size: size)
    let bottomRight = point(0.75, 0.22, size: size)
    let width = size * 0.085

    let left = CGMutablePath()
    left.move(to: topLeft)
    left.addLine(to: bottomLeft)
    left.addLine(to: center)
    drawGradientStroke(
        context: context,
        path: left,
        width: width,
        start: topLeft,
        end: center,
        colors: [deepIndigo.cgColor, softViolet.cgColor]
    )

    let upper = CGMutablePath()
    upper.move(to: center)
    upper.addLine(to: topRight)
    drawGradientStroke(
        context: context,
        path: upper,
        width: width,
        start: center,
        end: topRight,
        colors: [softViolet.cgColor, deepIndigo.cgColor]
    )

    let lower = CGMutablePath()
    lower.move(to: center)
    lower.addLine(to: bottomRight)
    drawGradientStroke(
        context: context,
        path: lower,
        width: width,
        start: center,
        end: bottomRight,
        colors: [softViolet.cgColor, pathTeal.cgColor]
    )

    context.setFillColor(deepIndigo.cgColor)
    context.fillEllipse(
        in: CGRect(
            x: topRight.x - width / 2,
            y: topRight.y - width / 2,
            width: width,
            height: width
        )
    )

    for (point, color, radius) in [
        (topLeft, deepIndigo.cgColor, size * 0.086),
        (center, softViolet.cgColor, size * 0.090),
        (bottomRight, pathTeal.cgColor, size * 0.087),
    ] {
        context.setFillColor(color)
        context.fillEllipse(
            in: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }

    guard
        let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.png" as CFString,
            1,
            nil
        )
    else {
        throw NSError(domain: "KnowviaIcon", code: 2)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "KnowviaIcon", code: 3)
    }
}

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)
for icon in sizes {
    try drawIcon(pixels: icon.pixels, to: outputDirectory.appendingPathComponent(icon.name))
}
