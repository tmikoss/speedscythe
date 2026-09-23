import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let assets = URL(fileURLWithPath: "Speedscythe/Resources/Assets.xcassets")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func point(_ origin: CGPoint, _ distance: CGFloat, _ degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: origin.x + cos(radians) * distance, y: origin.y + sin(radians) * distance)
}

struct Scythe {
    let shaft: CGPath
    let blade: CGPath

    init(center: CGPoint) {
        let lowerAngle: CGFloat = 150
        let upperAngle: CGFloat = 172
        let kink = point(center, 120, lowerAngle)
        let head = point(kink, 55, upperAngle)

        let shaft = CGMutablePath()
        shaft.move(to: point(center, -40, lowerAngle))
        shaft.addLine(to: kink)
        shaft.addLine(to: head)
        self.shaft = shaft

        func local(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            point(point(head, x, upperAngle - 90), y, upperAngle)
        }
        let length: CGFloat = 175
        let blade = CGMutablePath()
        blade.move(to: local(0, -12))
        blade.addLine(to: local(0, 18))
        blade.addCurve(to: local(length, -0.5 * length), control1: local(0.4 * length, 70), control2: local(0.9 * length, 0.2 * length))
        blade.addCurve(to: local(14, -10), control1: local(0.85 * length, -0.05 * length), control2: local(0.45 * length, 4))
        blade.closeSubpath()
        self.blade = blade
    }
}

func drawDial(in context: CGContext, center: CGPoint, radius: CGFloat, ringWidth: CGFloat, stemWidth: CGFloat, crownWidth: CGFloat, ink: CGColor) {
    let gapHalf: CGFloat = 26
    context.setLineCap(.round)
    context.setStrokeColor(ink)
    context.setLineWidth(ringWidth)
    context.addArc(center: center, radius: radius, startAngle: (90 + gapHalf) * .pi / 180, endAngle: (90 - gapHalf + 360) * .pi / 180, clockwise: false)
    context.strokePath()

    context.setLineWidth(stemWidth)
    context.move(to: point(center, radius - 10, 90))
    context.addLine(to: point(center, radius + 74, 90))
    context.strokePath()
    context.setLineWidth(crownWidth)
    context.move(to: CGPoint(x: center.x - 58, y: center.y + radius + 92))
    context.addLine(to: CGPoint(x: center.x + 58, y: center.y + radius + 92))
    context.strokePath()
}

func drawScythe(in context: CGContext, center: CGPoint, shaftWidth: CGFloat, pivotRadius: CGFloat, ink: CGColor) {
    let scythe = Scythe(center: center)
    context.setStrokeColor(ink)
    context.setLineWidth(shaftWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.addPath(scythe.shaft)
    context.strokePath()
    context.setFillColor(ink)
    context.addPath(scythe.blade)
    context.fillPath()
    context.fillEllipse(in: CGRect(x: center.x - pivotRadius, y: center.y - pivotRadius, width: pivotRadius * 2, height: pivotRadius * 2))
}

func drawAppIcon(in context: CGContext) {
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 186, cornerHeight: 186, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    context.addPath(tile)
    context.setFillColor(color(0x1B1D22))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tile)
    context.clip()
    let background = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(0x2E3138), color(0x121317)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    let center = CGPoint(x: 512, y: 488)
    drawDial(in: context, center: center, radius: 300, ringWidth: 44, stemWidth: 40, crownWidth: 52, ink: color(0xEDEBE6))
    drawScythe(in: context, center: center, shaftWidth: 30, pivotRadius: 40, ink: color(0xF0A843))
    context.setFillColor(color(0x1B1D22))
    context.fillEllipse(in: CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30))
}

func drawMenuBarIcon(in context: CGContext) {
    context.translateBy(x: 512, y: 512)
    context.scaleBy(x: 1.3, y: 1.3)
    context.translateBy(x: -512, y: -540)

    let center = CGPoint(x: 512, y: 488)
    drawDial(in: context, center: center, radius: 300, ringWidth: 70, stemWidth: 64, crownWidth: 76, ink: color(0x000000))
    drawScythe(in: context, center: center, shaftWidth: 52, pivotRadius: 56, ink: color(0x000000))
}

func render(_ draw: (CGContext) -> Void, size: Int, to url: URL) {
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(context)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    print(url.path)
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    render(drawAppIcon, size: size, to: assets.appendingPathComponent("AppIcon.appiconset/icon_\(size).png"))
}
for size in [18, 36] {
    render(drawMenuBarIcon, size: size, to: assets.appendingPathComponent("MenuBarIcon.imageset/menubar_\(size).png"))
}
