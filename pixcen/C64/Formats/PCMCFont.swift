//
//  MCFont.swift
//  pixcen
//
//  Created by Jack Pearse on 20.11.20.
//  Copyright © 2026 Drehwerk. All rights reserved.
//
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

/// Multicolor character mode: 4x8 cells, 2 bits per pixel, 4 colors per cell
class PCMCFont: PCCommonFont {

    override convenience init() throws {
        try self.init(x: 160, y: 200, backbuffers: 1)
    }

    init(x: Int, y: Int, backbuffers: Int) throws {
        try super.init()

        canvasModel.mode = .MC_CHAR

        if x % 4 != 0 { throw C64InterfaceError.sizeMismatch("X must be divisible by 4") }
        if y % 8 != 0 { throw C64InterfaceError.sizeMismatch("Y must be divisible by 8") }

        canvasModel.xsize = x
        canvasModel.ysize = y
        canvasModel.xcell = 4
        canvasModel.ycell = 8

        // map = y * (x/4), color = (y/8) * (x/4), screen = 0
        try self.create(mapsize: y * (x / 4),
                        colorsize: (y / 8) * (x / 4),
                        screensize: 0,
                        backbuffers: backbuffers)

        // MC Font: mask 0 = background (global), mask 1 = ext0 (global),
        //          mask 2 = ext1 (global), mask 3 = color (per cell)
        setupInfoUse()

        if canvasModel.lock != nil {
            canvasModel.lock!.pointee = 1
        }

        duplicateGlobalsToBackBuffers()
    }

    override func setupInfoUse() {
        super.setupInfoUse()
        infouse[0].use = .INFO_VALUE
        infouse[0].pp = canvasModel.background
        infouse[1].use = .INFO_VALUE
        infouse[1].pp = canvasModel.ext0
        infouse[2].use = .INFO_VALUE
        infouse[2].pp = canvasModel.ext1
        infouse[3].use = .INFO_INDEX
        infouse[3].pp = canvasModel.color
    }

    // MARK: - Pixel access (2 bits per pixel)

    override func pixel(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil,
              canvasModel.background != nil else {
            return 0
        }

        var cx = x / 4
        var cy = y / 8
        translateFontDisplay(&cx, &cy)

        let xsize = canvasModel.xsize
        let d = (canvasModel.map![cy * xsize * 2 + cx * 8 + (y % 8)] >> (2 * (3 - (x % 4)))) & 3

        switch d {
        case 0:
            return canvasModel.background![0]
        case 1:
            return canvasModel.ext0 != nil ? canvasModel.ext0![0] : 0
        case 2:
            return canvasModel.ext1 != nil ? canvasModel.ext1![0] : 0
        case 3:
            return canvasModel.color != nil ? canvasModel.color![getCellCountX() * cy + cx] : 0
        default:
            return 0
        }
    }

    override var pixelWidth: Int { return 2 }

    override func setPixel(_ x: Int, _ y: Int, _ col: UInt8) {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil else {
            return
        }

        var cx = x / 4
        var cy = y / 8
        translateFontDisplay(&cx, &cy)

        let ci = cy * (canvasModel.xsize / 4) + cx

        let currentMask = getMask(x, y)
        guard let mask = resolveMask2(ci: ci, col: col, pointMask: currentMask) else {
            return
        }

        setColor(ci: ci, mask: mask, col: col)

        let mi = cy * canvasModel.xsize * 2 + cx * 8 + (y % 8)
        let shift = 2 * (3 - (x % 4))
        let filterMask: UInt8 = ~(UInt8(3) << shift)
        let shiftedMask: UInt8 = UInt8(mask) << shift
        canvasModel.map![mi] = (canvasModel.map![mi] & filterMask) | shiftedMask
    }

    private func getMask(_ x: Int, _ y: Int) -> Int {
        var cx = x / 4
        var cy = y / 8
        translateFontDisplay(&cx, &cy)
        return Int((canvasModel.map![cy * canvasModel.xsize * 2 + cx * 8 + (y % 8)] >> (2 * (3 - (x % 4)))) & 3)
    }

    // MARK: - Cell Info

    override func cellInfo(cx: Int, cy: Int, w: Int, h: Int, info: inout CellInfo) {
        info.w = canvasModel.xcell
        info.h = canvasModel.ycell

        let cellCountX = canvasModel.xsize / canvasModel.xcell

        // Mask 0: background (global)
        if let bg = canvasModel.background {
            info.col[0] = bg[0] & 0x0f
        } else {
            info.col[0] = 0xff
        }
        info.crippled[0] = 1

        // Mask 1: ext0 (global)
        if let ext0 = canvasModel.ext0 {
            info.col[1] = ext0[0] & 0x0f
        } else {
            info.col[1] = 0xff
        }
        info.crippled[1] = 1

        // Mask 2: ext1 (global)
        if let ext1 = canvasModel.ext1 {
            info.col[2] = ext1[0] & 0x0f
        } else {
            info.col[2] = 0xff
        }
        info.crippled[2] = 1

        // Mask 3: color (per cell)
        if let color = canvasModel.color, cx >= 0, cy >= 0,
           cx < cellCountX, cy < canvasModel.ysize / canvasModel.ycell {
            info.col[3] = color[cy * cellCountX + cx] & 0x0f
        } else {
            info.col[3] = 0xff
        }
        info.crippled[3] = 0

        for i in 4..<6 { info.col[i] = 0xff }
    }

    // MARK: - Load

    override func load(file: inout Data, type: String, version: Int) throws {
        try super.load(file: &file, type: type, version: version)

        if type == "raw" {
            try loadRaw(file: &file)
        }
    }

    private func loadRaw(file: inout Data) throws {
        var len = file.count

        if len % 8 != 0 {
            // Throw PRG header
            var tmp: UInt16 = 0
            file >> tmp
            len -= 2
        }

        canvasModel.xsize = 32 * 4
        canvasModel.ysize = ((len + 255) / 256) * 8

        destroy()
        try create(mapsize: canvasModel.ysize * (canvasModel.xsize / 4),
                   colorsize: 3,
                   screensize: 0,
                   backbuffers: 1)

        canvasModel.background![0] = 0
        if let color = canvasModel.color {
            color[0] = 11
            color[1] = 12
            color[2] = 1
        }

        file.read(canvasModel.map, len)
    }

    // MARK: - Save

    override func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }
        return try super.saveToFile(type: type)
    }
}
