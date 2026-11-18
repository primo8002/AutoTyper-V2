import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func render(_ size: Int) -> Data {
 let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState()
 NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
 let scale = CGFloat(size) / 1024
 let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
 let tile = NSBezierPath(roundedRect: NSRect(x:32,y:32,width:960,height:960), xRadius:220,yRadius:220)
 NSGradient(starting:NSColor(red:1,green:0.58,blue:0.37,alpha:1),ending:NSColor(red:0.87,green:0.33,blue:0.18,alpha:1))!.draw(in:tile,angle:270)
 NSColor(red:1,green:0.973,blue:0.93,alpha:1).setFill()
 let a = NSBezierPath(); a.windingRule = .evenOdd
 a.move(to:NSPoint(x:205,y:298)); a.line(to:NSPoint(x:393,y:744)); a.line(to:NSPoint(x:506,y:744)); a.line(to:NSPoint(x:694,y:298)); a.line(to:NSPoint(x:574,y:298)); a.line(to:NSPoint(x:539,y:390)); a.line(to:NSPoint(x:357,y:390)); a.line(to:NSPoint(x:322,y:298)); a.close()
 a.move(to:NSPoint(x:394,y:489)); a.line(to:NSPoint(x:502,y:489)); a.line(to:NSPoint(x:448,y:636)); a.close(); a.fill()
 NSBezierPath(roundedRect:NSRect(x:742,y:300,width:42,height:428),xRadius:21,yRadius:21).fill()
 for y in [CGFloat(710),CGFloat(282)] { NSBezierPath(roundedRect:NSRect(x:690,y:y,width:146,height:35),xRadius:17,yRadius:17).fill() }
 NSGraphicsContext.restoreGraphicsState()
 return bitmap.representation(using:.png,properties:[:])!
}
let iconset = root.appendingPathComponent("assets/AutoTyper.iconset")
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
 try render(size).write(to:iconset.appendingPathComponent("icon_\(size)x\(size).png"))
 try render(size*2).write(to:iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
for size in [16,32,48,128] { try render(size).write(to:root.appendingPathComponent("browser-extension/icons/icon-\(size).png")) }
try render(512).write(to:root.appendingPathComponent("assets/AutoTyper.png"))
