// Draws the SpotKeys app icon: a key cap with a play/pause glyph on a green squircle.
//
// Run from the repository root after changing the artwork:
//     swift scripts/make-icon.swift
//
// Writes:
//   Resources/AppIcon.icon/       Icon Composer bundle (Liquid Glass icon on macOS 26+)
//   Resources/AppIcon.icns        Classic icon for older macOS versions
//   docs/logo.png                 Logo for the README
import AppKit

let canvas: CGFloat = 1024
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255,
            green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

let greenTop: UInt32 = 0x2EE070
let greenBottom: UInt32 = 0x12993F
let keyFaceTop: UInt32 = 0xFFFFFF
let keyFaceBottom: UInt32 = 0xE9EDF0
let keyEdge: UInt32 = 0xBCC3C9
let glyphColor: UInt32 = 0x161A1D

// MARK: - Drawing

func fillGradient(_ ctx: CGContext, _ path: CGPath, top: UInt32, bottom: UInt32) {
    let rect = path.boundingBox
    let gradient = CGGradient(colorsSpace: sRGB, colors: [color(top), color(bottom)] as CFArray,
                              locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    ctx.restoreGState()
}

func drawBackground(_ ctx: CGContext) {
    // macOS icon grid: an 824 pt squircle centred on the 1024 pt canvas.
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, alpha: 0.3))
    ctx.addPath(body)
    ctx.setFillColor(color(greenBottom))
    ctx.fillPath()
    ctx.restoreGState()
    fillGradient(ctx, body, top: greenTop, bottom: greenBottom)
}

/// The play/pause glyph centred on `center`, `width` points wide.
/// The triangle is returned separately so its corners can be rounded with a stroke.
func glyphPaths(center: CGPoint, width: CGFloat) -> (triangle: CGPath, bars: CGPath) {
    let unit = width / 264
    let height = 176 * unit
    let minX = center.x - width / 2
    let minY = center.y - height / 2

    let triangle = CGMutablePath()
    triangle.move(to: CGPoint(x: minX, y: minY))
    triangle.addLine(to: CGPoint(x: minX + 140 * unit, y: center.y))
    triangle.addLine(to: CGPoint(x: minX, y: minY + height))
    triangle.closeSubpath()

    let bars = CGMutablePath()
    let barWidth = 34 * unit
    for x in [minX + 176 * unit, minX + 230 * unit] {
        bars.addRoundedRect(in: CGRect(x: x, y: minY, width: barWidth, height: height),
                            cornerWidth: 8 * unit, cornerHeight: 8 * unit)
    }
    return (triangle, bars)
}

func drawKeycap(_ ctx: CGContext) {
    let size: CGFloat = 500
    let face = CGRect(x: (canvas - size) / 2, y: (canvas - size) / 2 + 18, width: size, height: size)
    let base = face.offsetBy(dx: 0, dy: -36)
    let radius: CGFloat = 104
    let facePath = CGPath(roundedRect: face, cornerWidth: radius, cornerHeight: radius, transform: nil)
    let basePath = CGPath(roundedRect: base, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // The key's side, casting a soft shadow onto the background.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 44, color: color(0x003314, alpha: 0.45))
    ctx.addPath(basePath)
    ctx.setFillColor(color(keyEdge))
    ctx.fillPath()
    ctx.restoreGState()

    fillGradient(ctx, facePath, top: keyFaceTop, bottom: keyFaceBottom)

    let glyph = glyphPaths(center: CGPoint(x: face.midX + 4, y: face.midY), width: 264)
    ctx.setFillColor(color(glyphColor))
    ctx.setStrokeColor(color(glyphColor))
    ctx.setLineWidth(14)
    ctx.setLineJoin(.round)
    ctx.addPath(glyph.triangle)
    ctx.drawPath(using: .fillStroke)
    ctx.addPath(glyph.bars)
    ctx.fillPath()
}

// MARK: - Output

func render(pixels: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    draw(ctx)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not write \(path)")
}

func fullIcon(_ ctx: CGContext) {
    drawBackground(ctx)
    drawKeycap(ctx)
}

// Icon Composer bundle: the system draws the background and glass, we supply the key cap.
let iconBundle = "Resources/AppIcon.icon"
try? FileManager.default.removeItem(atPath: iconBundle)
// The system's squircle fills the whole canvas, so scale the key cap up to keep the classic proportions.
writePNG(render(pixels: 1024) { ctx in
    let scale = canvas / 824
    ctx.translateBy(x: canvas / 2, y: canvas / 2)
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -canvas / 2, y: -canvas / 2)
    drawKeycap(ctx)
}, to: "\(iconBundle)/Assets/Keycap.png")
let iconJSON = """
    {
      "fill" : {
        "linear-gradient" : [
          "srgb:\(String(format: "%.5f,%.5f,%.5f", 0x2E / 255.0, 0xE0 / 255.0, 0x70 / 255.0)),1.00000",
          "srgb:\(String(format: "%.5f,%.5f,%.5f", 0x12 / 255.0, 0x99 / 255.0, 0x3F / 255.0)),1.00000"
        ]
      },
      "groups" : [
        {
          "layers" : [
            {
              "image-name" : "Keycap.png",
              "name" : "Keycap"
            }
          ],
          "shadow" : {
            "kind" : "neutral",
            "opacity" : 0.5
          },
          "translucency" : {
            "enabled" : false,
            "value" : 0.5
          }
        }
      ],
      "supported-platforms" : {
        "squares" : [
          "macOS"
        ]
      }
    }

    """
try! iconJSON.write(toFile: "\(iconBundle)/icon.json", atomically: true, encoding: .utf8)

// Classic .icns.
let iconset = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
for points in [16, 32, 128, 256, 512] {
    writePNG(render(pixels: points, fullIcon), to: "\(iconset)/icon_\(points)x\(points).png")
    writePNG(render(pixels: points * 2, fullIcon), to: "\(iconset)/icon_\(points)x\(points)@2x.png")
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
precondition(iconutil.terminationStatus == 0, "iconutil failed")

writePNG(render(pixels: 512, fullIcon), to: "docs/logo.png")
print("Wrote \(iconBundle), Resources/AppIcon.icns and docs/logo.png")
