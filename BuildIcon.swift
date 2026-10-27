import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func rounded(_ rect: NSRect, _ radius: CGFloat, _ color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let body = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 192, yRadius: 192)
        NSGradient(starting: NSColor(srgbRed: 0.28, green: 0.57, blue: 1, alpha: 1),
                   ending: NSColor(srgbRed: 0.22, green: 0.22, blue: 0.72, alpha: 1))!.draw(in: body, angle: -65)
        rounded(NSRect(x: 184, y: 480, width: 656, height: 230), 65, NSColor.white.withAlphaComponent(0.95))
        let ink = NSColor(srgbRed: 0.22, green: 0.36, blue: 0.78, alpha: 1)
        for x in [277, 460, 643] { rounded(NSRect(x: x, y: 548, width: 104, height: 94), 22, ink) }
        let arrows = NSBezierPath()
        arrows.lineWidth = 29
        arrows.lineCapStyle = .round
        arrows.lineJoinStyle = .round
        arrows.move(to: NSPoint(x: 250, y: 336)); arrows.line(to: NSPoint(x: 442, y: 336))
        arrows.move(to: NSPoint(x: 387, y: 391)); arrows.line(to: NSPoint(x: 442, y: 336)); arrows.line(to: NSPoint(x: 387, y: 281))
        arrows.move(to: NSPoint(x: 774, y: 336)); arrows.line(to: NSPoint(x: 582, y: 336))
        arrows.move(to: NSPoint(x: 637, y: 391)); arrows.line(to: NSPoint(x: 582, y: 336)); arrows.line(to: NSPoint(x: 637, y: 281))
        NSColor.white.setStroke(); arrows.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
