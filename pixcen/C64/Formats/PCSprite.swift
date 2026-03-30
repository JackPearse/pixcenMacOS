//
//  Sprite.swift
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

/// Hires sprite: 24x21 pixels per sprite, 1 bit per pixel, 64 bytes per sprite cell
class PCSprite: PCC64Interface {

    override convenience init() throws {
        try self.init(x: 24, y: 21, backbuffers: 1)
    }

    init(x: Int, y: Int, backbuffers: Int) throws {
        try super.init()

        canvasModel.mode = .SPRITE

        if x % 24 != 0 { throw C64InterfaceError.sizeMismatch("X must be divisible by 24") }
        if y % 21 != 0 { throw C64InterfaceError.sizeMismatch("Y must be divisible by 21") }

        canvasModel.xsize = x
        canvasModel.ysize = y
        canvasModel.xcell = 24
        canvasModel.ycell = 21
        canvasModel.sizecell = 21 * 3
        canvasModel.offsetcell = 64

        let cx = x / 24
        let cy = y / 21

        try self.create(mapsize: cx * cy * 64, colorsize: cx * cy, screensize: 0, backbuffers: backbuffers)

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

        let cx = x / 24
        let cy = y / 21
        let ci = cy * getCellCountX() + cx

        let d = (canvasModel.map![64 * (cy * (canvasModel.xsize / 24) + cx) + (y % 21) * 3 + (x / 8) % 3] >> (7 - (x % 8))) & 1

        switch d {
        case 0:
            return canvasModel.background![0] & 0x0f
        case 1:
            return canvasModel.color![ci] & 0x0f
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

        let cx = x / 24
        let cy = y / 21
        let ci = cy * getCellCountX() + cx

        // Determine mask: 0 = background, 1 = sprite color
        let bgColor = canvasModel.background![0] & 0x0f
        let sprColor = canvasModel.color![ci] & 0x0f
        let mask: UInt8

        if col == bgColor {
            mask = 0
        } else if col == sprColor {
            mask = 1
        } else {
            // Replace the sprite color if in replace mode
            if canvasModel.overflow == .REPLACE {
                canvasModel.color![ci] = col & 0x0f
                mask = 1
            } else {
                return
            }
        }

        let si = 64 * (cy * (canvasModel.xsize / 24) + cx) + (y % 21) * 3 + (x / 8) % 3
        let shift = 7 - (x % 8)
        let filterMask = UInt8(~(1 << shift))
        let shiftedMask = mask << shift
        canvasModel.map![si] = (canvasModel.map![si] & filterMask) | shiftedMask
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

        if len % 64 != 0 {
            // Throw PRG header
            var tmp: UInt16 = 0
            file >> tmp
            len -= 2
        }

        let num = (((len + 63) / 64) + 7) & ~7

        canvasModel.xsize = 24 * 8
        canvasModel.ysize = 21 * (num / 8)

        destroy()
        try create(mapsize: num * 64, colorsize: 3, screensize: 0, backbuffers: 1)

        canvasModel.background![0] = 0

        // Default all sprite colours to white
        if let color = canvasModel.color {
            for i in 0..<num {
                color[i] = 1
            }
        }

        file.read(canvasModel.map, len)
    }

    // MARK: - Save

    override func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }

        switch type {
        case "raw":
            guard let map = canvasModel.map else {
                throw C64InterfaceError.backbuffersMissing
            }
            var file = Data()
            let mapSize = (canvasModel.xsize / 24) * (canvasModel.ysize / 21) * 64
            file.append(map, count: mapSize)
            return file

        default:
            return try super.saveToFile(type: type)
        }
    }
}
