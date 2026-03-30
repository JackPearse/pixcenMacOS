//
//  PCPreviewWindow.swift
//  pixcen
//
//  Preview window showing the C64 image with pixel aspect ratio applied.
//  This is a floating window that updates whenever the bitmap changes.
//

import Cocoa

class PCPreviewWindowController: NSWindowController {

    private var imageView: NSImageView!
    private var timer: Timer?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 384, height: 272),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preview"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 160, height: 100)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        imageView = NSImageView(frame: contentView.bounds)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        contentView.addSubview(imageView)

        // Use a wantsLayer background for the border color
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.darkGray.cgColor
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        startUpdating()
    }

    func startUpdating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            self?.updatePreview()
        }
    }

    func stopUpdating() {
        timer?.invalidate()
        timer = nil
    }

    override func close() {
        stopUpdating()
        super.close()
    }

    private func updatePreview() {
        guard let delegate = NSApp.delegate as? AppDelegate,
              let canvas = delegate.pixelCanvasView else { return }

        let pbm = canvas.m_pbm
        let w = pbm.sizeX
        let h = pbm.sizeY
        let pw = pbm.pixelWidth

        guard w > 0, h > 0 else { return }

        // Render to NSImage with PAR applied
        let par = pbm.getPARValue()
        let imgW = Int(Double(w * pw) * par)
        let imgH = h

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: imgW, pixelsHigh: imgH,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: imgW * 4, bitsPerPixel: 32
        ) else { return }

        let pixels = rep.bitmapData!
        let palette = C64Col.shared

        // Render border area
        let borderIdx = Int(pbm.borderColor & 0x0f)
        let borderColor = palette.borderColor[borderIdx]
        let br = UInt8(borderColor.redComponent * 255)
        let bg = UInt8(borderColor.greenComponent * 255)
        let bb = UInt8(borderColor.blueComponent * 255)

        // Fill with border color first
        for i in 0..<(imgW * imgH) {
            pixels[i * 4] = br
            pixels[i * 4 + 1] = bg
            pixels[i * 4 + 2] = bb
            pixels[i * 4 + 3] = 255
        }

        // Render bitmap pixels with PAR scaling
        for y in 0..<h {
            for x in 0..<w {
                let colorIdx = Int(pbm.pixel(x, y) & 0x0f)
                let c = palette.color[colorIdx]
                let r = UInt8(c.redComponent * 255)
                let g = UInt8(c.greenComponent * 255)
                let b = UInt8(c.blueComponent * 255)

                // Each C64 pixel spans pw screen pixels, scaled by PAR
                let startX = Int(Double(x * pw) * par)
                let endX = Int(Double((x + 1) * pw) * par)

                for sx in startX..<min(endX, imgW) {
                    let offset = (y * imgW + sx) * 4
                    pixels[offset] = r
                    pixels[offset + 1] = g
                    pixels[offset + 2] = b
                    pixels[offset + 3] = 255
                }
            }
        }

        let image = NSImage(size: NSSize(width: imgW, height: imgH))
        image.addRepresentation(rep)
        imageView.image = image

        // Update background to border color
        window?.contentView?.layer?.backgroundColor = borderColor.cgColor
    }
}
