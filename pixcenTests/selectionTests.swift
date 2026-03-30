//
//  selectionTests.swift
//  pixcenTests
//
//  Tests for selection operations and pixel transformations.
//

import XCTest
@testable import pixcen

final class SelectionTransformTests: XCTestCase {

    // MARK: - Flip Vertical

    func testFlipVertically() throws {
        let bm = try PCMCBitmap()
        // Set a pixel at top
        bm.setPixel(10, 0, 1)
        XCTAssertEqual(bm.pixel(10, 0), 1)
        XCTAssertEqual(bm.pixel(10, 199), 0)

        // Flip
        bm.beginHistory()
        let w = bm.sizeX, h = bm.sizeY
        for y in 0..<(h / 2) {
            for x in 0..<w {
                let top = bm.pixel(x, y)
                let bot = bm.pixel(x, h - 1 - y)
                bm.setPixel(x, y, bot)
                bm.setPixel(x, h - 1 - y, top)
            }
        }
        bm.endHistory()

        // Pixel should now be at bottom
        XCTAssertEqual(bm.pixel(10, 199), 1, "Pixel should have moved to bottom after flip")
    }

    // MARK: - Flip Horizontal

    func testFlipHorizontally() throws {
        let bm = try PCMCBitmap()
        bm.setPixel(0, 10, 1)
        XCTAssertEqual(bm.pixel(0, 10), 1)
        XCTAssertEqual(bm.pixel(159, 10), 0)

        bm.beginHistory()
        let w = bm.sizeX, h = bm.sizeY
        for y in 0..<h {
            for x in 0..<(w / 2) {
                let left = bm.pixel(x, y)
                let right = bm.pixel(w - 1 - x, y)
                bm.setPixel(x, y, right)
                bm.setPixel(w - 1 - x, y, left)
            }
        }
        bm.endHistory()

        XCTAssertEqual(bm.pixel(159, 10), 1, "Pixel should have moved to right after flip")
    }

    // MARK: - Shift Operations

    func testShiftDown() throws {
        let bm = try PCMCBitmap()
        bm.setPixel(10, 0, 1)

        bm.beginHistory()
        let w = bm.sizeX, h = bm.sizeY
        // Save bottom row
        var saved = [UInt8](repeating: 0, count: w)
        for x in 0..<w { saved[x] = bm.pixel(x, h - 1) }
        // Shift down
        for y in stride(from: h - 1, through: 1, by: -1) {
            for x in 0..<w { bm.setPixel(x, y, bm.pixel(x, y - 1)) }
        }
        // Wrap top
        for x in 0..<w { bm.setPixel(x, 0, saved[x]) }
        bm.endHistory()

        XCTAssertEqual(bm.pixel(10, 1), 1, "Pixel should have shifted down by 1")
    }

    func testShiftRight() throws {
        let bm = try PCMCBitmap()
        bm.setPixel(0, 10, 1)

        bm.beginHistory()
        let w = bm.sizeX, h = bm.sizeY
        for y in 0..<h {
            let saved = bm.pixel(w - 1, y)
            for x in stride(from: w - 1, through: 1, by: -1) {
                bm.setPixel(x, y, bm.pixel(x - 1, y))
            }
            bm.setPixel(0, y, saved)
        }
        bm.endHistory()

        XCTAssertEqual(bm.pixel(1, 10), 1, "Pixel should have shifted right by 1")
    }

    // MARK: - Flip preserves undo

    func testFlipWithUndo() throws {
        let bm = try PCMCBitmap()
        bm.setPixel(10, 10, 1)
        let originalPixel = bm.pixel(10, 10)

        // Flip vertically (with history)
        bm.beginHistory()
        let w = bm.sizeX, h = bm.sizeY
        for y in 0..<(h / 2) {
            for x in 0..<w {
                let top = bm.pixel(x, y)
                let bot = bm.pixel(x, h - 1 - y)
                bm.setPixel(x, y, bot)
                bm.setPixel(x, h - 1 - y, top)
            }
        }
        bm.endHistory()

        XCTAssertTrue(bm.canUndo, "Should be able to undo flip")

        // Undo
        let _ = bm.undo()
        XCTAssertEqual(bm.pixel(10, 10), originalPixel, "Undo should restore original pixel")
    }

    // MARK: - Copy/Paste buffer

    func testCopyCreatesBuffer() throws {
        let bm = try PCMCBitmap()
        bm.setPixel(5, 5, 3)

        let w = bm.sizeX, h = bm.sizeY
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: w * h)
        for y in 0..<h {
            for x in 0..<w {
                buffer[y * w + x] = bm.pixel(x, y)
            }
        }

        // Verify the copied buffer has the pixel
        XCTAssertEqual(buffer[5 * w + 5], 3, "Buffer should contain the pixel value")
        buffer.deallocate()
    }

    // MARK: - Hires bitmap transforms

    func testHiresFlipVertically() throws {
        let bm = try PCBitmap()
        bm.setPixel(100, 0, 1)

        bm.beginHistory()
        let w = bm.sizeX, h = bm.sizeY
        for y in 0..<(h / 2) {
            for x in 0..<w {
                let top = bm.pixel(x, y)
                let bot = bm.pixel(x, h - 1 - y)
                bm.setPixel(x, y, bot)
                bm.setPixel(x, h - 1 - y, top)
            }
        }
        bm.endHistory()

        XCTAssertEqual(bm.pixel(100, 199), 1, "Hires pixel should flip to bottom")
    }

    // MARK: - Double flip = identity

    func testDoubleFlipIsIdentity() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var data = asset.data
        let bm = try PCMCBitmap()
        try bm.load(file: &data, type: "kla", version: 0)

        // Save original pixels
        let w = bm.sizeX, h = bm.sizeY
        var original = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w { original[y * w + x] = bm.pixel(x, y) } }

        // Flip twice vertically
        for _ in 0..<2 {
            for y in 0..<(h / 2) {
                for x in 0..<w {
                    let top = bm.pixel(x, y)
                    let bot = bm.pixel(x, h - 1 - y)
                    bm.setPixel(x, y, bot)
                    bm.setPixel(x, h - 1 - y, top)
                }
            }
        }

        // Should be identical
        var mismatches = 0
        for y in 0..<h { for x in 0..<w {
            if bm.pixel(x, y) != original[y * w + x] { mismatches += 1 }
        }}
        XCTAssertEqual(mismatches, 0, "Double flip should restore original image")
    }
}
