//
//  Bitmap.swift
//  pixcen
//
//  Created by Jack Pearse on 20.11.20.
//  Copyright © 2026 Drehwerk. All rights reserved.
//
//  Pixcen - A windows platform low level pixel editor for C64
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

import Foundation

/// Standard hires bitmap (320x200, 1 bit per pixel, 8x8 cells)
/// Each cell has 2 colors from screen RAM (low nibble = bg, high nibble = fg)
class PCBitmap: PCC64Interface {

    override convenience init() throws {
        try self.init(x: 320, y: 200, backbuffers: 1)
    }

    init(x: Int, y: Int, backbuffers: Int) throws {
        try super.init()

        canvasModel.mode = .BITMAP

        if x % 8 != 0 { throw C64InterfaceError.sizeMismatch("X must be divisible by 8") }
        if y % 8 != 0 { throw C64InterfaceError.sizeMismatch("Y must be divisible by 8") }

        canvasModel.xsize = x
        canvasModel.ysize = y
        canvasModel.xcell = 8
        canvasModel.ycell = 8

        // mapsize = y * (x/8), colorsize = 0, screensize = (y/8) * (x/8)
        try self.create(mapsize: y * (x / 8),
                        colorsize: 0,
                        screensize: (y / 8) * (x / 8),
                        backbuffers: backbuffers)

        setupInfoUse()
        duplicateGlobalsToBackBuffers()
    }

    override func setupInfoUse() {
        super.setupInfoUse()
        infouse[0].use = .INFO_INDEX_LOW
        infouse[0].pp = canvasModel.screen
        infouse[1].use = .INFO_INDEX_HIGH
        infouse[1].pp = canvasModel.screen
    }

    // MARK: - Pixel access (1 bit per pixel)

    override func pixel(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil, canvasModel.screen != nil else {
            return 0
        }

        let xsize = canvasModel.xsize
        let cx = x / 8
        let cy = y / 8

        // 1 bit per pixel: map[cy * xsize + cx * 8 + (y%8)], bit (7 - (x%8))
        let d = (canvasModel.map![cy * xsize + cx * 8 + (y % 8)] >> (7 - (x % 8))) & 1

        let ci = cy * (xsize / 8) + cx
        switch d {
        case 0:
            return canvasModel.screen![ci] & 0x0f      // low nibble
        case 1:
            return canvasModel.screen![ci] >> 4         // high nibble
        default:
            return 0
        }
    }

    override var pixelWidth: Int { return 1 }  // hires = 1:1 pixels

    override func setPixel(_ x: Int, _ y: Int, _ col: UInt8) {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil, canvasModel.screen != nil else {
            return
        }

        let xsize = canvasModel.xsize
        let cx = x / 8
        let cy = y / 8
        let ci = cy * (xsize / 8) + cx

        // Determine which mask (0 or 1) matches the requested color
        let lowColor = canvasModel.screen![ci] & 0x0f
        let highColor = canvasModel.screen![ci] >> 4

        let mask: UInt8
        if col == lowColor {
            mask = 0
        } else if col == highColor {
            mask = 1
        } else if lowColor == highColor {
            // Both slots same color, assign the new color to the high nibble
            canvasModel.screen![ci] = (canvasModel.screen![ci] & 0x0f) | (col << 4)
            mask = 1
        } else {
            // Color doesn't fit in this cell - replace based on overflow mode
            if canvasModel.overflow == .REPLACE {
                let currentMask = getMask(x, y)
                if currentMask == 0 {
                    canvasModel.screen![ci] = (canvasModel.screen![ci] & 0xf0) | (col & 0x0f)
                } else {
                    canvasModel.screen![ci] = (canvasModel.screen![ci] & 0x0f) | (col << 4)
                }
                mask = UInt8(currentMask)
            } else {
                return  // NOTHING/IGNORE
            }
        }

        let mi = cy * xsize + cx * 8 + (y % 8)
        let shift = 7 - (x % 8)
        let filterMask: UInt8 = ~(UInt8(1) << shift)
        let shiftedMask: UInt8 = mask << shift
        canvasModel.map![mi] = (canvasModel.map![mi] & filterMask) | shiftedMask
    }

    private func getMask(_ x: Int, _ y: Int) -> Int {
        let cx = x / 8
        let cy = y / 8
        let mi = cy * canvasModel.xsize + cx * 8 + (y % 8)
        return Int((canvasModel.map![mi] >> (7 - (x % 8))) & 1)
    }

    // MARK: - Load

    override func load(file: inout Data, type: String, version: Int) throws {
        try super.load(file: &file, type: type, version: version)

        switch type {
        case "art":
            try loadART(file: &file)
        case "dd", "ddl":
            try loadDD(file: &file)
        case "jj":
            try loadJJ(file: &file)
        case "binhi":
            try loadBINHI(file: &file)
        default:
            break
        }
    }

    // MARK: - Save

