import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: DMGBackground.swift /path/to/arrow.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 640
let height = 360
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    fputs("Unable to create drawing context\n", stderr)
    exit(1)
}

context.setFillColor(CGColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// A filled polygon keeps the shaft horizontal and the arrow head symmetric
// after Finder scales the background image.
context.setFillColor(CGColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 0.72))
let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: 250, y: 174))
arrowPath.addLine(to: CGPoint(x: 350, y: 174))
arrowPath.addLine(to: CGPoint(x: 350, y: 150))
arrowPath.addLine(to: CGPoint(x: 390, y: 180))
arrowPath.addLine(to: CGPoint(x: 350, y: 210))
arrowPath.addLine(to: CGPoint(x: 350, y: 186))
arrowPath.addLine(to: CGPoint(x: 250, y: 186))
arrowPath.closeSubpath()
context.addPath(arrowPath)
context.fillPath()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
          outputURL as CFURL,
          UTType.png.identifier as CFString,
          1,
          nil
      ) else {
    fputs("Unable to create PNG destination\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to finalize PNG\n", stderr)
    exit(1)
}
