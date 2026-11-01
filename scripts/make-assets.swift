// Draws RIM's app icon and GitHub banner. Run: swift scripts/make-assets.swift
// Writes assets/icon.png (1024) and assets/banner.png (1280x640). make-icon.sh turns the icon into AppIcon.icns.
import AppKit

let accent = NSColor(srgbRed: 1.0, green: 0.72, blue: 0.28, alpha: 1)
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func render(width: Int, height: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    draw(context.cgContext)
    NSGraphicsContext.current = nil
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    let url = outDir.appendingPathComponent(name)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("wrote \(url.path)")
}

/// Flat top, rounded bottom corners. y grows upward; `top` is the flat edge.
func notchPath(centerX: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, radius r: CGFloat) -> CGPath {
    let minX = centerX - width / 2, maxX = centerX + width / 2, bottom = top - height
    let path = CGMutablePath()
    path.move(to: CGPoint(x: minX, y: top))
    path.addLine(to: CGPoint(x: maxX, y: top))
    path.addLine(to: CGPoint(x: maxX, y: bottom + r))
    path.addArc(tangent1End: CGPoint(x: maxX, y: bottom), tangent2End: CGPoint(x: maxX - r, y: bottom), radius: r)
    path.addLine(to: CGPoint(x: minX + r, y: bottom))
    path.addArc(tangent1End: CGPoint(x: minX, y: bottom), tangent2End: CGPoint(x: minX, y: bottom + r), radius: r)
    path.closeSubpath()
    return path
}

/// The "rim light": a stroke that is invisible at the top and bright amber along the bottom edge, with a soft glow.
func drawRim(_ ctx: CGContext, path: CGPath, lineWidth: CGFloat, glow: CGFloat, topY: CGFloat, bottomY: CGFloat) {
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: [
        accent.withAlphaComponent(0).cgColor,
        NSColor.white.withAlphaComponent(0.10).cgColor,
        accent.withAlphaComponent(0.95).cgColor,
    ] as CFArray, locations: [0, 0.45, 1])!

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: glow, color: accent.withAlphaComponent(0.55).cgColor)
    ctx.addPath(path)
    ctx.setLineWidth(lineWidth)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: topY), end: CGPoint(x: 0, y: bottomY), options: [])
    ctx.restoreGState()
}

func text(_ string: String, font: NSFont, color: NSColor, kern: CGFloat = 0, centerX: CGFloat, baselineY: CGFloat) {
    let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .kern: kern])
    let size = attributed.size()
    // Kerning adds trailing space after the last glyph; shift back so the text looks centered.
    attributed.draw(at: CGPoint(x: centerX - (size.width - kern) / 2, y: baselineY))
}

func textLeft(_ string: String, font: NSFont, color: NSColor, x: CGFloat, baselineY: CGFloat) {
    NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]).draw(at: CGPoint(x: x, y: baselineY))
}

func textWidth(_ string: String, font: NSFont) -> CGFloat {
    NSAttributedString(string: string, attributes: [.font: font]).size().width
}

func roundedRect(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, fill: NSColor) {
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(fill.cgColor)
    ctx.fillPath()
}

// MARK: - Icon

let icon = render(width: 1024, height: 1024) { ctx in
    let space = CGColorSpaceCreateDeviceRGB()
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Near-black body with a little lift at the top.
    let bg = CGGradient(colorsSpace: space, colors: [
        NSColor(srgbRed: 0.13, green: 0.13, blue: 0.15, alpha: 1).cgColor,
        NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

    // The notch hangs from the top edge of the icon.
    let notch = notchPath(centerX: 512, top: 960, width: 540, height: 430, radius: 140)
    ctx.addPath(notch)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    drawRim(ctx, path: notch, lineWidth: 12, glow: 70, topY: 800, bottomY: 530)

    // Three tab dots inside, the first one lit.
    for (i, alpha) in [0.9, 0.28, 0.28].enumerated() {
        let x = 512 + CGFloat(i - 1) * 56
        ctx.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
        ctx.fillEllipse(in: CGRect(x: x - 11, y: 610, width: 22, height: 22))
    }
    ctx.restoreGState()

    // Hairline edge so the icon holds its shape on dark backgrounds.
    ctx.addPath(squircle)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor)
    ctx.setLineWidth(3)
    ctx.strokePath()
}
save(icon, "icon.png")

// MARK: - Banner

let banner = render(width: 1280, height: 640) { ctx in
    let space = CGColorSpaceCreateDeviceRGB()
    let W: CGFloat = 1280, H: CGFloat = 640

    ctx.setFillColor(NSColor(srgbRed: 0.035, green: 0.035, blue: 0.043, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    // Soft pool of warm light under the panel.
    let glow = CGGradient(colorsSpace: space, colors: [
        accent.withAlphaComponent(0.13).cgColor, accent.withAlphaComponent(0).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 640, y: 380), startRadius: 0, endCenter: CGPoint(x: 640, y: 380), endRadius: 420, options: [])

    // The open notch.
    let panelTop = H + 10, panelHeight: CGFloat = 290, panelWidth: CGFloat = 620
    let panel = notchPath(centerX: 640, top: panelTop, width: panelWidth, height: panelHeight, radius: 46)
    ctx.addPath(panel)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    drawRim(ctx, path: panel, lineWidth: 2.5, glow: 40, topY: panelTop - 150, bottomY: panelTop - panelHeight)

    // Tabs: the selected one gets a pill.
    let tabY: CGFloat = 505
    let tabFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    var tabX: CGFloat = 350
    for (i, name) in ["clipboard", "convert", "shelf", "dev", "focus"].enumerated() {
        let width = textWidth(name, font: tabFont)
        let pad: CGFloat = 16
        if i == 0 {
            roundedRect(ctx, CGRect(x: tabX, y: tabY, width: width + pad * 2, height: 30), radius: 15, fill: NSColor.white.withAlphaComponent(0.14))
        }
        textLeft(name, font: tabFont, color: i == 0 ? .white : NSColor.white.withAlphaComponent(0.4), x: tabX + pad, baselineY: tabY + 8)
        tabX += width + pad * 2 + 4
    }

    // A few clipboard rows.
    let rows: [(String, String)] = [("const token = await getAuth()", "code"), ("github.com/raykrz/rim/pull/12", "link"), ("report.pdf", "file")]
    for (i, row) in rows.enumerated() {
        let y = 450 - CGFloat(i) * 40
        roundedRect(ctx, CGRect(x: 350, y: y, width: 580, height: 32), radius: 10, fill: NSColor.white.withAlphaComponent(0.07))
        textLeft(row.0, font: .monospacedSystemFont(ofSize: 13, weight: .regular), color: NSColor.white.withAlphaComponent(0.85),
                 x: 366, baselineY: y + 9)
        let tagFont = NSFont.systemFont(ofSize: 11, weight: .regular)
        textLeft(row.1, font: tagFont, color: NSColor.white.withAlphaComponent(0.35),
                 x: 914 - textWidth(row.1, font: tagFont), baselineY: y + 10)
    }

    // Wordmark and tagline.
    text("RIM", font: .systemFont(ofSize: 132, weight: .ultraLight), color: NSColor.white.withAlphaComponent(0.94),
         kern: 46, centerX: 640, baselineY: 118)
    text("everything lives in the notch", font: .systemFont(ofSize: 24, weight: .regular),
         color: NSColor.white.withAlphaComponent(0.45), kern: 3, centerX: 640, baselineY: 62)
}
save(banner, "banner.png")
