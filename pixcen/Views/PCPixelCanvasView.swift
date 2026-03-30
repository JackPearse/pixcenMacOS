//
//  PCPixelCanvasView.swift
//  pixcen
//
//  Created by Jack Pearse on 30.06.20.
//  Copyright (C) 2013  John Hammarberg (crt@nospam.censordesign.com)
//  Ported to MacOS in 2020-2026 by JackPearse (Drehwerk^Drehwerk)
//
//    This file is part of Pixcen.
//
//    Pixcen is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    Pixcen is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with Pixcen.  If not, see <http://www.gnu.org/licenses/>.

import Cocoa
import MetalKit
import simd

#if os(OSX) || os(iOS)
typealias OSView = MTKView
#endif

extension Notification.Name {
    static let pixcenCellHover = Notification.Name("pixcenCellHover")
}

class PCPixelCanvasView: OSView {

    var renderer: PixelCanvasRenderer!

    // Flipped coordinate system (origin top-left, like Windows and C64)
    override var isFlipped: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { return true }

    // MARK: - Bitmap
    var m_pbm: PCC64Interface = try! PCMCBitmap() {
        didSet {
            self.updateBorderColor()
        }
    }

    // MARK: - Zoom & Pan (continuous, shader-driven)
    var zoomLevel: Float = 2.0
    var panOffset: SIMD2<Float> = .zero
    var zoomMin: Float = 0.5
    var zoomMax: Float = 50.0

    // MARK: - Grid
    var m_Grid: Int = 1
    var m_CellGrid: Int = 1

    // MARK: - Active colors
    var m_Col1: Int = 1   // White
    var m_Col2: Int = 0   // Black

    // MARK: - Paint state
    var m_Paint: Bool = false
    var m_Fill: Bool = false
    var m_LastPaintPix: CGPoint = CGPoint(x: -1, y: -1)
    var m_ActivePaintCol: Int = 0

    // MARK: - Colour info
    var m_ShowColourInfo: Bool = false

    // MARK: - Paste state
    var m_Paste: Bool = false
    var m_MaskedPaste: Bool = false
    var m_pPasteBuffer: UnsafeMutablePointer<UInt8>?
    var m_PastePoint: CGPoint = CGPoint(x: -1, y: -1)
    var m_PasteSizeX: Int = 0
    var m_PasteSizeY: Int = 0

    // MARK: - Color picker
    var m_ColorPick: Bool = false

    // MARK: - Format
    var m_goodFormat: Bool = false

    // MARK: - Move
    var m_Move: Bool = false

    // MARK: - Selection / Marker
    var m_AutoMarker: Bool = false
    var m_ManualMarker: Bool = false
    var m_Marker: Bool = false
    var m_MarkerCount: Int = 0
    var m_CellSnapMarker: Bool = false

    /// Selection rectangle in C64 pixel coordinates (set by Option+drag)
    var selectionStart: (x: Int, y: Int)?
    var selectionEnd: (x: Int, y: Int)?
    var isSelecting: Bool = false

    /// Normalized selection rect (sorted so min < max)
    var selectionRect: (x: Int, y: Int, w: Int, h: Int)? {
        guard let s = selectionStart, let e = selectionEnd else { return nil }
        let minX = min(s.x, e.x)
        let minY = min(s.y, e.y)
        let maxX = max(s.x, e.x)
        let maxY = max(s.y, e.y)
        let w = maxX - minX + 1
        let h = maxY - minY + 1
        guard w > 0, h > 0 else { return nil }
        return (minX, minY, w, h)
    }

    // MARK: - Timer
    var m_TimeCount: Int = 0

    // MARK: - Semaphore
    let canvasSemaphore = DispatchSemaphore(value: 1)

    // MARK: - Scroll indicators
    lazy var hScrollIndicator: PCScrollIndicator = {
        let ind = PCScrollIndicator(orientation: .horizontal)
        self.addSubview(ind)
        return ind
    }()
    lazy var vScrollIndicator: PCScrollIndicator = {
        let ind = PCScrollIndicator(orientation: .vertical)
        self.addSubview(ind)
        return ind
    }()

    // MARK: - Init

    deinit {
        if m_pPasteBuffer != nil {
            m_pPasteBuffer?.deallocate()
        }
    }

