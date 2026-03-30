//
//  ImageImporter.swift
//  pixcen
//
//  Imports BMP/PNG/JPG/GIF images into C64 format with color reduction.
//  Converts RGB pixels to the closest C64 palette colors while respecting
//  the per-cell color constraints of each C64 graphics mode.
//

import Cocoa

struct ImageImporter {

    /// Import an image file into a multicolor bitmap (160x200, 4 colors per cell)
    static func importToMCBitmap(_ image: NSImage, palette: C64Col) throws -> PCMCBitmap {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw C64InterfaceError.failed(0, "Could not convert image")
        }

        let bitmap = try PCMCBitmap()
        let srcWidth = cgImage.width
        let srcHeight = cgImage.height

        // Render source image to a 160x200 RGBA buffer
        let destW = 160
        let destH = 200
        let rgba = renderToRGBA(cgImage, width: destW, height: destH)

        // First pass: find the most common color across all cells for the background
        let bgColor = findGlobalBackgroundColor(rgba: rgba, width: destW, height: destH,
                                                 cellW: 4, cellH: 8, palette: palette)
        bitmap.canvasModel.background![0] = bgColor

        // Second pass: for each 4x8 cell, find the best 3 additional colors
        let cellCountX = destW / 4
        let cellCountY = destH / 8

        for cy in 0..<cellCountY {
            for cx in 0..<cellCountX {
                let cellColors = findBestCellColors(
                    rgba: rgba, width: destW,
                    cellX: cx * 4, cellY: cy * 8,
                    cellW: 4, cellH: 8,
                    fixedColor: bgColor, maxColors: 3,
                    palette: palette
                )

                let ci = cy * cellCountX + cx

                // Assign cell colors to screen RAM and color RAM
                if cellColors.count > 0 {
                    let screenHigh = cellColors[0]
                    bitmap.canvasModel.screen![ci] = (bitmap.canvasModel.screen![ci] & 0x0f) | (screenHigh << 4)
                }
                if cellColors.count > 1 {
                    let screenLow = cellColors[1]
                    bitmap.canvasModel.screen![ci] = (bitmap.canvasModel.screen![ci] & 0xf0) | (screenLow & 0x0f)
                }
                if cellColors.count > 2 {
                    bitmap.canvasModel.color![ci] = cellColors[2] & 0x0f
                }

                // Map each pixel to the nearest allowed color
                let allowedColors = [bgColor] + cellColors
                for py in 0..<8 {
                    for px in 0..<4 {
                        let x = cx * 4 + px
                        let y = cy * 8 + py
                        let offset = (y * destW + x) * 4
                        let r = rgba[offset]
                        let g = rgba[offset + 1]
                        let b = rgba[offset + 2]

                        let bestMask = findClosestMask(r: r, g: g, b: b,
                                                       allowedColors: allowedColors,
                                                       palette: palette)
                        // Set 2-bit pixel value in map
                        let mi = cy * destW * 2 + cx * 8 + py
                        let shift = 2 * (3 - px)
                        let filterMask: UInt8 = ~(3 << shift)
                        bitmap.canvasModel.map![mi] = (bitmap.canvasModel.map![mi] & filterMask) | (UInt8(bestMask) << shift)
                    }
                }
            }
        }

