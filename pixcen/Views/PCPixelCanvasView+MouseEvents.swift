//
//  PCPixelCanvasView+MouseEvents.swift
//  pixcen
//
//  Mouse down/up/drag handlers for painting and interaction.
//

import Cocoa

extension PCPixelCanvasView {

    // MARK: - Tracking Area

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        // Remove old tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        guard newWindow != nil else { return }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        let trackingArea = NSTrackingArea(rect: .zero,
                                          options: options,
                                          owner: self,
                                          userInfo: nil)
        addTrackingArea(trackingArea)
    }

    // MARK: - Enter / Exit

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
    }

    // MARK: - Mouse Moved

    override func mouseMoved(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)

        if let cell = getCellFromPoint(locationInView) {
            // Get full cell color info for the palette view
            var info = CellInfo()
            m_pbm.cellInfo(cx: cell.cx, cy: cell.cy, w: 1, h: 1, info: &info)

            NotificationCenter.default.post(
                name: .pixcenCellHover,
                object: nil,
                userInfo: [
                    "cx": cell.cx,
                    "cy": cell.cy,
                    "cellInfo": info
                ]
            )
        }

        if let pix = getPixelFromPoint(locationInView) {
            updateStatus(pix: CGPoint(x: CGFloat(pix.x), y: CGFloat(pix.y)))
        }
    }

    // MARK: - Left Mouse Button
    // Option+click = start selection, normal click = paint

    override func mouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)

        guard let pix = getPixelFromPoint(locationInView) else {
            return
        }

        // Option+click = start selection
        if event.modifierFlags.contains(.option) {
            isSelecting = true
            selectionStart = pix
            selectionEnd = pix
            return
        }

        // If in paste mode, click confirms paste at this position
        if m_Paste, let pasteBuffer = m_pPasteBuffer {
            m_pbm.beginHistory()
            for y in 0..<m_PasteSizeY {
                for x in 0..<m_PasteSizeX {
                    let destX = pix.x + x
                    let destY = pix.y + y
                    guard destX >= 0, destX < m_pbm.sizeX,
                          destY >= 0, destY < m_pbm.sizeY else { continue }
                    let col = pasteBuffer[y * m_PasteSizeX + x]
                    if m_MaskedPaste && col == UInt8(m_Col2) { continue }
                    m_pbm.setPixel(destX, destY, col)
                }
            }
            m_pbm.endHistory()
            m_Paste = false
            refreshStatus()
            return
        }

        // Clear selection on normal click
        if selectionStart != nil {
            selectionStart = nil
            selectionEnd = nil
            isSelecting = false
        }

        if m_ColorPick {
            m_Col1 = Int(m_pbm.pixel(pix.x, pix.y))
            m_ColorPick = false
            return
        }

        if m_Fill {
            m_Fill = false
            let targetColor = m_pbm.pixel(pix.x, pix.y)
            if targetColor != UInt8(m_Col1) {
                m_pbm.beginHistory()
                floodFill(x: pix.x, y: pix.y, newColor: UInt8(m_Col1), targetColor: targetColor)
                m_pbm.endHistory()
            }
            return
        }

        m_pbm.beginHistory()
        m_pbm.setPixel(pix.x, pix.y, UInt8(m_Col1))
        m_LastPaintPix = CGPoint(x: pix.x, y: pix.y)
        m_Paint = true
    }

    override func mouseDragged(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)

        // Option+drag = extend selection
        if isSelecting {
            if let pix = getPixelFromPoint(locationInView) {
                selectionEnd = pix
            }
            return
        }

        guard let pix = getPixelFromPoint(locationInView), m_Paint else {
            return
        }

        let lastX = Int(m_LastPaintPix.x)
        let lastY = Int(m_LastPaintPix.y)

        if lastX != pix.x || lastY != pix.y {
            drawLine(from: (lastX, lastY), to: (pix.x, pix.y), color: UInt8(m_Col1))
            m_LastPaintPix = CGPoint(x: pix.x, y: pix.y)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isSelecting {
            isSelecting = false
            if let sel = selectionRect {
                m_MarkerCount = 2
                m_Marker = true
                if m_CellSnapMarker {
                    let cw = m_pbm.cellSizeX
                    let ch = m_pbm.cellSizeY
                    selectionStart = (x: (sel.x / cw) * cw, y: (sel.y / ch) * ch)
                    let endX = ((sel.x + sel.w - 1) / cw + 1) * cw - 1
                    let endY = ((sel.y + sel.h - 1) / ch + 1) * ch - 1
                    selectionEnd = (x: min(endX, m_pbm.sizeX - 1),
                                    y: min(endY, m_pbm.sizeY - 1))
                }
            }
            refreshStatus()
            return
        }
        if m_Paint {
            m_pbm.endHistory()
            m_Paint = false
        }
    }

    // MARK: - Right Mouse Button

    override func rightMouseDown(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)

        guard let pix = getPixelFromPoint(locationInView) else {
            return
        }

        if m_ColorPick {
            m_Col2 = Int(m_pbm.pixel(pix.x, pix.y))
            m_ColorPick = false
            return
        }

        if m_Fill {
            m_Fill = false
            let targetColor = m_pbm.pixel(pix.x, pix.y)
            if targetColor != UInt8(m_Col2) {
                m_pbm.beginHistory()
                floodFill(x: pix.x, y: pix.y, newColor: UInt8(m_Col2), targetColor: targetColor)
                m_pbm.endHistory()
            }
            return
        }

        m_pbm.beginHistory()
        m_pbm.setPixel(pix.x, pix.y, UInt8(m_Col2))
        m_LastPaintPix = CGPoint(x: pix.x, y: pix.y)
        m_Paint = true
    }

    override func rightMouseDragged(with event: NSEvent) {
        let locationInView = convert(event.locationInWindow, from: nil)

        guard let pix = getPixelFromPoint(locationInView), m_Paint else {
            return
        }

        let lastX = Int(m_LastPaintPix.x)
        let lastY = Int(m_LastPaintPix.y)

        if lastX != pix.x || lastY != pix.y {
            drawLine(from: (lastX, lastY), to: (pix.x, pix.y), color: UInt8(m_Col2))
            m_LastPaintPix = CGPoint(x: pix.x, y: pix.y)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        if m_Paint {
            m_pbm.endHistory()
            m_Paint = false
        }
    }

    // MARK: - Status update

    func updateStatus(pix: CGPoint!) {
        guard let pix = pix else { return }

        let overflowTag: String
        switch m_pbm.canvasModel.overflow {
        case .REPLACE:  overflowTag = "OVF: Rep"
        case .CLOSEST:  overflowTag = "OVF: Clo"
        case .NOTHING:  overflowTag = "OVF: Ign"
        }

        var txt: String
        if m_pbm.isChar {
            txt = String(format: "Z: %d/%d  X: %03d  Y: %03d  %@",
                         m_pbm.backBuffer + 1, m_pbm.backBufferCount,
                         Int(pix.x), Int(pix.y), overflowTag)
        } else {
            txt = String(format: "X: %03d  Y: %03d  Zoom: %.0f%%  %@",
                         Int(pix.x), Int(pix.y), zoomLevel * 100.0, overflowTag)
        }

        if let sel = selectionRect {
            txt += String(format: "  Sel: %d x %d at (%d, %d)", sel.w, sel.h, sel.x, sel.y)
        }

        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: "MSG_STATUS_TEXT"),
            object: nil,
            userInfo: [
                "status": txt,
                "hasPasteBuffer": m_pPasteBuffer != nil,
                "isPasting": m_Paste,
                "hasSelection": selectionRect != nil
            ]
        )
    }
}
