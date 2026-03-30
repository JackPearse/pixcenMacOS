//
//  gpxTests.swift
//  pixcenTests
//
//  Tests for GPX file format round-trip (save and load).
//  Uses the "Miss Pixcen" KLA intro image as test data.
//

import XCTest
@testable import pixcen

final class GPXTests: XCTestCase {

    /// Test zlib compression round-trip
    func testZlibRoundTrip() throws {
        let original = Data(repeating: 0xAB, count: 1000)
        let compressed = try ZlibCompression.compress(original)
        let decompressed = try ZlibCompression.decompress(compressed, maxSize: 2000)

        XCTAssertEqual(original, decompressed, "Zlib round-trip should produce identical data")
        XCTAssertLessThan(compressed.count, original.count, "Compressed data should be smaller")
    }

    /// Test zlib with varied data
    func testZlibVariedData() throws {
        var original = Data()
        for i in 0..<10000 {
            original.append(UInt8(i % 256))
        }
        let compressed = try ZlibCompression.compress(original)
        let decompressed = try ZlibCompression.decompress(compressed, maxSize: 20000)

        XCTAssertEqual(original, decompressed)
    }

    /// Test creating an MCBitmap and saving/loading as GPX
    func testGPXSaveLoadRoundTrip() throws {
        // Create a test bitmap
        let bitmap = try PCMCBitmap()
        XCTAssertEqual(bitmap.sizeX, 160)
        XCTAssertEqual(bitmap.sizeY, 200)

        // Draw some pixels
        bitmap.setPixel(10, 10, 1)  // White
        bitmap.setPixel(20, 20, 2)  // Red
        bitmap.setPixel(50, 50, 6)  // Blue

        // Save to GPX
        let gpxData = try bitmap.saveGPX()
        XCTAssertGreaterThan(gpxData.count, 0, "GPX data should not be empty")

        // Decompress and verify header
        let maxSize = 1024 * 1024 * 20
        var decompressed = try ZlibCompression.decompress(gpxData, maxSize: maxSize)

        var version: UInt32 = 0
        var mode: UInt32 = 0
        decompressed >> version
        decompressed >> mode

        XCTAssertEqual(version, 4, "GPX version should be 4")
        XCTAssertEqual(mode, 1, "Mode should be MC_BITMAP (1)")

        // Load the GPX into a new bitmap
        let loaded = try PCMCBitmap()
        loaded.canvasModel.mode = .MC_BITMAP
        try loaded.load(file: &decompressed, type: "gpx", version: Int(version))

        // Verify dimensions match
        XCTAssertEqual(loaded.sizeX, 160)
        XCTAssertEqual(loaded.sizeY, 200)

        // Verify pixels match
        XCTAssertEqual(loaded.pixel(10, 10), bitmap.pixel(10, 10), "Pixel at (10,10) should match")
        XCTAssertEqual(loaded.pixel(20, 20), bitmap.pixel(20, 20), "Pixel at (20,20) should match")
        XCTAssertEqual(loaded.pixel(50, 50), bitmap.pixel(50, 50), "Pixel at (50,50) should match")
        XCTAssertEqual(loaded.pixel(0, 0), bitmap.pixel(0, 0), "Background pixel should match")
    }

    /// Test loading the Miss Pixcen KLA, saving as GPX, reloading, and comparing
    func testMissPixcenRoundTrip() throws {
        // Load Miss Pixcen from app bundle
        guard let asset = NSDataAsset(name: "mspixcen") else {
            XCTFail("Missing mspixcen data asset")
            return
        }

        var klaData = asset.data
        let original = try PCMCBitmap()
        try original.load(file: &klaData, type: "kla", version: 0)

        XCTAssertEqual(original.sizeX, 160)
        XCTAssertEqual(original.sizeY, 200)

        // Save as GPX
        let gpxData = try original.saveGPX()
        XCTAssertGreaterThan(gpxData.count, 100, "GPX should have substantial data")

        // Load GPX back
        var decompressed = try ZlibCompression.decompress(gpxData, maxSize: 1024 * 1024 * 20)
        var version: UInt32 = 0
        var mode: UInt32 = 0
        decompressed >> version
        decompressed >> mode

        let loaded = try PCMCBitmap()
        loaded.canvasModel.mode = .MC_BITMAP
        try loaded.load(file: &decompressed, type: "gpx", version: Int(version))

        // Compare every pixel
        var mismatches = 0
        for y in 0..<200 {
            for x in 0..<160 {
                if original.pixel(x, y) != loaded.pixel(x, y) {
                    mismatches += 1
                }
            }
        }
        XCTAssertEqual(mismatches, 0, "All 32000 pixels should match after GPX round-trip")
    }

    /// Test GPX metadata preservation
    func testGPXMetadata() throws {
        let bitmap = try PCMCBitmap()

        // Save and decompress to check metadata
        let gpxData = try bitmap.saveGPX()
        var decompressed = try ZlibCompression.decompress(gpxData, maxSize: 1024 * 1024 * 20)

        var version: UInt32 = 0
        var mode: UInt32 = 0
        decompressed >> version
        decompressed >> mode

        // Read metacount
        var metacount: UInt32 = 0
        decompressed >> metacount

        XCTAssertGreaterThan(metacount, 0, "Should have metadata entries")

        // Read and verify at least some metadata keys exist
        var meta: [String: String] = [:]
        for _ in 0..<metacount {
            let key = decompressed.readNullTerminatedASCII()
            let value = decompressed.readNullTerminatedUTF16LE()
            meta[key] = value
        }

        XCTAssertEqual(meta["xsize"], "160", "xsize metadata should be 160")
        XCTAssertEqual(meta["ysize"], "200", "ysize metadata should be 200")
        XCTAssertNotNil(meta["mapsize"], "mapsize metadata should exist")
        XCTAssertNotNil(meta["colorsize"], "colorsize metadata should exist")
        XCTAssertNotNil(meta["screensize"], "screensize metadata should exist")
    }

    /// Test undo history is preserved through GPX round-trip
    func testGPXHistoryPreservation() throws {
        let bitmap = try PCMCBitmap()

        // Make some changes with history
        bitmap.beginHistory()
        bitmap.setPixel(10, 10, 1)
        bitmap.endHistory()

        bitmap.beginHistory()
        bitmap.setPixel(20, 20, 2)
        bitmap.endHistory()

        XCTAssertTrue(bitmap.canUndo, "Should be able to undo")

        // Save and reload
        let gpxData = try bitmap.saveGPX()
        var decompressed = try ZlibCompression.decompress(gpxData, maxSize: 1024 * 1024 * 20)

        var version: UInt32 = 0
        var mode: UInt32 = 0
        decompressed >> version
        decompressed >> mode

        let loaded = try PCMCBitmap()
        loaded.canvasModel.mode = .MC_BITMAP
        try loaded.load(file: &decompressed, type: "gpx", version: Int(version))

        // Verify history was loaded
        XCTAssertTrue(loaded.canUndo, "Loaded bitmap should have undo history")
    }
}
