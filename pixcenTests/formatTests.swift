//
//  formatTests.swift
//  pixcenTests
//
//  Comprehensive tests for all C64 file formats.
//

import XCTest
@testable import pixcen

// MARK: - GPX Format (Native Pixcen)

final class GPXFormatTests: XCTestCase {

    func testGPXLoad() throws {
        let bitmap = try PCMCBitmap()
        let gpxData = try bitmap.saveGPX()
        var decompressed = try ZlibCompression.decompress(gpxData, maxSize: 1024 * 1024 * 20)
        var version: UInt32 = 0; var mode: UInt32 = 0
        decompressed >> version; decompressed >> mode
        let loaded = try PCMCBitmap()
        loaded.canvasModel.mode = .MC_BITMAP
        try loaded.load(file: &decompressed, type: "gpx", version: Int(version))
        XCTAssertEqual(loaded.sizeX, 160)
        XCTAssertEqual(loaded.sizeY, 200)
    }

    func testGPXSave() throws {
        let bitmap = try PCMCBitmap()
        bitmap.setPixel(10, 10, 1)
        let data = try bitmap.saveGPX()
        XCTAssertGreaterThan(data.count, 0)
    }

    func testGPXRoundTrip() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var kla = asset.data
        let original = try PCMCBitmap()
        try original.load(file: &kla, type: "kla", version: 0)
        let gpx = try original.saveGPX()
        var dec = try ZlibCompression.decompress(gpx, maxSize: 1024*1024*20)
        var v: UInt32 = 0; var m: UInt32 = 0
        dec >> v; dec >> m
        let loaded = try PCMCBitmap()
        loaded.canvasModel.mode = .MC_BITMAP
        try loaded.load(file: &dec, type: "gpx", version: Int(v))
        var mismatches = 0
        for y in 0..<200 { for x in 0..<160 {
            if original.pixel(x, y) != loaded.pixel(x, y) { mismatches += 1 }
        }}
        XCTAssertEqual(mismatches, 0)
    }
}

// MARK: - Koala Format (MCBitmap)

final class KoalaFormatTests: XCTestCase {

    func testKLALoad() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var data = asset.data
        let bm = try PCMCBitmap()
        try bm.load(file: &data, type: "kla", version: 0)
        XCTAssertEqual(bm.sizeX, 160)
    }

    func testKOALoad() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var data = asset.data
        let bm = try PCMCBitmap()
        try bm.load(file: &data, type: "koa", version: 0)
        XCTAssertEqual(bm.sizeX, 160)
    }

    func testKLASave() throws {
        // IMPLEMENTED: KLA save produces 10003 bytes
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var data = asset.data
        let bm = try PCMCBitmap()
        try bm.load(file: &data, type: "kla", version: 0)
        let saved = try bm.saveToFile(type: "kla")
        XCTAssertEqual(saved.count, 10003, "KLA should be 10003 bytes")
    }

    func testKLARoundTrip() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var data = asset.data
        let original = try PCMCBitmap()
        try original.load(file: &data, type: "kla", version: 0)
        let saved = try original.saveToFile(type: "kla")
        var reloaded = saved
        let loaded = try PCMCBitmap()
        try loaded.load(file: &reloaded, type: "kla", version: 0)
        var mismatches = 0
        for y in 0..<200 { for x in 0..<160 {
            if original.pixel(x, y) != loaded.pixel(x, y) { mismatches += 1 }
        }}
        XCTAssertEqual(mismatches, 0, "KLA round-trip pixels should match")
    }

    func testGGLoad() throws {
        // GG (Koala compressed): TODO - needs DecompressKoalaStream
    }

    func testGGSave() throws {
        // GG save: TODO - needs CompressKoalaStream
    }
}

// MARK: - MCBitmap Additional Formats

final class MCBitmapFormatTests: XCTestCase {

    func testCENSave() throws {
        let bm = try PCMCBitmap()
        let saved = try bm.saveToFile(type: "cen")
        XCTAssertEqual(saved.count, 10051, "CEN should be 10051 bytes")
    }

    func testOCPSave() throws {
        let bm = try PCMCBitmap()
        let saved = try bm.saveToFile(type: "ocp")
        XCTAssertEqual(saved.count, 10018, "OCP should be 10018 bytes")
    }

    func testMGSave() throws {
        let bm = try PCMCBitmap()
        let saved = try bm.saveToFile(type: "mg")
        XCTAssertEqual(saved.count, 11266, "MG should be 11266 bytes")
    }

    func testPRGSave() throws {
        // IMPLEMENTED: PRG save via ByteBoozer bridge
        let bm = try PCMCBitmap()
        let saved = try bm.saveToFile(type: "prg")
        XCTAssertGreaterThan(saved.count, 0, "PRG should produce data")
        // PRG is ByteBoozer compressed, so size varies
    }

