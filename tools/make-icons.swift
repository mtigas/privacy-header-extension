// Render the app and extension icons from design/icon.svg.
//
// Uses only what macOS ships: AppKit loads the SVG (CoreSVG) and CoreGraphics
// rasterizes it, so there is nothing to install. SVG filters are not supported
// by CoreSVG and are ignored; the artwork does not depend on them.
//
// The same artwork is framed three ways:
// - full-bleed square: the iOS app icon. iOS applies its own mask, and App Store
//   Connect rejects an alpha channel in this slot, so it is written without one.
// - rounded square, edge to edge: the extension icons (manifest `icons` and
//   `default_icon`) and the images the app shows in-app.
// - macOS app icon: the rounded square inset on the canvas (Apple's 824/1024
//   grid) with a soft drop shadow, as macOS has expected since Big Sur.
//
// Usage: swift tools/make-icons.swift [extension/icons] [apple/GPC Switch/Shared (App)]

import AppKit
import Foundation

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let svgURL = scriptDir.appendingPathComponent("../design/icon.svg").standardizedFileURL
let extensionSizes = [48, 96, 128, 256, 512]
let macIconSizes = [16, 32, 128, 256, 512]   // each at @1x and @2x
let cornerFraction: CGFloat = 0.2237         // iOS/macOS icon corner radius, as a fraction of the size

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("error: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

guard let artwork = NSImage(contentsOf: svgURL) else { fail("cannot load \(svgURL.path)") }

enum Frame { case square, rounded, mac }

func render(_ size: Int, as frame: Frame) -> Data {
    let alpha = frame != .square
    let info: CGImageAlphaInfo = alpha ? .premultipliedLast : .noneSkipLast
    guard let cg = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info.rawValue)
    else { fail("cannot create a \(size)px bitmap") }
    cg.interpolationQuality = .high

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let artRect: CGRect
    switch frame {
    case .square, .rounded:
        artRect = canvas
    case .mac:
        artRect = canvas.insetBy(dx: canvas.width * 100 / 1024, dy: canvas.height * 100 / 1024)
    }
    let radius = artRect.width * cornerFraction
    let shape = CGPath(roundedRect: artRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    if frame == .mac {
        // Shadow under the icon shape, drawn before clipping to it.
        cg.saveGState()
        let s = canvas.width / 1024
        cg.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s,
                     color: CGColor(gray: 0, alpha: 0.35))
        cg.addPath(shape)
        cg.setFillColor(CGColor(gray: 0, alpha: 1))
        cg.fillPath()
        cg.restoreGState()
    }
    if frame != .square {
        cg.addPath(shape)
        cg.clip()
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
    artwork.draw(in: artRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    guard let image = cg.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fail("cannot encode PNG") }
    return png
}

func write(_ data: Data, to path: URL, note: String) {
    do {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: path)
    } catch {
        fail("cannot write \(path.path): \(error)")
    }
    print("\(path.relativePath)  \(note)")
}

let args = Array(CommandLine.arguments.dropFirst())
let extensionDir = URL(fileURLWithPath: args.first ?? "extension/icons")
var rendered: [Int: Data] = [:]
for size in extensionSizes {
    let data = render(size, as: .rounded)
    rendered[size] = data
    write(data, to: extensionDir.appendingPathComponent("icon-\(size).png"), note: "\(size)x\(size) rounded")
}

if args.count > 1 {
    let app = URL(fileURLWithPath: args[1])
    let iconset = app.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
    write(render(1024, as: .square), to: iconset.appendingPathComponent("universal-icon-1024@1x.png"),
          note: "1024x1024 opaque")
    for size in macIconSizes {
        for scale in [1, 2] {
            let px = size * scale
            write(render(px, as: .mac), to: iconset.appendingPathComponent("mac-icon-\(size)@\(scale)x.png"),
                  note: "\(px)x\(px) mac")
        }
    }
    write(rendered[512]!, to: app.appendingPathComponent("Assets.xcassets/LargeIcon.imageset/icon-512.png"),
          note: "512x512 rounded")
}
