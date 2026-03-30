//
//  PCScrollIndicator.swift
//  pixcen
//
//  Thin always-visible scrollbar indicators overlaid on the canvas.
//  These are pure display widgets - not interactive scroll views.
//  They show the current pan position relative to the document.
//

import Cocoa

class PCScrollIndicator: NSView {

    enum Orientation {
        case horizontal
        case vertical
    }

    let orientation: Orientation

    /// Visible fraction (0..1). 1.0 = entire document visible, 0.1 = 10% visible.
    var visibleFraction: CGFloat = 1.0 { didSet { needsDisplay = true } }

    /// Position (0..1). 0.0 = start, 1.0 = end.
    var position: CGFloat = 0.0 { didSet { needsDisplay = true } }

    // Thin, subtle styling to communicate "indicator, not interactive"
    private let barColor = NSColor.white.withAlphaComponent(0.25)
    private let trackColor = NSColor.clear
    private let barThickness: CGFloat = 3
    private let cornerRadius: CGFloat = 1.5

    init(orientation: Orientation) {
        self.orientation = orientation
        super.init(frame: .zero)
        wantsLayer = true
        layer?.zPosition = 100  // Always on top
    }

    required init?(coder: NSCoder) {
        self.orientation = .horizontal
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw track
        trackColor.setFill()
        let trackRect = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        trackRect.fill()

        // Calculate thumb rect
        let fraction = max(0.05, min(1.0, visibleFraction))
        let pos = max(0.0, min(1.0 - fraction, position))

        let thumbRect: NSRect
        if orientation == .horizontal {
            let thumbWidth = bounds.width * fraction
            let thumbX = bounds.width * pos
            thumbRect = NSRect(x: thumbX, y: 0, width: thumbWidth, height: bounds.height)
        } else {
            let thumbHeight = bounds.height * fraction
            let thumbY = bounds.height * pos
            thumbRect = NSRect(x: 0, y: thumbY, width: bounds.width, height: thumbHeight)
        }

        // Draw thumb
        barColor.setFill()
        let thumbPath = NSBezierPath(roundedRect: thumbRect, xRadius: cornerRadius, yRadius: cornerRadius)
        thumbPath.fill()
    }

    /// Update from canvas pan/zoom state
    func update(panOffset: Float, zoomLevel: Float, bufferSize: Float, viewportSize: Float, pixelWidth: Float) {
        // How many C64 pixels are visible in this dimension
        let visibleC64Pixels: Float
        if orientation == .horizontal {
            visibleC64Pixels = viewportSize / (zoomLevel * pixelWidth)
        } else {
            visibleC64Pixels = viewportSize / zoomLevel
        }

        let fraction = visibleC64Pixels / bufferSize
        visibleFraction = CGFloat(min(1.0, max(0.05, fraction)))

        // Position: panOffset / bufferSize (clamped)
        let maxPan = bufferSize - visibleC64Pixels
        if maxPan > 0 {
            position = CGFloat(max(0, min(1.0, panOffset / maxPan)) * (1.0 - Float(visibleFraction)))
        } else {
            position = 0
        }
    }
}
