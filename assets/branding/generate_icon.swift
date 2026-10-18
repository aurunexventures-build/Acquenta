import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for transparent in [false, true] {
 let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
 NSGraphicsContext.saveGraphicsState()
 NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
 if !transparent { NSColor(calibratedRed: 0.396, green: 0.329, blue: 0.753, alpha: 1).setFill(); NSRect(x:0,y:0,width:1024,height:1024).fill() }
 let path=NSBezierPath(); path.move(to: NSPoint(x:512,y:512))
 path.curve(to:NSPoint(x:270,y:650),controlPoint1:NSPoint(x:416,y:638),controlPoint2:NSPoint(x:353,y:674))
 path.curve(to:NSPoint(x:270,y:374),controlPoint1:NSPoint(x:133,y:612),controlPoint2:NSPoint(x:133,y:412))
 path.curve(to:NSPoint(x:754,y:650),controlPoint1:NSPoint(x:435,y:326),controlPoint2:NSPoint(x:589,y:698))
 path.curve(to:NSPoint(x:754,y:374),controlPoint1:NSPoint(x:891,y:612),controlPoint2:NSPoint(x:891,y:412))
 path.curve(to:NSPoint(x:512,y:512),controlPoint1:NSPoint(x:671,y:350),controlPoint2:NSPoint(x:608,y:386))
 path.lineWidth=70; path.lineCapStyle = .round; NSColor.white.setStroke();path.stroke()
 NSGraphicsContext.restoreGraphicsState()
 try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(transparent ? "metcue-foreground.png" : "metcue-icon.png"))
}
