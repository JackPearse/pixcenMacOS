//
//  PixelCanvasRenderer.swift
//  pixcen
//
//  Created by Jack Pearse on 21.03.21.
//  Rewritten for fullscreen Metal rendering - 2026-03-26
//

import Foundation
import MetalKit
import simd

// Uniforms structure matching Metal shader layout exactly
struct Uniforms {
    var viewportSize: SIMD2<Float>      // offset 0:  drawable size in pixels (Retina)
    var pixelBufferSize: SIMD2<Float>   // offset 8:  C64 buffer size (e.g. 160x200)
    var zoom: Float                      // offset 16: continuous zoom factor * retinaScale
    var pixelWidth: Float                // offset 20: pixel width (1=hires, 2=multicolor)
    var pan: SIMD2<Float>               // offset 24: pan in C64-pixel-space
    var showPixelGrid: Int32            // offset 32
    var showCellGrid: Int32             // offset 36
    var cellWidth: Int32                // offset 40
    var cellHeight: Int32               // offset 44
    var borderColor: SIMD4<Float>       // offset 48
    var gridColor: SIMD4<Float>         // offset 64
    var cellGridColor: SIMD4<Float>     // offset 80
    var selectionRect: SIMD4<Float>     // offset 96: (x, y, w, h) in C64 pixels, w=0 means no selection
    var time: Float                      // offset 112: animation time for marching ants
    var _padding3: SIMD3<Float> = .zero  // offset 116: padding to 128 bytes
}

class PixelCanvasRenderer: NSObject, MTKViewDelegate {

    var view: MTKView!
    var device: MTLDevice!
    var queue: MTLCommandQueue!
    var library: MTLLibrary!

    var renderPipeline: MTLRenderPipelineState!
    var pixelTexture: MTLTexture?
    var uniformBuffer: MTLBuffer!
    var paletteBuffer: MTLBuffer!

    var uniforms = Uniforms(
        viewportSize: SIMD2<Float>(800, 600),
        pixelBufferSize: SIMD2<Float>(160, 200),
        zoom: 2.0,
        pixelWidth: 2.0,
        pan: SIMD2<Float>(0, 0),
        showPixelGrid: 1,
        showCellGrid: 1,
        cellWidth: 4,
        cellHeight: 8,
        borderColor: SIMD4<Float>(0.1, 0.19, 0.22, 1.0),
        gridColor: SIMD4<Float>(0.4, 0.4, 0.4, 1.0),
        cellGridColor: SIMD4<Float>(0.8, 0.8, 0.8, 1.0),
        selectionRect: SIMD4<Float>(0, 0, 0, 0),
        time: 0
    )

    init(mtkView: MTKView) {
        super.init()

        self.view = mtkView
        self.device = mtkView.device

        print("Metal device: " + device.name)

        loadMetal()
        createPipelines()
        createBuffers()
    }

    func loadMetal() {
        view.colorPixelFormat = .bgra8Unorm
        view.sampleCount = 1
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        library = device.makeDefaultLibrary()
        queue = device.makeCommandQueue()
    }

    func createPipelines() {
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.sampleCount = view.sampleCount
        renderDescriptor.vertexFunction = library.makeFunction(name: "copyVertex")
        renderDescriptor.fragmentFunction = library.makeFunction(name: "copyFragment")
        renderDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: renderDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func createBuffers() {
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                          options: .storageModeShared)
        // 16 colors * SIMD4<Float> (16 bytes each) = 256 bytes
        paletteBuffer = device.makeBuffer(length: 16 * MemoryLayout<SIMD4<Float>>.stride,
                                          options: .storageModeShared)
    }

    /// Upload the current C64 palette (16 RGBA colors) to the GPU
    func updatePalette(colors: [SIMD4<Float>]) {
        guard colors.count == 16 else { return }
        let ptr = paletteBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 16)
        for i in 0..<16 {
            ptr[i] = colors[i]
        }
    }

    // Upload pixel buffer (C64 color indices 0-15)
    func updatePixelBuffer(pixels: UnsafePointer<UInt8>, width: Int, height: Int) {
        if pixelTexture == nil ||
           pixelTexture!.width != width ||
           pixelTexture!.height != height {

            let desc = MTLTextureDescriptor()
            desc.pixelFormat = .r8Uint
            desc.width = width
            desc.height = height
            desc.usage = [.shaderRead]
            desc.storageMode = .shared
            pixelTexture = device.makeTexture(descriptor: desc)
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        pixelTexture?.replace(region: region,
                              mipmapLevel: 0,
                              withBytes: pixels,
                              bytesPerRow: width)
        uniforms.pixelBufferSize = SIMD2<Float>(Float(width), Float(height))
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    func draw(in view: MTKView) {
        // Let the canvas update uniforms before rendering
        if let canvasView = view as? PCPixelCanvasView {
            canvasView.updateMetalRenderer()
        }
        // Animate marching ants
        uniforms.time += 1.0 / 30.0

        guard let commandBuffer = queue.makeCommandBuffer(),
              let rpd = view.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            return
        }

        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)

        encoder.setRenderPipelineState(renderPipeline)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(paletteBuffer, offset: 0, index: 1)

        if let texture = pixelTexture {
            encoder.setFragmentTexture(texture, index: 0)
        }

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
    }
}
