// Generates the 1024×1024 ChoreQuest app icon (violet gradient + white check)
// using CoreGraphics — no Xcode or third-party tools required.
//
// Run from the repo root:
//     swift tools/AppIconGenerator.swift
//
// Writes: ChoreQuest/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let pixels = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    // No alpha channel — app icons must be fully opaque (avoids actool warnings).
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Could not create CGContext")
}

let s = CGFloat(pixels)

// Background: violet gradient (matches the app accent).
let top = CGColor(colorSpace: colorSpace, components: [0.56, 0.43, 1.00, 1.0])!
let bottom = CGColor(colorSpace: colorSpace, components: [0.36, 0.24, 0.96, 1.0])!
let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, bottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

// Soft highlight for depth.
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.10])!)
ctx.fillEllipse(in: CGRect(x: s * 0.10, y: s * 0.40, width: s * 0.95, height: s * 0.95))

// White checkmark (coordinates are y-up).
ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!)
ctx.setLineWidth(s * 0.095)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.beginPath()
ctx.move(to: CGPoint(x: s * 0.30, y: s * 0.52))
ctx.addLine(to: CGPoint(x: s * 0.45, y: s * 0.37))
ctx.addLine(to: CGPoint(x: s * 0.72, y: s * 0.66))
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("Could not render image") }

let outURL = URL(fileURLWithPath: "ChoreQuest/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
guard let destination = CGImageDestinationCreateWithURL(
    outURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fatalError("Could not create image destination")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write PNG") }

print("Wrote \(outURL.path)")
