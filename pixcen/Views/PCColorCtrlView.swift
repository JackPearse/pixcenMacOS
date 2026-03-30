//
//  PCColorCtrlView.swift
//  pixcen
//
//  Cell color control panel - shows the colors of the cell under the mouse cursor.
//  Mirrors the original Windows CColorCtrl layout:
//    0  [color swatch]     ← mask 0: background
//    1  [color swatch]     ← mask 1: screen high nibble
//    2  [color swatch]     ← mask 2: screen low nibble
//    3  [color swatch]     ← mask 3: color RAM
//    Ex [hatched]          ← mask 4-5: extra (unused in MC bitmap)
//    Bd [color swatch]     ← border color
//

import Cocoa

class PCColorCtrlView: PCToolView {

    private var cellColors: [UInt8] = Array(repeating: 0xff, count: 6)
    private var cellCrippled: [Int] = Array(repeating: 0, count: 6)
    private var borderColorIdx: Int32 = 0
    private var cellCoord = ""

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onCellHover(_:)),
            name: .pixcenCellHover,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func onCellHover(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let info = userInfo["cellInfo"] as? CellInfo,
              let cx = userInfo["cx"] as? Int,
              let cy = userInfo["cy"] as? Int else { return }

        cellColors = info.col
        cellCrippled = info.crippled
        cellCoord = "Cell \(cx),\(cy)"

        // Get border color from the canvas
        if let delegate = NSApp.delegate as? AppDelegate,
           let canvas = delegate.pixelCanvasView {
            borderColorIdx = canvas.m_pbm.borderColor
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let palette = C64Col.shared
        let w = bounds.width
        let rowHeight: CGFloat = (bounds.height - 20) / 6.0  // 6 rows
        let swatchSize: CGFloat = min(rowHeight - 8, w * 0.45)
        let labelX: CGFloat = 8
        let swatchX: CGFloat = w - swatchSize - 8

        let labels = ["0", "1", "2", "3", "Ex", "Bd"]

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        ]

        for i in 0..<6 {
            let y = CGFloat(i) * rowHeight + 4

            // Draw label
            let labelRect = NSRect(x: labelX, y: y + (rowHeight - 20) / 2, width: 30, height: 20)
            labels[i].draw(in: labelRect, withAttributes: labelAttrs)

            // Swatch rect
            let swatchRect = NSRect(
                x: swatchX,
                y: y + (rowHeight - swatchSize) / 2,
                width: swatchSize,
                height: swatchSize
            )

            if i == 5 {
                // Border color
                let borderColor = palette.color[Int(borderColorIdx & 0x0f)]
                drawColorSwatch(in: swatchRect, color: borderColor, crippled: false, unused: false)
            } else if i == 4 {
                // Extra - unused in MC bitmap
                let col = cellColors[i]
                if col == 0xff {
                    drawHatchedSwatch(in: swatchRect)
                } else {
                    let c = palette.color[Int(col & 0x0f)]
                    drawColorSwatch(in: swatchRect, color: c, crippled: false, unused: false)
                }
            } else {
                // Masks 0-3
                let col = cellColors[i]
                if col == 0xff {
                    drawHatchedSwatch(in: swatchRect)
                } else if col == 0xfe {
                    // Mixed colors in cell range
                    drawMixedSwatch(in: swatchRect)
                } else {
                    let c = palette.color[Int(col & 0x0f)]
                    let isCrippled = cellCrippled[i] != 0
                    drawColorSwatch(in: swatchRect, color: c, crippled: isCrippled, unused: false)
                }
            }
        }

        // Cell coordinate at the bottom
        let coordAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.systemFont(ofSize: 10)
        ]
        let coordRect = NSRect(x: 0, y: bounds.height - 16, width: w, height: 14)
        let coordStyle = NSMutableParagraphStyle()
        coordStyle.alignment = .center
        var attrs = coordAttrs
        attrs[.paragraphStyle] = coordStyle
        cellCoord.draw(in: coordRect, withAttributes: attrs)
    }

    // MARK: - Swatch Drawing

    private func drawColorSwatch(in rect: NSRect, color: NSColor, crippled: Bool, unused: Bool) {
        let path = NSBezierPath(ovalIn: rect)
        color.setFill()
        path.fill()

        // Border around swatch
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        // Crippled indicator: diagonal strike-through line
        if crippled {
            NSColor.labelColor.withAlphaComponent(0.6).setStroke()
            let line = NSBezierPath()
            line.move(to: NSPoint(x: rect.minX + 2, y: rect.minY + 2))
            line.line(to: NSPoint(x: rect.maxX - 2, y: rect.maxY - 2))
            line.lineWidth = 2
            line.stroke()
        }
    }

    private func drawHatchedSwatch(in rect: NSRect) {
        // Light background
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(ovalIn: rect).fill()

        // Diagonal hatch lines
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: rect).addClip()

        NSColor.separatorColor.setStroke()
        let spacing: CGFloat = 5
        let line = NSBezierPath()
        line.lineWidth = 1

        var x = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            line.move(to: NSPoint(x: x, y: rect.minY))
            line.line(to: NSPoint(x: x + rect.height, y: rect.maxY))
            x += spacing
        }
        line.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // Border
        NSColor.separatorColor.setStroke()
        NSBezierPath(ovalIn: rect).stroke()
    }

    private func drawMixedSwatch(in rect: NSRect) {
        // Half-and-half pattern for mixed colors
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(ovalIn: rect).fill()

        let questionAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: rect.height * 0.5)
        ]
        let textSize = "?" as NSString
        let size = textSize.size(withAttributes: questionAttrs)
        let textRect = NSRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        textSize.draw(in: textRect, withAttributes: questionAttrs)

        NSColor.separatorColor.setStroke()
        NSBezierPath(ovalIn: rect).stroke()
    }
}