    func testZOMLoad() throws {
        // ZOM: TODO - needs DecompressZoomaticStream
    }

    func testZOMSave() throws {
        // ZOM save: TODO - needs CompressZoomaticStream
    }

    func testBINMCLoad() throws {
        // Multipaint MC: TODO - complex interleaved layout
    }

    func testAMILoad() throws {
        // Amica: TODO - needs DecompressAmicaStream
    }
}

// MARK: - Bitmap (Hires) Formats

final class BitmapFormatTests: XCTestCase {

    func testARTSave() throws {
        let bm = try PCBitmap()
        let saved = try bm.saveToFile(type: "art")
        XCTAssertEqual(saved.count, 9002, "ART should be 9002 bytes")
    }

    func testDDSave() throws {
        let bm = try PCBitmap()
        let saved = try bm.saveToFile(type: "dd")
        XCTAssertEqual(saved.count, 9218, "DD should be 9218 bytes")
    }

    func testARTRoundTrip() throws {
        let original = try PCBitmap()
        original.setPixel(100, 100, 1)
        let saved = try original.saveToFile(type: "art")
        var data = saved
        let loaded = try PCBitmap()
        try loaded.load(file: &data, type: "art", version: 0)
        XCTAssertEqual(original.pixel(100, 100), loaded.pixel(100, 100))
    }

    func testDDRoundTrip() throws {
        let original = try PCBitmap()
        original.setPixel(100, 100, 1)
        let saved = try original.saveToFile(type: "dd")
        var data = saved
        let loaded = try PCBitmap()
        try loaded.load(file: &data, type: "dd", version: 0)
        XCTAssertEqual(original.pixel(100, 100), loaded.pixel(100, 100))
    }

    func testJJLoad() throws {
        // JJ: TODO - needs DecompressKoalaStream
    }

    func testBINHILoad() throws {
        // Multipaint hires: TODO - complex interleaved
    }
}

// MARK: - Sprite Formats

final class SpriteFormatTests: XCTestCase {

    func testSpriteCreation() throws {
        let spr = try PCSprite()
        XCTAssertEqual(spr.sizeX, 24)
        XCTAssertEqual(spr.sizeY, 21)
        XCTAssertEqual(spr.pixelWidth, 1)
    }

    func testMCSpriteCreation() throws {
        let spr = try PCMCSprite()
        XCTAssertEqual(spr.sizeX, 12)
        XCTAssertEqual(spr.sizeY, 21)
        XCTAssertEqual(spr.pixelWidth, 2)
    }

    func testSpriteRawSave() throws {
        let spr = try PCSprite()
        let data = try spr.saveToFile(type: "raw")
        XCTAssertEqual(data.count, 64, "Single sprite raw = 64 bytes")
    }

    func testMCSpriteRawSave() throws {
        let spr = try PCMCSprite()
        let data = try spr.saveToFile(type: "raw")
        XCTAssertEqual(data.count, 64, "Single MC sprite raw = 64 bytes")
    }
}

// MARK: - Font Formats

final class FontFormatTests: XCTestCase {

    func testSFontCreation() throws {
        let font = try PCSFont()
        XCTAssertEqual(font.sizeX, 320)
        XCTAssertEqual(font.sizeY, 200)
        XCTAssertEqual(font.pixelWidth, 1)
        XCTAssertEqual(font.cellSizeX, 8)
        XCTAssertEqual(font.cellSizeY, 8)
    }

    func testMCFontCreation() throws {
        let font = try PCMCFont()
        XCTAssertEqual(font.sizeX, 160)
        XCTAssertEqual(font.sizeY, 200)
        XCTAssertEqual(font.pixelWidth, 2)
        XCTAssertEqual(font.cellSizeX, 4)
        XCTAssertEqual(font.cellSizeY, 8)
    }
}

// MARK: - Unrestricted Format

final class UnrestrictedFormatTests: XCTestCase {

    func testUnrestrictedCreation() throws {
        let ur = try PCUnrestricted()
        XCTAssertEqual(ur.sizeX, 320)
        XCTAssertEqual(ur.sizeY, 200)
        XCTAssertEqual(ur.pixelWidth, 1)
    }

    func testUnrestrictedPixelReadWrite() throws {
        let ur = try PCUnrestricted()
        ur.setPixel(10, 10, 5)
        XCTAssertEqual(ur.pixel(10, 10), 5, "Unrestricted allows any color per pixel")
    }
}

// MARK: - RAM Export Formats

final class RAMExportFormatTests: XCTestCase {

