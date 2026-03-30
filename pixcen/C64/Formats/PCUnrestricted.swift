//
//  Unrestricted.swift
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

/// Unrestricted mode: any color per pixel, no cell constraints.
/// Wide mode (W_UNRESTRICTED) uses 2x pixel width.
class PCUnrestricted: PCC64Interface {

    override convenience init() throws {
        try self.init(x: 320, y: 200, wide: false, backbuffers: 1)
    }

    convenience init(wide: Bool) throws {
        if wide {
            try self.init(x: 160, y: 200, wide: true, backbuffers: 1)
        } else {
            try self.init(x: 320, y: 200, wide: false, backbuffers: 1)
        }
    }

    init(x: Int, y: Int, wide: Bool, backbuffers: Int) throws {
        try super.init()

        if wide {
            canvasModel.mode = .W_UNRESTRICTED
            canvasModel.offsetcell = 4
            canvasModel.xcell = 4
        } else {
            canvasModel.mode = .UNRESTRICTED
            canvasModel.offsetcell = 8
            canvasModel.xcell = 8
        }

        canvasModel.xsize = x
        canvasModel.ysize = y
        canvasModel.ycell = 8

        // map = x*y (one byte per pixel), no color/screen RAM
        try self.create(mapsize: x * y, colorsize: 0, screensize: 0, backbuffers: backbuffers)
    }

    // MARK: - Pixel access (direct nibble per pixel)

    override func pixel(_ x: Int, _ y: Int) -> UInt8 {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil else {
            return 0
        }
        return canvasModel.map![y * canvasModel.xsize + x]
    }

    override var pixelWidth: Int {
        return canvasModel.mode == .W_UNRESTRICTED ? 2 : 1
    }

    override func setPixel(_ x: Int, _ y: Int, _ col: UInt8) {
        guard x >= 0, x < canvasModel.xsize,
              y >= 0, y < canvasModel.ysize,
              canvasModel.map != nil else {
            return
        }
        canvasModel.map![y * canvasModel.xsize + x] = col & 0x0f
    }

    // MARK: - Cell Info

    override func cellInfo(cx: Int, cy: Int, w: Int, h: Int, info: inout CellInfo) {
        info.h = 8
        info.w = 8 / pixelWidth

        // Unrestricted: all colors are valid, mark as 0xff (no constraint)
        for i in 0..<6 {
            info.col[i] = 0xff
        }
    }

    // MARK: - Save

    override func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }

        // Override map save for unrestricted: pack each pixel as doubled nibble
        if type == "map" {
            var file = Data()
            for y in 0..<canvasModel.ysize {
                for x in 0..<canvasModel.xsize {
                    var b = pixel(x, y) & 0x0f
                    b = b | (b << 4)
                    file.append(b)
                }
            }
            return file
        }

        return try super.saveToFile(type: type)
    }
}
