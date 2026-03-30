//
//  PCPixelCanvasView+Drawing.swift
//  pixcen
//
//  Pixel manipulation: Bresenham line drawing and flood fill.
//

import Foundation

extension PCPixelCanvasView {

    // MARK: - Bresenham Line Drawing

    /// Draw a line from one C64 pixel to another using Bresenham's algorithm.
    func drawLine(from: (x: Int, y: Int), to: (x: Int, y: Int), color: UInt8) {
        var x = from.x
        var y = from.y
        let dx = to.x - x
        let dy = to.y - y

        let xo, yo, xr, yr, total, partial: Int

        if abs(dx) > abs(dy) {
            total = abs(dx)
            partial = abs(dy)
            xo = dx > 0 ? 1 : -1
            yo = 0
            xr = 0
            yr = dy > 0 ? 1 : -1
        } else {
            total = abs(dy)
            partial = abs(dx)
            yo = dy > 0 ? 1 : -1
            xo = 0
            yr = 0
            xr = dx > 0 ? 1 : -1
        }

        var count = total + 1
        var step = total / 2

        while count > 0 {
            m_pbm.setPixel(x, y, color)

            x += xo
            y += yo
            step += partial

            if step >= total {
                x += xr
                y += yr
                step -= total
            }

            count -= 1
        }
    }

    // MARK: - Flood Fill (queue-based)

    /// Queue-based flood fill to avoid stack overflow on large areas.
    func floodFill(x: Int, y: Int, newColor: UInt8, targetColor: UInt8) {
        if newColor == targetColor {
            return
        }

        guard x >= 0, x < m_pbm.canvasModel.xsize,
              y >= 0, y < m_pbm.canvasModel.ysize else {
            return
        }

        var queue: [(x: Int, y: Int)] = [(x, y)]
        var visited = Set<Int>()
        let width = m_pbm.canvasModel.xsize
        let height = m_pbm.canvasModel.ysize

        while !queue.isEmpty {
            let point = queue.removeFirst()
            let px = point.x
            let py = point.y

            let key = py * width + px

            if visited.contains(key) {
                continue
            }

            guard px >= 0, px < width,
                  py >= 0, py < height else {
                continue
            }

            let currentColor = m_pbm.pixel(px, py)
            if currentColor != targetColor {
                continue
            }

            visited.insert(key)
            m_pbm.setPixel(px, py, newColor)

            queue.append((px + 1, py))
            queue.append((px - 1, py))
            queue.append((px, py + 1))
            queue.append((px, py - 1))
        }
    }
}
