import AppKit

let size = 1024
let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let green = NSColor(red: 0.16, green: 0.72, blue: 0.47, alpha: 1)
NSGradient(colors: [green, NSColor(red: 0.08, green: 0.45, blue: 0.36, alpha: 1)])!.draw(in: bounds, angle: -60)

let bubble = NSBezierPath(roundedRect: NSRect(x: 176, y: 300, width: 672, height: 480), xRadius: 140, yRadius: 140)
let tail = NSBezierPath()
tail.move(to: NSPoint(x: 300, y: 330))
tail.line(to: NSPoint(x: 240, y: 190))
tail.line(to: NSPoint(x: 430, y: 310))
tail.close()
bubble.append(tail)
NSColor.white.setFill()
bubble.fill()

green.setFill()
NSBezierPath(ovalIn: NSRect(x: 420, y: 448, width: 184, height: 184)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