    override func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }

        guard canvasModel.xsize == 320, canvasModel.ysize == 200 else {
            throw C64InterfaceError.sizeMismatch("Buffers are not standard 320x200 hires")
        }
        guard let map = canvasModel.map, let screen = canvasModel.screen else {
            throw C64InterfaceError.backbuffersMissing
        }

        var file = Data()

        switch type {
        case "art":
            // Art Studio: addr(2) + map(8000) + screen(1000) = 9002
            var addr: UInt16 = 0x2000
            file.append(Data(bytes: &addr, count: 2))
            file.append(map, count: 8000)
            file.append(screen, count: 1000)

        case "dd":
            // Doodle: addr(2) + screen(1000) + 24pad + map(8000) + 192pad = 9218
            var addr: UInt16 = 0x5c00
            file.append(Data(bytes: &addr, count: 2))
            file.append(screen, count: 1000)
            file.append(Data(repeating: 0, count: 24))
            file.append(map, count: 8000)
            file.append(Data(repeating: 0, count: 192))

        case "jj":
            // Doodle compressed: same layout as Doodle but Koala RLE compressed
            var src = Data(count: 9216)
            src.replaceSubrange(0..<1000, with: Data(bytes: screen, count: 1000))
            // bytes 1000-1023 stay zero (padding)
            src.replaceSubrange(1024..<9024, with: Data(bytes: map, count: 8000))
            let compressed = try C64Codecs.compressKoala(data: src)
            var jjAddr: UInt16 = 0x5c00
            file.append(Data(bytes: &jjAddr, count: 2))
            file.append(compressed)

        case "bin":
            // Multipaint BIN (Hires Bitmap): 88000 bytes total
            // Border (1 byte)
            if let border = canvasModel.border {
                file.append(border, count: 1)
            } else {
                file.append(0 as UInt8)
            }

            // Header: [0xFF, 0x00, 0x00, 0x0F, 0x28, 0x00, 0x19] + 4 zeros + byte(3)
            let binHiHeader: [UInt8] = [0xFF, 0x00, 0x00, 0x0F, 0x28, 0x00, 0x19]
            file.append(contentsOf: binHiHeader)
            file.append(Data(repeating: 0, count: 4))
            file.append(UInt8(3))

            // Pad to 0x103
            while file.count < 0x103 {
                file.append(0 as UInt8)
            }

            // Meta bytes (same as MCBitmap BIN)
            let binMeta: [UInt8] = [
                0xFF, 0xFF, 0xFF, 0x68, 0x37, 0x2B, 0x70, 0xA4,
                0xB2, 0x6F, 0x3D, 0x86, 0x58, 0x8D, 0x43, 0x35,
                0x28, 0x79, 0xB8, 0xC7, 0x6F, 0x6F, 0x4F, 0x25,
                0x43, 0x39, 0x00, 0x9A, 0x67, 0x59, 0x44, 0x44,
                0x44, 0x6C, 0x6C, 0x6C, 0x9A, 0xD2, 0x84, 0x6C,
                0x5E, 0xB5, 0x95, 0x95, 0x95
            ]
            file.append(contentsOf: binMeta)

            // Pad to 0x400
            while file.count < 0x400 {
                file.append(0 as UInt8)
            }

            // Write bitmap: expand each map byte into 8 separate bytes (one per bit)
            for y in 0..<200 {
                for x in 0..<40 {
                    let mapindex = (y / 8) * 320 + (y % 8) + x * 8
                    let mapByte = map[mapindex]
                    for bit in stride(from: 7, through: 0, by: -1) {
                        file.append((mapByte >> bit) & 1)
                    }
                }
            }

            // Pad to 0x10000
            while file.count < 0x10000 {
                file.append(0 as UInt8)
            }

            // Write screen high nibbles: for each of 25 rows, repeat 8 times
            for y in 0..<25 {
                for _ in 0..<8 {
                    for x in 0..<40 {
                        file.append(screen[y * 40 + x] >> 4)
                    }
                }
            }
            // Write screen low nibbles: for each of 25 rows, repeat 8 times
            for y in 0..<25 {
                for _ in 0..<8 {
                    for x in 0..<40 {
                        file.append(screen[y * 40 + x] & 0x0f)
                    }
                }
            }

            // Pad to 88000 total
            while file.count < 88000 {
                file.append(0 as UInt8)
            }

        case "prg":
            // C64 self-extracting PRG (hires bitmap viewer + data, ByteBoozer compressed)
            let viewer: [UInt8] = [
                0x00, 0x1f, 0x78, 0xa9, 0x3b, 0x8d, 0x11, 0xd0,
                0xa9, 0x08, 0x8d, 0x16, 0xd0, 0xa9, 0x18, 0x8d,
                0x18, 0xd0, 0xa2, 0x00, 0xbd, 0x40, 0x3f, 0x9d,
                0x00, 0x04, 0xbd, 0x40, 0x40, 0x9d, 0x00, 0x05,
                0xbd, 0x40, 0x41, 0x9d, 0x00, 0x06, 0xbd, 0x40,
                0x42, 0x9d, 0x00, 0x07, 0xe8, 0xd0, 0xe5, 0xad,
                0x28, 0x43, 0x8d, 0x20, 0xd0, 0x4c, 0x33, 0x1f
            ]

            file.append(contentsOf: viewer)
            // Pad to 256 bytes (viewer.count - 2 bytes for prg header)
            var pad = viewer.count - 2
            while pad < 256 {
                file.append(0 as UInt8)
                pad += 1
            }
            file.append(map, count: 8000)
            file.append(screen, count: 1000)
            if let border = canvasModel.border {
                file.append(border, count: 1)
            } else {
                file.append(0 as UInt8)
            }

            // ByteBoozer crunch with start address 0x1F00
            return try ByteBoozer.crunch(data: file, startAddress: 0x1F00)

        default:
            return try super.saveToFile(type: type)
        }

        return file
    }

    // MARK: - Cell Info

    override func cellInfo(cx: Int, cy: Int, w: Int, h: Int, info: inout CellInfo) {
        info.w = canvasModel.xcell
        info.h = canvasModel.ycell

        let cellCountX = canvasModel.xsize / canvasModel.xcell

        // Hires: 2 colors from screen RAM
        if let screen = canvasModel.screen, cx >= 0, cy >= 0,
           cx < cellCountX, cy < canvasModel.ysize / canvasModel.ycell {
            let ci = cy * cellCountX + cx
            info.col[0] = screen[ci] & 0x0f     // low nibble (background)
            info.col[1] = screen[ci] >> 4        // high nibble (foreground)
        } else {
            info.col[0] = 0xff
            info.col[1] = 0xff
        }
        info.crippled[0] = 0
        info.crippled[1] = 0

        // Unused masks
        for i in 2..<6 { info.col[i] = 0xff }
    }

    // MARK: - Private loaders

    private func loadART(file: inout Data) throws {
        guard file.count == 9002 || file.count == 9009 else {
            throw C64InterfaceError.sizeMismatch("Invalid Art Studio file size")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        var addr: UInt16 = 0
        file >> addr

        file.read(canvasModel.map, 8000)
        file.read(canvasModel.screen, 1000)

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }

    private func loadDD(file: inout Data) throws {
        guard file.count == 9218 else {
            throw C64InterfaceError.sizeMismatch("Invalid Doodle file size")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        var addr: UInt16 = 0
        file >> addr

        file.read(canvasModel.screen, 1000)
        file = file.advanced(by: 24)  // skip padding
        file.read(canvasModel.map, 8000)

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }

    private func loadBINHI(file: inout Data) throws {
        guard file.count == 88000 else {
            throw C64InterfaceError.sizeMismatch("Invalid Multipaint Hires file size (expected 88000)")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        // Read border (1 byte)
        if canvasModel.border != nil {
            file.read(canvasModel.border, 1)
        } else {
            file = file.advanced(by: 1)
        }

        // Seek to 0x0400 (skip past header; we already read 1 byte)
        file = Data(file.suffix(from: file.startIndex.advanced(by: 0x0400 - 1)))

        // Read bitmap: 200 rows x 40 columns, pack 8 bytes into 1 byte each
        for y in 0..<200 {
            for x in 0..<40 {
                let mapindex = (y / 8) * 320 + (y % 8) + x * 8
                var tmp: UInt8 = 0
                for bit in stride(from: 7, through: 0, by: -1) {
                    let b = file[file.startIndex]
                    file = file.advanced(by: 1)
                    tmp |= (b & 1) << bit
                }
                canvasModel.map![mapindex] = tmp
            }
        }

        // Seek to position 0x10000 (advance past remaining bitmap padding)
        let currentOffset = 0x0400 + 200 * 40 * 8
        let skipAmount = 0x10000 - currentOffset
        file = file.advanced(by: skipAmount)

        // Read screen high nibbles: for y in 0..<25, x in 0..<40, then skip 7*40 bytes
        for y in 0..<25 {
            for x in 0..<40 {
                let b = file[file.startIndex]
                file = file.advanced(by: 1)
                canvasModel.screen![y * 40 + x] = b << 4
            }
            // Skip 7*40 bytes (repeated rows)
            file = file.advanced(by: 7 * 40)
        }

        // Read screen low nibbles: for y in 0..<25, x in 0..<40, then skip 7*40 bytes
        for y in 0..<25 {
            for x in 0..<40 {
                let b = file[file.startIndex]
                file = file.advanced(by: 1)
                canvasModel.screen![y * 40 + x] |= b & 0x0f
            }
            // Skip 7*40 bytes (repeated rows)
            file = file.advanced(by: 7 * 40)
        }
    }

    private func loadJJ(file: inout Data) throws {
        guard canvasModel.map != nil, canvasModel.screen != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        // Skip 2-byte PRG header, decompress using Koala RLE to 9216 bytes
        let stream = file.advanced(by: 2)
        var buffer = try C64Codecs.decompressKoala(stream: stream, outputSize: 9216)

        // First 1000 bytes = screen
        buffer.read(canvasModel.screen, 1000)
        // Skip 24 bytes padding (bytes 1000-1023)
        buffer = buffer.advanced(by: 24)
        // Next 8000 bytes = map
        buffer.read(canvasModel.map, 8000)

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }
}
