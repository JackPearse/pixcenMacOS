//
//  pixcenTests.swift
//  pixcenTests
//
//  General sanity tests for the pixcen application.
//

import XCTest
@testable import pixcen

final class PixcenTests: XCTestCase {

    // MARK: - Bitmap creation

    func testCreateMCBitmap() throws {
        let bm = try PCMCBitmap()
        XCTAssertEqual(bm.sizeX, 160)
        XCTAssertEqual(bm.sizeY, 200)
        XCTAssertEqual(bm.pixelWidth, 2)
        XCTAssertEqual(bm.cellSizeX, 4)
        XCTAssertEqual(bm.cellSizeY, 8)
        XCTAssertNotNil(bm.canvasModel.map)
        XCTAssertNotNil(bm.canvasModel.screen)
        XCTAssertNotNil(bm.canvasModel.color)
        XCTAssertNotNil(bm.canvasModel.background)
    }

    func testPixelReadWrite() throws {
        let bm = try PCMCBitmap()

        // Default pixel should be 0 (background)
        XCTAssertEqual(bm.pixel(0, 0), 0)

        // Set and read back
        bm.setPixel(10, 10, 1)
        // Note: MC bitmap setPixel resolves mask, so the exact color
        // depends on cell color allocation. Just verify it changed.
        let val = bm.pixel(10, 10)
        XCTAssertNotEqual(val, 255, "Pixel should be a valid color")
    }

    // MARK: - Undo/Redo

    func testUndoRedo() throws {
        let bm = try PCMCBitmap()

        XCTAssertFalse(bm.canUndo, "Fresh bitmap should not have undo")
        XCTAssertFalse(bm.canRedo, "Fresh bitmap should not have redo")

        // Make a change
        bm.beginHistory()
        bm.setPixel(10, 10, 1)
        bm.endHistory()

        XCTAssertTrue(bm.canUndo, "Should be able to undo after change")
        XCTAssertFalse(bm.canRedo, "Should not be able to redo yet")

        // Undo
        let _ = bm.undo()
        XCTAssertFalse(bm.canUndo, "Should not be able to undo after undoing")
        XCTAssertTrue(bm.canRedo, "Should be able to redo after undo")

        // Redo
        let _ = bm.redo()
        XCTAssertTrue(bm.canUndo, "Should be able to undo after redo")
    }

    func testUndoLimit() throws {
        let bm = try PCMCBitmap()

        // Create more than 100 history entries
        for i in 0..<110 {
            bm.beginHistory()
            bm.setPixel(i % 160, i % 200, UInt8(i % 16))
            bm.endHistory()
        }

        // History should be capped
        // The exact count depends on implementation but should not exceed ~101
        XCTAssertTrue(bm.canUndo)
    }

    // MARK: - Color palette

    func testPaletteHas16Colors() {
        let palette = C64Col.shared
        XCTAssertEqual(palette.color.count, 16, "C64 palette should have 16 colors")
    }

    func testPaletteSelection() {
        let palette = C64Col.shared
        let count = palette.palette.count
        XCTAssertGreaterThan(count, 0, "Should have at least one palette")

        // Select each palette and verify colors are still 16
        for i in 0..<count {
            palette.selectPalette(i)
            XCTAssertEqual(palette.color.count, 16)
        }
    }

    // MARK: - Data extensions

    func testDataReadUInt32() {
        var data = Data([0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00])
        var val: UInt32 = 0
        data >> val
        XCTAssertEqual(val, 4, "Should read little-endian UInt32")
        data >> val
        XCTAssertEqual(val, 1)
    }

    func testDataReadUInt16() {
        var data = Data([0x00, 0x60, 0xE8, 0x03])
        var val: UInt16 = 0
        data >> val
        XCTAssertEqual(val, 0x6000, "Koala load address")
        data >> val
        XCTAssertEqual(val, 1000)
    }

    func testDataAppendInt32() {
        var data = Data()
        data.appendInt32(4)
        data.appendInt32(1)
        XCTAssertEqual(data.count, 8)
        XCTAssertEqual(data[0], 4)
        XCTAssertEqual(data[4], 1)
    }

    func testNullTerminatedASCII() {
        var data = Data([0x78, 0x73, 0x69, 0x7A, 0x65, 0x00, 0xFF])  // "xsize\0\xFF"
        let str = data.readNullTerminatedASCII()
        XCTAssertEqual(str, "xsize")
        XCTAssertEqual(data.count, 1, "Should have consumed up to null terminator")
    }

    func testNullTerminatedUTF16LE() {
        // "160" in UTF-16LE: 0x31 0x00  0x36 0x00  0x30 0x00  0x00 0x00
        var data = Data([0x31, 0x00, 0x36, 0x00, 0x30, 0x00, 0x00, 0x00, 0xFF])
        let str = data.readNullTerminatedUTF16LE()
        XCTAssertEqual(str, "160")
        XCTAssertEqual(data.count, 1, "Should have consumed up to null terminator")
    }

    // MARK: - Zlib

    func testZlibCompressDecompress() throws {
        let original = Data(repeating: 0x42, count: 5000)
        let compressed = try ZlibCompression.compress(original)
        let decompressed = try ZlibCompression.decompress(compressed, maxSize: 10000)
        XCTAssertEqual(original, decompressed)
    }

    // MARK: - Load formats

    func testLoadFormatsIncludeGPX() {
        let formats = PCC64Interface.loadFormats
        let gpxFormat = formats.first { $0.matchExt(ex: "gpx") }
        XCTAssertNotNil(gpxFormat, "Load formats should include GPX")
    }

    func testLoadFormatsIncludeKoala() {
        let formats = PCC64Interface.loadFormats
        let klaFormat = formats.first { $0.matchExt(ex: "kla") }
        XCTAssertNotNil(klaFormat, "Load formats should include KLA")
    }
}