    /// Initialize the pixel canvas. Call from viewDidLoad of the ViewController.
    func initPixelCanvas() {
        initMetal()

        // Show Miss Pixcen intro image
        // On first launch: always show. After that: only if user enabled "Always show intro".
        let alwaysShow = UserDefaults.standard.bool(forKey: "alwaysShowIntro")
        let shownBefore = UserDefaults.standard.bool(forKey: "Intro.Shown")

        if !shownBefore || alwaysShow {
            if loadIntro() {
                UserDefaults.standard.set(true, forKey: "Intro.Shown")
            }
        }
    }

    func initMetal() {
        if let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) {
            self.colorspace = colorSpace

            let devices = MTLCopyAllDevices()
            if devices.count > 0 {
                var device: MTLDevice! = MTLCreateSystemDefaultDevice()
                for potentialDevice in devices {
                    if !potentialDevice.isLowPower {
                        device = potentialDevice
                        break
                    }
                }

                self.device = device

                if self.device != nil {
                    self.renderer = PixelCanvasRenderer(mtkView: self)

                    self.isPaused = false
                    self.enableSetNeedsDisplay = false
                    self.preferredFramesPerSecond = 30

                    self.renderer.mtkView(self, drawableSizeWillChange: self.drawableSize)
                    self.delegate = self.renderer
                    print("Metal Renderer created, device=\(device.name)")
                    return
                }
            }
            print("Metal is not supported on this device")
        } else {
            print("Could not create colorspace")
        }
    }

    // MARK: - Metal update (called each frame by PixelCanvasRenderer.draw(in:))

    func updateMetalRenderer() {
        guard let renderer = renderer else { return }
        guard let colorBuffer = m_pbm.getExpandedColorBuffer() else { return }

        let pbm = m_pbm

        // Upload pixel buffer
        renderer.updatePixelBuffer(pixels: colorBuffer,
                                   width: pbm.sizeX,
                                   height: pbm.sizeY)

        // Retina scaling
        let drawableSize = self.drawableSize
        let retina = Float(drawableSize.width / bounds.size.width)

        renderer.uniforms.viewportSize = SIMD2<Float>(Float(drawableSize.width),
                                                      Float(drawableSize.height))
        renderer.uniforms.zoom = zoomLevel * retina
        renderer.uniforms.pan = panOffset
        renderer.uniforms.pixelWidth = Float(pbm.pixelWidth)
        renderer.uniforms.pixelBufferSize = SIMD2<Float>(Float(pbm.sizeX),
                                                         Float(pbm.sizeY))

        renderer.uniforms.showPixelGrid = Int32(m_Grid)
        renderer.uniforms.showCellGrid = Int32(m_CellGrid)
        renderer.uniforms.cellWidth = Int32(pbm.cellSizeX)
        renderer.uniforms.cellHeight = Int32(pbm.cellSizeY)

        // Selection rectangle
        if let sel = selectionRect {
            renderer.uniforms.selectionRect = SIMD4<Float>(
                Float(sel.x), Float(sel.y), Float(sel.w), Float(sel.h))
        } else {
            renderer.uniforms.selectionRect = SIMD4<Float>(0, 0, 0, 0)
        }

        // Border color
        let borderIdx = Int(pbm.borderColor)
        let borderCol = C64Col.shared.borderColor[borderIdx]
        renderer.uniforms.borderColor = SIMD4<Float>(
            Float(borderCol.redComponent),
            Float(borderCol.greenComponent),
            Float(borderCol.blueComponent),
            1.0
        )

        // Grid colors from user defaults
        let gcP = UInt32(UserDefaults.standard.integer(forKey: "GridColor.Pixel"))
        let gcC = UInt32(UserDefaults.standard.integer(forKey: "GridColor.Cell"))
        renderer.uniforms.gridColor = colorrefToSIMD4(gcP != 0 ? gcP : 0x00101010)
        renderer.uniforms.cellGridColor = colorrefToSIMD4(gcC != 0 ? gcC : 0x00404040)

        // Upload current palette (supports palette switching at runtime)
        let palette = C64Col.shared
        var colors = [SIMD4<Float>](repeating: .zero, count: 16)
        for i in 0..<16 {
            let c = palette.color[i]
            colors[i] = SIMD4<Float>(Float(c.redComponent),
                                     Float(c.greenComponent),
                                     Float(c.blueComponent),
                                     1.0)
        }
        renderer.updatePalette(colors: colors)

        // Update scroll indicators
        updateScrollIndicators()
    }

    private func updateScrollIndicators() {
        let retina = Float(drawableSize.width / bounds.size.width)
        let inset: CGFloat = 3
        let thickness: CGFloat = 3

        // Position horizontal bar at bottom
        hScrollIndicator.frame = NSRect(
            x: inset,
            y: bounds.height - thickness - inset,
            width: bounds.width - thickness - inset * 3,
            height: thickness
        )

        // Position vertical bar at right
        vScrollIndicator.frame = NSRect(
            x: bounds.width - thickness - inset,
            y: inset,
            width: thickness,
            height: bounds.height - thickness - inset * 3
        )

        let vp = drawableSize
        hScrollIndicator.update(
            panOffset: panOffset.x,
            zoomLevel: zoomLevel * retina,
            bufferSize: Float(m_pbm.sizeX),
            viewportSize: Float(vp.width),
            pixelWidth: Float(m_pbm.pixelWidth)
        )
        vScrollIndicator.update(
            panOffset: panOffset.y,
            zoomLevel: zoomLevel * retina,
            bufferSize: Float(m_pbm.sizeY),
            viewportSize: Float(vp.height),
            pixelWidth: 1.0
        )
    }

    // MARK: - Invalidate

    func invalidate(_ flag: Bool = false) {
        panOffset = .zero
        zoomLevel = 1.0
    }

    // MARK: - Border color

    func updateBorderColor() {
        // Border color is now handled by the shader via updateMetalRenderer.
        // Nothing to do here; the renderer reads it each frame.
    }

    // MARK: - Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if self.window != nil {
            self.isPaused = false
        }
    }

    // MARK: - Intro

    func loadIntro() -> Bool {
        guard let asset = NSDataAsset(name: "mspixcen") else {
            print("Missing data asset: mspixcen")
            return false
        }

        var missPixcen = asset.data

        do {
            let i = try PCMCBitmap()
            i.inheritHistory(old: m_pbm)
            m_pbm = i
            try m_pbm.load(file: &missPixcen, type: "kla", version: 0)
            zoomLevel = 2.0
            self.invalidate()
        } catch {
            print("Error: \(error)")
            return false
        }
        return true
    }

    // MARK: - Palette handling

    func onModePalette(_ n: Int) {
        C64Col.shared.selectPalette(n)
        invalidate()
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "MSG_REFRESH")))
    }

    // MARK: - View restore

    func onViewRestoremainview() {
        zoomLevel = 1.0
        panOffset = .zero
        m_Grid = 1
        invalidate()
    }

    // MARK: - PAR (Pixel Aspect Ratio)

    func onPreviewpixelaspectratioPc() {
        m_pbm.setPAR(0)
    }

    func onPreviewpixelaspectratioPal() {
        m_pbm.setPAR(1)
    }

    func onPreviewpixelaspectratioNtsc() {
        m_pbm.setPAR(2)
    }

    // MARK: - File New (stub)

    func onFileNew() {
        // TODO: Implement new file dialog
    }

    // MARK: - Status refresh

    /// Refresh the status bar without requiring a mouse event.
    /// Call after keyboard actions or menu operations that change state.
    func refreshStatus() {
        let mouseInWindow = window?.mouseLocationOutsideOfEventStream ?? .zero
        let locationInView = convert(mouseInWindow, from: nil)
        if let pix = getPixelFromPoint(locationInView) {
            updateStatus(pix: CGPoint(x: CGFloat(pix.x), y: CGFloat(pix.y)))
        } else {
            // Mouse outside image - still update with dummy coords to refresh hints
            updateStatus(pix: CGPoint(x: 0, y: 0))
        }
    }

    // MARK: - Helpers

    /// Convert a COLORREF (0x00BBGGRR) to SIMD4<Float>
    private func colorrefToSIMD4(_ c: UInt32) -> SIMD4<Float> {
        let r = Float(c & 0xFF) / 255.0
        let g = Float((c >> 8) & 0xFF) / 255.0
        let b = Float((c >> 16) & 0xFF) / 255.0
        return SIMD4<Float>(r, g, b, 1.0)
    }
}
