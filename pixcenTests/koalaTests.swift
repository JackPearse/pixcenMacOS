//
//  koalaTests.swift
//  pixcenTests
//
//  Tests for Koala (.kla/.koa) file format loading.
//

import XCTest
@testable import pixcen

final class KoalaTests: XCTestCase {

    func testLoadMissPixcen() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else {
            XCTFail("Missing mspixcen data asset")
            return
        }
        var data = asset.data
        XCTAssertEqual(data.count, 10003, "Koala file should be 10003 bytes")

        let bitmap = try PCMCBitmap()
        try bitmap.load(file: &data, type: "kla", version: 0)

        XCTAssertEqual(bitmap.sizeX, 160)
        XCTAssertEqual(bitmap.sizeY, 200)
        XCTAssertEqual(bitmap.pixelWidth, 2)
        XCTAssertEqual(bitmap.cellSizeX, 4)
        XCTAssertEqual(bitmap.cellSizeY, 8)
    }

    func testKLAHasPixelData() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else {
            XCTFail("Missing mspixcen data asset")
            return
        }
        var data = asset.data
        let bitmap = try PCMCBitmap()
        try bitmap.load(file: &data, type: "kla", version: 0)

        var nonZero = 0
        for y in 0..<200 {
            for x in 0..<160 {
                if bitmap.pixel(x, y) != 0 { nonZero += 1 }
            }
        }
        XCTAssertGreaterThan(nonZero, 1000, "Should have substantial pixel data")
    }

    func testKLAInvalidSize() throws {
        var data = Data(repeating: 0, count: 100)
        let bitmap = try PCMCBitmap()
        XCTAssertThrowsError(try bitmap.load(file: &data, type: "kla", version: 0))
    }

    func testKOAEqualsKLA() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else {
            XCTFail("Missing mspixcen data asset")
            return
        }
        var d1 = asset.data
        var d2 = asset.data

        let b1 = try PCMCBitmap()
        try b1.load(file: &d1, type: "kla", version: 0)
        let b2 = try PCMCBitmap()
        try b2.load(file: &d2, type: "koa", version: 0)

        for y in 0..<200 {
            for x in 0..<160 {
                XCTAssertEqual(b1.pixel(x, y), b2.pixel(x, y))
            }
        }
    }

    func testCellInfo() throws {
        guard let asset = NSDataAsset(name: "mspixcen") else {
            XCTFail("Missing mspixcen data asset")
            return
        }
        var data = asset.data
        let bitmap = try PCMCBitmap()
        try bitmap.load(file: &data, type: "kla", version: 0)

        var info = CellInfo()
        bitmap.cellInfo(cx: 0, cy: 0, w: 1, h: 1, info: &info)

        XCTAssertNotEqual(info.col[0], 0xff, "Background should be set")
        XCTAssertLessThanOrEqual(info.col[0], 15)
    }
}
