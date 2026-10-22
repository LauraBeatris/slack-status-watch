import AppKit

let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: Int, alpha: Double = 1) -> NSColor {
  NSColor(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: alpha)
}

func fillRounded(_ rect: NSRect, radius: CGFloat, _ fill: NSColor) {
  fill.setFill()
  NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

NSGradient(colors: [color(0x4A154B), color(0x2E0B30)])!.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: -70)

fillRounded(NSRect(x: 112, y: 382, width: 800, height: 260), radius: 130, .white)
fillRounded(NSRect(x: 380, y: 532, width: 400, height: 50), radius: 25, color(0xD9D4DA))
fillRounded(NSRect(x: 380, y: 444, width: 260, height: 50), radius: 25, color(0xD9D4DA, alpha: 0.6))

let emoji = NSAttributedString(string: "🍔", attributes: [.font: NSFont(name: "Apple Color Emoji", size: 170)!])
let emojiSize = emoji.size()
emoji.draw(at: NSPoint(x: 252 - emojiSize.width / 2, y: 512 - emojiSize.height / 2 - 7))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