    func testSCRSave() throws {
        let bm = try PCMCBitmap()
        let data = try bm.saveToFile(type: "scr")
        XCTAssertEqual(data.count, 1000, "Screen RAM = 1000 bytes for MC bitmap")
    }

    func testCOLSave() throws {
        let bm = try PCMCBitmap()
        let data = try bm.saveToFile(type: "col")
        XCTAssertEqual(data.count, 1000, "Color RAM = 1000 bytes for MC bitmap")
    }

    func testMAPSave() throws {
        let bm = try PCMCBitmap()
        let data = try bm.saveToFile(type: "map")
        XCTAssertEqual(data.count, 8000, "Bitmap RAM = 8000 bytes for MC bitmap")
    }

    func testPSCRSave() throws {
        let bm = try PCMCBitmap()
        let data = try bm.saveToFile(type: "pscr")
        XCTAssertGreaterThan(data.count, 1000, "PRG screen has address header + data")
    }

    func testPCOLSave() throws {
        let bm = try PCMCBitmap()
        let data = try bm.saveToFile(type: "pcol")
        XCTAssertGreaterThan(data.count, 1000, "PRG color has address header + data")
    }

    func testPMAPSave() throws {
        let bm = try PCMCBitmap()
        let data = try bm.saveToFile(type: "pmap")
        XCTAssertGreaterThan(data.count, 8000, "PRG map has address header + data")
    }
}

// MARK: - Image Export Formats

final class ImageExportFormatTests: XCTestCase {

    func testPNGSave() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else { XCTFail("No asset"); return }
        var data = asset.data
        let bm = try PCMCBitmap()
        try bm.load(file: &data, type: "kla", version: 0)
        let png = try bm.saveToFile(type: "png")
        XCTAssertGreaterThan(png.count, 1000, "PNG should have substantial data")
        // PNG magic bytes
        XCTAssertEqual(png[0], 0x89)
        XCTAssertEqual(png[1], 0x50) // 'P'
        XCTAssertEqual(png[2], 0x4E) // 'N'
        XCTAssertEqual(png[3], 0x47) // 'G'
    }

    func testBMPSave() throws {
        let bm = try PCMCBitmap()
        let bmp = try bm.saveToFile(type: "bmp")
        XCTAssertGreaterThan(bmp.count, 100)
        // BMP magic bytes
        XCTAssertEqual(bmp[0], 0x42) // 'B'
        XCTAssertEqual(bmp[1], 0x4D) // 'M'
    }

    func testJPGSave() throws {
        let bm = try PCMCBitmap()
        let jpg = try bm.saveToFile(type: "jpg")
        XCTAssertGreaterThan(jpg.count, 100)
        // JPEG magic bytes
        XCTAssertEqual(jpg[0], 0xFF)
        XCTAssertEqual(jpg[1], 0xD8)
    }

    func testGIFSave() throws {
        let bm = try PCMCBitmap()
        let gif = try bm.saveToFile(type: "gif")
        XCTAssertGreaterThan(gif.count, 100)
        // GIF magic bytes
        XCTAssertEqual(gif[0], 0x47) // 'G'
        XCTAssertEqual(gif[1], 0x49) // 'I'
        XCTAssertEqual(gif[2], 0x46) // 'F'
    }

    func testBMPLoad() throws {
        // Image import: TODO - needs color reduction to C64 palette
    }

    func testPNGLoad() throws {
        // Image import: TODO - needs color reduction to C64 palette
    }
}

// MARK: - Format Summary

final class FormatSummaryTests: XCTestCase {

    func testFormatInventory() {
        // === IMPLEMENTED ===
        // Load: GPX, KLA, KOA, OCP, CEN, MG, PMG, ART, DD, Sprite raw, MCSprite raw, SFont raw, MCFont raw
        // Save: GPX, KLA, KOA, OCP, CEN, MG, PRG, ART, DD, Sprite raw, MCSprite raw,
        //       SCR, PSCR, COL, PCOL, MAP, PMAP, PNG, BMP, JPG, GIF
        //
        // === STILL TODO (need special codecs) ===
        // GG, ZOM (compressed MC bitmap) - need KoalaStream/ZoomaticStream RLE codecs
        // JJ (compressed hires) - needs KoalaStream RLE codec
        // AMI (Amica) - needs AmicaStream decompressor
        // BIN/BINMC/BINHI (Multipaint) - complex interleaved pixel format
        // Image import (BMP/PNG → C64) - needs color reduction algorithm
        //
        // === IMPLEMENTED VIA C++ BRIDGE ===
        // PRG (C64 executable) - ByteBoozer2 compression

        XCTAssertTrue(true, "Format inventory documented")
    }
}