        bitmap.canvasModel.border!.pointee = bitmap.guessBorderColor()
        return bitmap
    }

    /// Import an image into a hires bitmap (320x200, 2 colors per cell)
    static func importToBitmap(_ image: NSImage, palette: C64Col) throws -> PCBitmap {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw C64InterfaceError.failed(0, "Could not convert image")
        }

        let bitmap = try PCBitmap()
        let destW = 320
        let destH = 200
        let rgba = renderToRGBA(cgImage, width: destW, height: destH)

        let cellCountX = destW / 8
        let cellCountY = destH / 8

        for cy in 0..<cellCountY {
            for cx in 0..<cellCountX {
                // Find 2 best colors for this 8x8 cell
                let cellColors = findBestCellColors(
                    rgba: rgba, width: destW,
                    cellX: cx * 8, cellY: cy * 8,
                    cellW: 8, cellH: 8,
                    fixedColor: nil, maxColors: 2,
                    palette: palette
                )

                let ci = cy * cellCountX + cx
                let color0 = cellColors.count > 0 ? cellColors[0] : 0
                let color1 = cellColors.count > 1 ? cellColors[1] : 1
                bitmap.canvasModel.screen![ci] = (color1 << 4) | (color0 & 0x0f)

                // Map each pixel
                let allowedColors = [color0, color1]
                for py in 0..<8 {
                    for px in 0..<8 {
                        let x = cx * 8 + px
                        let y = cy * 8 + py
                        let offset = (y * destW + x) * 4
                        let r = rgba[offset]
                        let g = rgba[offset + 1]
                        let b = rgba[offset + 2]

                        let bestMask = findClosestMask(r: r, g: g, b: b,
                                                       allowedColors: allowedColors,
                                                       palette: palette)
                        // Set 1-bit pixel value
                        let mi = cy * destW + cx * 8 + py
                        let shift = 7 - px
                        let filterMask: UInt8 = ~(UInt8(1) << shift)
                        bitmap.canvasModel.map![mi] = (bitmap.canvasModel.map![mi] & filterMask) | (UInt8(bestMask) << shift)
                    }
                }
            }
        }

        if bitmap.canvasModel.border != nil {
            bitmap.canvasModel.border!.pointee = bitmap.guessBorderColor()
        }
        return bitmap
    }

    // MARK: - Private helpers

    /// Render a CGImage to an RGBA byte array at the specified dimensions
    private static func renderToRGBA(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    /// Color distance using weighted CIE formula (same as original C++)
    private static func colorDistance(r1: UInt8, g1: UInt8, b1: UInt8,
                                      r2: UInt8, g2: UInt8, b2: UInt8) -> Int {
        let rmean = (Int(r1) + Int(r2)) / 2
        let r = Int(r1) - Int(r2)
        let g = Int(g1) - Int(g2)
        let b = Int(b1) - Int(b2)
        return (((512 + rmean) * r * r) >> 8) + 4 * g * g + (((767 - rmean) * b * b) >> 8)
    }

    /// Find the closest C64 color index for an RGB value
    private static func closestC64Color(r: UInt8, g: UInt8, b: UInt8, palette: C64Col) -> UInt8 {
        var bestIdx = 0
        var bestDist = Int.max
        for i in 0..<16 {
            let c = palette.color[i]
            let pr = UInt8(c.redComponent * 255)
            let pg = UInt8(c.greenComponent * 255)
            let pb = UInt8(c.blueComponent * 255)
            let dist = colorDistance(r1: r, g1: g, b1: b, r2: pr, g2: pg, b2: pb)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }
        return UInt8(bestIdx)
    }

    /// Find which mask index (into allowedColors) is closest to the given RGB
    private static func findClosestMask(r: UInt8, g: UInt8, b: UInt8,
                                         allowedColors: [UInt8], palette: C64Col) -> Int {
        var bestMask = 0
        var bestDist = Int.max
        for (mask, colorIdx) in allowedColors.enumerated() {
            let c = palette.color[Int(colorIdx & 0x0f)]
            let pr = UInt8(c.redComponent * 255)
            let pg = UInt8(c.greenComponent * 255)
            let pb = UInt8(c.blueComponent * 255)
            let dist = colorDistance(r1: r, g1: g, b1: b, r2: pr, g2: pg, b2: pb)
            if dist < bestDist {
                bestDist = dist
                bestMask = mask
            }
        }
        return bestMask
    }

    /// Find the most common C64 color across all cells (for background)
    private static func findGlobalBackgroundColor(rgba: [UInt8], width: Int, height: Int,
                                                   cellW: Int, cellH: Int,
                                                   palette: C64Col) -> UInt8 {
        var colorCounts = [Int](repeating: 0, count: 16)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let idx = closestC64Color(r: rgba[offset], g: rgba[offset+1], b: rgba[offset+2],
                                          palette: palette)
                colorCounts[Int(idx)] += 1
            }
        }
        return UInt8(colorCounts.enumerated().max(by: { $0.element < $1.element })!.offset)
    }

    /// Find the best N colors for a cell region (excluding fixedColor if provided)
    private static func findBestCellColors(rgba: [UInt8], width: Int,
                                            cellX: Int, cellY: Int,
                                            cellW: Int, cellH: Int,
                                            fixedColor: UInt8?,
                                            maxColors: Int,
                                            palette: C64Col) -> [UInt8] {
        var colorCounts = [Int](repeating: 0, count: 16)

        for py in 0..<cellH {
            for px in 0..<cellW {
                let x = cellX + px
                let y = cellY + py
                let offset = (y * width + x) * 4
                let idx = closestC64Color(r: rgba[offset], g: rgba[offset+1], b: rgba[offset+2],
                                          palette: palette)
                colorCounts[Int(idx)] += 1
            }
        }

        // Remove the fixed color from candidates
        if let fixed = fixedColor {
            colorCounts[Int(fixed)] = 0
        }

        // Return the top N most frequent colors
        let sorted = colorCounts.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(maxColors)
            .filter { $0.element > 0 }
            .map { UInt8($0.offset) }

        return Array(sorted)
    }
}
