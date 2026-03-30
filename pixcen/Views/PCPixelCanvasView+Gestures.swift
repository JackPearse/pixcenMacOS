//
//  PCPixelCanvasView+Gestures.swift
//  pixcen
//
//  Zoom/pan gesture handling and coordinate conversion.
//

import Cocoa
import MetalKit
import simd

extension PCPixelCanvasView {

    // MARK: - Scroll Wheel
    //
    // Auto-detect input device:
    //   Trackpad (hasPreciseScrollingDeltas): two-finger = pan, pinch = zoom
    //   Mouse wheel (no precise deltas): scroll = zoom
    //   Cmd + scroll: always zoom
    //
    // User can override via Preferences (inputMode: "trackpad" or "mouse"):
    //   Mouse mode: all scroll = zoom (even trackpad)
    //   Trackpad mode: precise scroll = pan, non-precise = zoom

    override func scrollWheel(with event: NSEvent) {
        let inputMode = UserDefaults.standard.string(forKey: "inputMode") ?? "trackpad"
        let isCmd = event.modifierFlags.contains(.command)

        let wantsPan: Bool
        if isCmd {
            wantsPan = false  // Cmd+scroll always zooms
        } else if inputMode == "mouse" {
            wantsPan = false  // Mouse mode: scroll always zooms
        } else {
            wantsPan = event.hasPreciseScrollingDeltas  // Trackpad mode: auto-detect
        }

        if wantsPan {
            let retina = Float(drawableSize.width / bounds.size.width)
            let z = zoomLevel * retina
            let pw = Float(m_pbm.pixelWidth)

            panOffset.x -= Float(event.scrollingDeltaX) * retina / (z * pw)
            panOffset.y -= Float(event.scrollingDeltaY) * retina / z
            clampPan()
        } else {
            let delta = event.scrollingDeltaY
            guard delta != 0 else { return }
            let factor: Float = 1.0 + Float(delta) * 0.02
            zoomCentered(by: factor, at: event)
        }
    }

    // MARK: - Pinch (magnify = zoom)

    override func magnify(with event: NSEvent) {
        let factor: Float = 1.0 + Float(event.magnification)
        zoomCentered(by: factor, at: event)
    }

    // MARK: - Zoom keeping mouse point stable

    func zoomCentered(by factor: Float, at event: NSEvent) {
        let mouseInView = convert(event.locationInWindow, from: nil)

        // 1. Find C64 pixel under mouse BEFORE zoom
        let retina = Float(drawableSize.width / bounds.size.width)
        let screenX = Float(mouseInView.x) * retina
        let screenY = Float(mouseInView.y) * retina
        let zOld = zoomLevel * retina
        let pw = Float(m_pbm.pixelWidth)

        let c64X = screenX / (zOld * pw) + panOffset.x
        let c64Y = screenY / zOld + panOffset.y

        // 2. Apply zoom change
        let newZoom = (zoomLevel * factor).clamped(to: zoomMin...zoomMax)
        zoomLevel = newZoom

        // 3. Recalculate pan so same C64 pixel stays under mouse
        let zNew = zoomLevel * retina
        panOffset.x = c64X - screenX / (zNew * pw)
        panOffset.y = c64Y - screenY / zNew

        clampPan()

        // Update status bar with new zoom level
        if let pix = getPixelFromPoint(mouseInView) {
            updateStatus(pix: CGPoint(x: CGFloat(pix.x), y: CGFloat(pix.y)))
        }
    }

    // MARK: - Clamp pan

    func clampPan() {
        let bufW = Float(m_pbm.sizeX)
        let bufH = Float(m_pbm.sizeY)

        // How many C64 pixels fit in the viewport at current zoom
        let retina = Float(drawableSize.width / bounds.size.width)
        let z = zoomLevel * retina
        let pw = Float(m_pbm.pixelWidth)
        let viewC64W = Float(drawableSize.width) / (z * pw)
        let viewC64H = Float(drawableSize.height) / z

        // Clamp so the image never fully leaves the viewport.
        // Minimum: right/bottom edge of image stays at left/top edge of viewport
        // Maximum: left/top edge of image stays at right/bottom edge of viewport
        let minX = -(viewC64W - 1)
        let maxX = bufW - 1
        let minY = -(viewC64H - 1)
        let maxY = bufH - 1

        panOffset.x = panOffset.x.clamped(to: minX...maxX)
        panOffset.y = panOffset.y.clamped(to: minY...maxY)
    }

    // MARK: - Screen to C64 pixel coordinate

    func getPixelFromPoint(_ pointInView: CGPoint) -> (x: Int, y: Int)? {
        let retina = Float(drawableSize.width / bounds.size.width)
        let screenX = Float(pointInView.x) * retina
        let screenY = Float(pointInView.y) * retina
        let z = zoomLevel * retina
        let pw = Float(m_pbm.pixelWidth)

        let bufX = Int(screenX / (z * pw) + panOffset.x)
        let bufY = Int(screenY / z + panOffset.y)

        guard bufX >= 0, bufX < m_pbm.canvasModel.xsize,
              bufY >= 0, bufY < m_pbm.canvasModel.ysize else {
            return nil
        }

        return (bufX, bufY)
    }

    // MARK: - Screen to cell coordinate

    func getCellFromPoint(_ pointInView: CGPoint) -> (cx: Int, cy: Int)? {
        guard let pix = getPixelFromPoint(pointInView) else {
            return nil
        }

        let cx = pix.x / m_pbm.cellSizeX
        let cy = pix.y / m_pbm.cellSizeY

        return (cx, cy)
    }
}

// MARK: - Float clamped helper

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
