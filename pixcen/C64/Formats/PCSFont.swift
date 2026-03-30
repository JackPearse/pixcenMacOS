//
//  SFont.swift
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

/// Hires character mode: 8x8 cells, 1 bit per pixel, 2 colors per cell
class PCSFont: PCCommonFont {

    override convenience init() throws {
        try self.init(x: 320, y: 200, backbuffers: 1)
    }

    init(x: Int, y: Int, backbuffers: Int) throws {
        try super.init()

        canvasModel.mode = .CHAR

        if x % 8 != 0 { throw C64InterfaceError.sizeMismatch("X must be divisible by 8") }
        if y % 8 != 0 { throw C64InterfaceError.sizeMismatch("Y must be divisible by 8") }

        canvasModel.xsize = x
        canvasModel.ysize = y
        canvasModel.xcell = 8
        canvasModel.ycell = 8

        let colsize = (x / 8) * (y / 8)

        // map = y * (x/8), color = colsize, screen = 0
        try self.create(mapsize: y * (x / 8), colorsize: colsize, screensize: 0, backbuffers: backbuffers)

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
        infouse[1].use = .INFO_INDEX
        infouse[1].pp = canvasModel.color
    }

    // MARK: - Pixel access (1 bit per pixel)

    override func pixel(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil,
              canvasModel.background != nil,
              canvasModel.color != nil else {
            return 0
        }

        var cx = x / 8
        var cy = y / 8
        translateFontDisplay(&cx, &cy)

        let xsize = canvasModel.xsize
        let d = (canvasModel.map![cy * xsize + cx * 8 + (y % 8)] >> (7 - (x % 8))) & 1

        switch d {
        case 0:
            return canvasModel.background![0] & 0x0f
        case 1:
            return canvasModel.color![getCellCountX() * cy + cx] & 0x0f
        default:
            return 0
        }
    }

    override var pixelWidth: Int { return 1 }

    override func setPixel(_ x: Int, _ y: Int, _ col: UInt8) {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil,
              canvasModel.background != nil,
              canvasModel.color != nil else {
            return
        }

        var cx = x / 8
        var cy = y / 8
        translateFontDisplay(&cx, &cy)

        let ci = cy * (canvasModel.xsize / 8) + cx

        // Simple 1-bit mask resolution
        let bgColor = canvasModel.background![0] & 0x0f
        let fgColor = canvasModel.color![ci] & 0x0f
        let mask: UInt8

        if col == bgColor {
            mask = 0
        } else if col == fgColor {
            mask = 1
        } else {
            if canvasModel.overflow == .REPLACE {
                canvasModel.color![ci] = col & 0x0f
                mask = 1
            } else {
                return
            }
        }

        let mi = cy * canvasModel.xsize + cx * 8 + (y % 8)
        let shift = 7 - (x % 8)
        let filterMask = UInt8(~(1 << shift))
        let shiftedMask = mask << shift
        canvasModel.map![mi] = (canvasModel.map![mi] & filterMask) | shiftedMask
    }

    // MARK: - Cell Info

    override func cellInfo(cx: Int, cy: Int, w: Int, h: Int, info: inout CellInfo) {
        info.w = canvasModel.xcell
        info.h = canvasModel.ycell

        let cellCountX = canvasModel.xsize / canvasModel.xcell

        if let bg = canvasModel.background {
            info.col[0] = bg[0] & 0x0f
        } else {
            info.col[0] = 0xff
        }
        info.crippled[0] = 1

        if let color = canvasModel.color, cx >= 0, cy >= 0,
           cx < cellCountX, cy < canvasModel.ysize / canvasModel.ycell {
            info.col[1] = color[cy * cellCountX + cx] & 0x0f
        } else {
            info.col[1] = 0xff
        }
        info.crippled[1] = 0

        for i in 2..<6 { info.col[i] = 0xff }
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

        canvasModel.xsize = 32 * 8
        canvasModel.ysize = ((len + 255) / 256) * 8

        destroy()

        let colsize = (canvasModel.ysize / 8) * (canvasModel.xsize / 8)
        try create(mapsize: canvasModel.ysize * (canvasModel.xsize / 8),
                   colorsize: colsize,
                   screensize: 0,
                   backbuffers: 1)

        canvasModel.background![0] = 0

        // Default all character colors to white
        if let color = canvasModel.color {
            for i in 0..<colsize {
                color[i] = 1
            }
        }

        file.read(canvasModel.map, len)
    }

    // MARK: - Save

    override func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }
        return try super.saveToFile(type: type)
    }
}
