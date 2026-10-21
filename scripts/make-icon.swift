import AppKit
import Foundation

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"
let fileManager = FileManager.default
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("DiskPulse.iconset", isDirectory: true)

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2)
]

func renderIcon(pixels: Int) -> Data? {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)

    let size = CGFloat(pixels)
    let inset = size * 0.06
    let bodyRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = size * 0.22
    let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)

    bodyPath.addClip()

    if let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.10, green: 0.42, blue: 0.92, alpha: 1),
        NSColor(srgbRed: 0.06, green: 0.72, blue: 0.58, alpha: 1)
    ]) {
        gradient.draw(in: bodyRect, angle: -50)
    }

    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(rect: NSRect(x: inset, y: size * 0.55, width: size, height: size * 0.45)).fill()

    if let symbol = NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: nil) {
        let configuration = NSImage.SymbolConfiguration(pointSize: size * 0.44, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

        if let configured = symbol.withSymbolConfiguration(configuration) {
            let symbolSize = configured.size
            let origin = NSPoint(
                x: (size - symbolSize.width) / 2,
                y: (size - symbolSize.height) / 2
            )
            configured.draw(in: NSRect(origin: origin, size: symbolSize))
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return representation.representation(using: .png, properties: [:])
}

for variant in variants {
    let pixels = variant.points * variant.scale
    guard let data = renderIcon(pixels: pixels) else { continue }
    let suffix = variant.scale == 2 ? "@2x" : ""
    let name = "icon_\(variant.points)x\(variant.points)\(suffix).png"
    try data.write(to: iconsetURL.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputPath]

try process.run()
process.waitUntilExit()
try? fileManager.removeItem(at: iconsetURL)

guard process.terminationStatus == 0 else {
    print("iconutil failed with status \(process.terminationStatus)")
    exit(1)
}

print("Generated \(outputPath)")
