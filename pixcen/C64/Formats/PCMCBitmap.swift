//
//  MCBitmap.swift
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
//import PixcenFoundation // TODO: Remove if not needed anymore. Contains typedefs like BYTE


class PCMCBitmap: PCC64Interface {
    
    /// Default initializer, like in Windows versione in File C64Interface.h:
    /// MCBitmap(int x=160, int y=200, int backbuffers=1);
    override convenience init() throws {
        
        try self.init(x:160, y:200, backbuffers:1)
    }
    
    init(x:Int, y:Int, backbuffers:Int) throws {
        
        try super.init()
        
        canvasModel.mode = .MC_BITMAP

        if x%4 != 0 { throw C64InterfaceError.sizeMismatch("X must be divisible by 4") }
        if y%8 != 0 { throw C64InterfaceError.sizeMismatch("Y must be divisible by 8") }
                
        canvasModel.xsize = x
        canvasModel.ysize = y

        canvasModel.xcell = 4
        canvasModel.ycell = 8

        do {
        
            try self.create(mapsize: y * (x/4), colorsize: (y/8) * (x/4), screensize: (y/8) * (x/4), backbuffers: backbuffers)
        } catch {
            
            assertionFailure("\(error)")
        }

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
        infouse[1].use = .INFO_INDEX_HIGH
        infouse[1].pp = canvasModel.screen
        infouse[2].use = .INFO_INDEX_LOW
        infouse[2].pp = canvasModel.screen
        infouse[3].use = .INFO_INDEX
        infouse[3].pp = canvasModel.color
    }

    override func pixel(_ x: Int, _ y: Int) -> UInt8 {

        guard x >= 0,
              x <  self.canvasModel.xsize,
              y >= 0,
              y < self.canvasModel.ysize,
              self.canvasModel.map != nil,
              self.canvasModel.background != nil,
              self.canvasModel.screen != nil,
              self.canvasModel.color != nil else {
        
            return 0
        }

        let xsize = self.canvasModel.xsize
        let cx = x / 4
        let cy = y / 8

        let d = (self.canvasModel.map![cy * xsize * 2 + cx * 8 + (y % 8)] >> (2 * (3 - (x % 4)))) & 3

        var b:UInt8 = 0
        switch d {
        case 0:
            b = self.canvasModel.background![0]
            
        case 1:
            b = self.canvasModel.screen![cy * (xsize / 4) + cx] >> 4
            
        case 2:
            b = self.canvasModel.screen![cy * (xsize / 4) + cx] & 0x0f
            
        case 3:
            b = self.canvasModel.color![cy * (xsize / 4) + cx]
            
            
        default:
            break
        }

        return b
    }
    
    // MARK: - Cell Info

    override func cellInfo(cx: Int, cy: Int, w: Int, h: Int, info: inout CellInfo) {
        info.w = canvasModel.xcell
        info.h = canvasModel.ycell

        let cellCountX = canvasModel.xsize / canvasModel.xcell

        // Mask 0: Background (global value)
        if let bg = canvasModel.background {
            info.col[0] = bg[0] & 0x0f
        } else {
            info.col[0] = 0xff
        }
        info.crippled[0] = 1  // global, always crippled (shared)

        // Mask 1: Screen RAM high nibble (per cell)
        if let screen = canvasModel.screen, cx >= 0, cy >= 0,
           cx < cellCountX, cy < canvasModel.ysize / canvasModel.ycell {
            info.col[1] = screen[cy * cellCountX + cx] >> 4
        } else {
            info.col[1] = 0xff
        }
        info.crippled[1] = 0

        // Mask 2: Screen RAM low nibble (per cell)
        if let screen = canvasModel.screen, cx >= 0, cy >= 0,
           cx < cellCountX, cy < canvasModel.ysize / canvasModel.ycell {
            info.col[2] = screen[cy * cellCountX + cx] & 0x0f
        } else {
            info.col[2] = 0xff
        }
        info.crippled[2] = 0

        // Mask 3: Color RAM (per cell)
        if let color = canvasModel.color, cx >= 0, cy >= 0,
           cx < cellCountX, cy < canvasModel.ysize / canvasModel.ycell {
            info.col[3] = color[cy * cellCountX + cx] & 0x0f
        } else {
            info.col[3] = 0xff
        }
        info.crippled[3] = 0

        // Masks 4-5: unused in MC bitmap
        info.col[4] = 0xff
        info.col[5] = 0xff
    }

    // MARK: - Save

    override func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }

        guard canvasModel.xsize == 160, canvasModel.ysize == 200 else {
            throw C64InterfaceError.sizeMismatch("Buffers are not standard 160x200 multicolor")
        }
        guard let map = canvasModel.map,
              let screen = canvasModel.screen,
              let color = canvasModel.color,
              let background = canvasModel.background else {
            throw C64InterfaceError.backbuffersMissing
        }

        var file = Data()

        switch type {
        case "kla", "koa":
            // Koala: addr(2) + map(8000) + screen(1000) + color(1000) + bg(1) = 10003
            var addr: UInt16 = 0x6000
            file.append(Data(bytes: &addr, count: 2))
            file.append(map, count: 8000)
            file.append(screen, count: 1000)
            file.append(color, count: 1000)
            file.append(background, count: 1)

        case "ocp":
            // Advanced Art Studio: addr + map + screen + border + bg + 14 pad + color = 10018
            var addr: UInt16 = 0x2000
            file.append(Data(bytes: &addr, count: 2))
            file.append(map, count: 8000)
            file.append(screen, count: 1000)
            if let border = canvasModel.border {
                file.append(border, count: 1)
            } else {
                file.append(0 as UInt8)
            }
            file.append(background, count: 1)
            file.append(Data(repeating: 0, count: 14))
            file.append(color, count: 1000)

        case "cen":
            // Cenimate: addr + color + 24pad + screen + 24pad + map + bg = 10051
            var addr: UInt16 = 0x5800
            file.append(Data(bytes: &addr, count: 2))
            file.append(color, count: 1000)
            file.append(Data(repeating: 0, count: 24))
            file.append(screen, count: 1000)
            file.append(Data(repeating: 0, count: 24))
            file.append(map, count: 8000)
            file.append(background, count: 1)

        case "pmg":
            // Paint Magic: addr + viewer + pad + map + bg + 2pad + color + border + pad + screen + pad
            guard canvasModel.xsize == 160, canvasModel.ysize == 200 else {
                throw C64InterfaceError.sizeMismatch("Buffers are not standard 160x200 multicolor")
            }
            guard canvasModel.crippled != nil, canvasModel.crippled![3] != 0 else {
                throw C64InterfaceError.failed(0, "Paint Magic requires crippled color RAM (single color)")
            }

            let viewer: [UInt8] = [
                0x0b,0x08,0x0a,0x00,0x9e,0x32,0x30,0x36,0x39,0x00,0x13,0x08,0x14,0x00,
                0x89,0x32,0x30,0x00,0x00,0x00,0xa0,0x00,0x8c,0x11,0xd0,0xa2,0x24,0xb9,0x73,0x08,
                0x99,0x00,0x40,0xc8,0xd0,0xf7,0xee,0x1e,0x08,0xee,0x21,0x08,0xca,0xd0,0xee,0xa9,
                0x00,0x8d,0x11,0xd0,0xad,0x44,0x5f,0x8d,0x20,0xd0,0xad,0x00,0xdd,0x29,0xfc,0x09,
                0x02,0x8d,0x00,0xdd,0xa9,0x80,0x8d,0x18,0xd0,0xa9,0xd8,0x8d,0x16,0xd0,0xad,0x40,
                0x5f,0x8d,0x21,0xd0,0xad,0x43,0x5f,0xa0,0x00,0x99,0x00,0xd8,0x99,0x00,0xd9,0x99,
                0x00,0xda,0x99,0x00,0xdb,0xc8,0xd0,0xf1,0xa9,0x3b,0x8d,0x11,0xd0,0x60,0x48,0x81,
                0x71,0x80,0x71,0x80
            ]

            var pmgAddr: UInt16 = 0x3f8e
            file.append(Data(bytes: &pmgAddr, count: 2))
            file.append(contentsOf: viewer)
            var currentAddr = 0x3f8e + viewer.count
            while currentAddr < 0x4000 {
                file.append(0 as UInt8)
                currentAddr += 1
            }
            file.append(map, count: 8000)
            file.append(background, count: 1)
            file.append(0 as UInt8)
            file.append(0 as UInt8)
            file.append(color, count: 1)  // single color value
            if let border = canvasModel.border {
                file.append(border, count: 1)
            } else {
                file.append(0 as UInt8)
            }
            currentAddr = 0x5f45
            while currentAddr < 0x6000 {
                file.append(0 as UInt8)
                currentAddr += 1
            }
            file.append(screen, count: 1000)
            currentAddr = 0x63e8
            while currentAddr < 0x6400 {
                file.append(0 as UInt8)
                currentAddr += 1
            }

        case "mg":
            // Multigraf: addr + map + 175pad + bg + "MULTIGRAF V1.30\0" + screen + 24pad + color + 24pad + 1024pad
            var addr: UInt16 = 0x3000
            file.append(Data(bytes: &addr, count: 2))
            file.append(map, count: 8000)
            file.append(Data(repeating: 0, count: 175))
            file.append(background, count: 1)
            let tag: [UInt8] = [0x4D, 0x55, 0x4C, 0x54, 0x49, 0x47, 0x52, 0x41,
                                0x46, 0x20, 0x56, 0x31, 0x2E, 0x33, 0x30, 0x00]
            file.append(contentsOf: tag)
            file.append(screen, count: 1000)
            file.append(Data(repeating: 0, count: 24))
            file.append(color, count: 1000)
            file.append(Data(repeating: 0, count: 24))
            file.append(Data(repeating: 0, count: 1024))

        case "prg":
            // C64 self-extracting PRG (viewer + data, ByteBoozer compressed)
            let viewer: [UInt8] = [
                0x00,0x1f,0x78,0xa9,0x3b,0x8d,0x11,0xd0,0xa9,0x18,0x8d,0x16,0xd0,0xa9,0x18,0x8d,
                0x18,0xd0,0xa2,0x00,0xbd,0x40,0x3f,0x9d,0x00,0x04,0xbd,0x40,0x40,0x9d,0x00,0x05,
                0xbd,0x40,0x41,0x9d,0x00,0x06,0xbd,0x40,0x42,0x9d,0x00,0x07,0xbd,0x28,0x43,0x9d,
                0x00,0xd8,0xbd,0x28,0x44,0x9d,0x00,0xd9,0xbd,0x28,0x45,0x9d,0x00,0xda,0xbd,0x28,
                0x46,0x9d,0x00,0xdb,0xe8,0xd0,0xcd,0xad,0x10,0x47,0x8d,0x21,0xd0,0xad,0x11,0x47,
                0x8d,0x20,0xd0,0x4c,0x51,0x1f
            ]

            file.append(contentsOf: viewer)
            // Pad to 256 bytes (minus PRG header of 2 bytes)
            var pad = viewer.count - 2
            while pad < 256 {
                file.append(0 as UInt8)
                pad += 1
            }
            file.append(map, count: 8000)
            file.append(screen, count: 1000)
            file.append(color, count: 1000)
            file.append(background, count: 1)
            if let border = canvasModel.border {
                file.append(border, count: 1)
            } else {
                file.append(0 as UInt8)
            }

            // ByteBoozer crunch with start address 0x1F00
            return try ByteBoozer.crunch(data: file, startAddress: 0x1F00)

        case "gg":
            // Koala compressed
            var src = Data(count: 10001)
            src.replaceSubrange(0..<8000, with: Data(bytes: map, count: 8000))
            src.replaceSubrange(8000..<9000, with: Data(bytes: screen, count: 1000))
            src.replaceSubrange(9000..<10000, with: Data(bytes: color, count: 1000))
            src[10000] = background[0]
            let ggCompressed = try C64Codecs.compressKoala(data: src)
            var ggAddr: UInt16 = 0x6000
            file.append(Data(bytes: &ggAddr, count: 2))
            file.append(ggCompressed)

        case "bin":
            // Multipaint BIN (MC Bitmap): 88000 bytes total
            // Border + background
            if let border = canvasModel.border {
                file.append(border, count: 1)
            } else {
                file.append(0 as UInt8)
            }
            file.append(background, count: 1)

            // Header bytes at offset 2
            let binHeader: [UInt8] = [0x00, 0x0A, 0x0F, 0x28, 0x00, 0x19]
            file.append(contentsOf: binHeader)
            file.append(Data(repeating: 0, count: 4))
            file.append(UInt8(3))

            // Pad to position 0x103 with zeros
            while file.count < 0x103 {
                file.append(0 as UInt8)
            }

            // Meta bytes
            let binMeta: [UInt8] = [
                0xFF, 0xFF, 0xFF, 0x68, 0x37, 0x2B, 0x70, 0xA4,
                0xB2, 0x6F, 0x3D, 0x86, 0x58, 0x8D, 0x43, 0x35,
                0x28, 0x79, 0xB8, 0xC7, 0x6F, 0x6F, 0x4F, 0x25,
                0x43, 0x39, 0x00, 0x9A, 0x67, 0x59, 0x44, 0x44,
                0x44, 0x6C, 0x6C, 0x6C, 0x9A, 0xD2, 0x84, 0x6C,
                0x5E, 0xB5, 0x95, 0x95, 0x95
            ]
            file.append(contentsOf: binMeta)

            // Pad to position 0x400 with zeros
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

            // Pad to position 0x10000 with zeros
            while file.count < 0x10000 {
                file.append(0 as UInt8)
            }

            // Screen low nibbles: 1000 bytes
            for r in 0..<1000 {
                file.append(screen[r] & 0x0f)
            }
            // Screen high nibbles: 1000 bytes
            for r in 0..<1000 {
                file.append(screen[r] >> 4)
            }
            // Color: 1000 bytes
            file.append(color, count: 1000)

            // Pad to 88000 total
            while file.count < 88000 {
                file.append(0 as UInt8)
            }

        case "zom":
            // Zoomatic compressed
            var src = Data(count: 10001)
            src.replaceSubrange(0..<8000, with: Data(bytes: map, count: 8000))
            src.replaceSubrange(8000..<9000, with: Data(bytes: screen, count: 1000))
            src.replaceSubrange(9000..<10000, with: Data(bytes: color, count: 1000))
            src[10000] = background[0] | ((canvasModel.border?.pointee ?? 0) << 4)
            let zomCompressed = try C64Codecs.compressZoomatic(data: src)
            var zomAddr: UInt16 = 0x6000
            file.append(Data(bytes: &zomAddr, count: 2))
            file.append(zomCompressed)

        default:
            return try super.saveToFile(type: type)
        }

        return file
    }

    // MARK: - Load

    override func load(file: inout Data, type: String, version: Int) throws {

        try super.load(file: &file, type: type, version: version)

        switch type {
        case "kla", "koa":
            try loadKoala(file: &file, version: version)

        case "ocp":
            try loadOCP(file: &file)

        case "cen":
            try loadCEN(file: &file)

        case "mg":
            try loadMG(file: &file)

        case "pmg":
            try loadPMG(file: &file)

        case "gg":
            try loadGG(file: &file)

        case "zom":
            try loadZOM(file: &file)

        case "ami":
            try loadAMI(file: &file)

        case "binmc", "bin":
            try loadBINMC(file: &file)

        default:
            break
        }
    }
    
    override var pixelWidth: Int {

        return 2
    }

    // MARK: - SetPixel Implementation

    override func setPixel(_ x: Int, _ y: Int, _ col: UInt8) {
        guard x >= 0,
              x < canvasModel.xsize,
              y >= 0,
              y < canvasModel.ysize,
              canvasModel.map != nil,
              canvasModel.screen != nil,
              canvasModel.color != nil,
              canvasModel.background != nil else {
            return
        }

        let cx = x / 4
        let cy = y / 8
        let ci = cy * (canvasModel.xsize / 4) + cx

        let currentMask = getMask(x, y)
        guard let mask = resolveMask2(ci: ci, col: col, pointMask: currentMask) else {
            return
        }

        setColor(ci: ci, mask: mask, col: col)

        let mi = cy * canvasModel.xsize * 2 + cx * 8 + (y % 8)

        // Bit manipulation to set the 2-bit pixel value
        let shift = 2 * (3 - (x % 4))
        let filterMask: UInt8 = ~(UInt8(3) << shift)
        let shiftedMask: UInt8 = UInt8(mask) << shift
        canvasModel.map![mi] = (canvasModel.map![mi] & filterMask) | shiftedMask
    }

    private func getMask(_ x: Int, _ y: Int) -> Int {
        let cx = x / 4
        let cy = y / 8
        let mi = cy * canvasModel.xsize * 2 + cx * 8 + (y % 8)
        return Int((canvasModel.map![mi] >> (2 * (3 - (x % 4)))) & 3)
    }
    
    /*
     void MCBitmap::GetSaveFormats(narray<autoptr<SaveFormat>,int> &fmt)
     {
         __super::GetSaveFormats(fmt);
         //fmt.add(new SaveFormat(_T("Koala"),_T("koa")));

         if(xsize==160 && ysize == 200)
         {
             fmt.add(new SaveFormat(_T("Koala"),_T("kla;koa"),true));
             fmt.add(new SaveFormat(_T("Koala compressed"),_T("gg"),true));
             fmt.add(new SaveFormat(_T("Zoomatic"), _T("zom"), true));
             fmt.add(new SaveFormat(_T("Advanced Art Studio 2"),_T("ocp"),true));
             fmt.add(new SaveFormat(_T("Cenimate"),_T("cen"),true));
             if(crippled[3])fmt.add(new SaveFormat(_T("Paint Magic"),_T("pmg"),true));
             fmt.add(new SaveFormat(_T("Multigraf"), _T("mg"), true));
             fmt.add(new SaveFormat(_T("C64 Exe"),_T("prg"),false));
             fmt.add(new SaveFormat(_T("Multipaint"), _T("bin"), true));
         }
     }

     void MCBitmap::GetLoadFormats(narray<autoptr<SaveFormat>,int> &fmt)
     {
         fmt.add(new SaveFormat(_T("Koala"),_T("kla;koa;gg"),true,160,200,MC_BITMAP));
         fmt.add(new SaveFormat(_T("Zoomatic"), _T("zom"), true, 160, 200, MC_BITMAP));
         fmt.add(new SaveFormat(_T("Cenimate"),_T("cen"),true,160,200,MC_BITMAP));
         fmt.add(new SaveFormat(_T("Advanced Art Studio"),_T("ocp"),true,160,200,MC_BITMAP));
         fmt.add(new SaveFormat(_T("Paint Magic"),_T("pmg"),true,160,200,MC_BITMAP));
         fmt.add(new SaveFormat(_T("Multigraf"), _T("mg"), true, 160, 200, MC_BITMAP));
         fmt.add(new SaveFormat(_T("Multipaint"), _T("bin;binmc"), true, 160, 200, MC_BITMAP));
     }
     */
    /*
     nstr MCBitmap::IdentifyFile(nmemfile &file)
     {
         nstr ex;

         if (file.len() == 88000)
         {
             BYTE *ptr = file;
             static const BYTE cmp[] = { 0x00,0x0A,0x0F,0x28,0x00,0x19 };
             if (!memcmp(ptr + 2, cmp, 6))
             {
                 ex = "binmc";
                 return ex;
             }
         }

         unsigned short addr;
         file >> addr;

         if(file.len() == 10003 && (addr == 0x6000 || addr == 0x2000))
         {
             ex = _T("kla");
         }
         else if(file.len() == 10051 && addr == 0x5800)
         {
             ex = _T("cen");
         }
         else if(file.len() == 10018 && addr == 0x2000)
         {
             ex = _T("ocp");
         }
         else if(file.len() == 9332 && addr == 0x3f8e)
         {
             ex = _T("pmg");
         }
         else if (file.len() == 11266 && addr == 0x3000)
         {
             ex = _T("mg");
         }
         else if(addr == 0x6000)
         {
             BYTE buffer[10001];
             if(DecompressKoalaStream(((BYTE *)file)+2, int(file.len()-2), buffer, 10001) == 10001)
             {
                 ex = _T("gg");
             }
             else if (DecompressZoomaticStream(((BYTE *)file) + 2, int(file.len() - 2), buffer, 10001) == 10001)
             {
                 ex = _T("zom");
             }
         }
         else if (addr == 0x4000)
         {
             BYTE buffer[20000];
             if (DecompressAmicaStream(((BYTE *)file) + 2, int(file.len() - 2), buffer, 20000)  > 0)
             {
                 ex = _T("ami");
             }
         }

         return ex;
     }

     */
    
}

// MARK: - remapping
extension PCMCBitmap {
    
    /*
    void MCBitmap::RemapCellColour(int cx, int cy, int colour, int indexTo)
    {
        static int maskLUT[4] = { 0,1,2,3 };

        CellInfo info;
        GetCellInfo(cx, cy, 1, 1, &info);


        int targetMask = maskLUT[indexTo];

        //does this cell use the colour we want
        int colourUsed = 0;
        for (int c = 0; c < 4; ++c)
        {
            if (info.col[c] == colour)
            {
                ++colourUsed;
            }
        }
        if (colourUsed == 1)
        {
            for (int c = 0; c < 4; ++c)
            {
                if (info.col[c] == colour)
                {
                    //is it already where we want it to be
                    if (c != indexTo)
                    {
                        //no
                        int srcMask = maskLUT[c];
                        SwapmaskCell2(cx, cy, srcMask, targetMask);
                        //also need to swap the colours
                        int oldColour = info.col[indexTo];
                        int ci = cy * (xsize / 4) + cx;

                        SetColor(ci, targetMask, colour);
                        SetColor(ci, srcMask, oldColour);
                        break;  //found it so exit
                    }
                }
            }
        }
        else if (colourUsed >= 3)
        {
            //they are all the colour
            if (targetMask != 1) RemapCell2(cx, cy, maskLUT[1], targetMask);
            if (targetMask != 2) RemapCell2(cx, cy, maskLUT[2], targetMask);
            if (targetMask != 3) RemapCell2(cx, cy, maskLUT[3], targetMask);
        }
        else if (colourUsed >= 2) //2 are the colour
        {
            //find first colour with it
            int c = 0;
            int firstIndex = 0;
            while (c < 4)
            {
                if (info.col[c] == colour)
                {
                    firstIndex = c;
                    break;
                }
                ++c;
            }
            //find second colour with it
            int secondIndex = 0;
            ++c;
            while (c < 4)
            {
                if (info.col[c] == colour)
                {
                    secondIndex = c;
                    break;
                }
                ++c;
            }
            //if dest = first, map second onto first
            if (firstIndex == indexTo)
            {
                RemapCell2(cx, cy, maskLUT[secondIndex], maskLUT[firstIndex]);
            }
            //else if dest = second, map first onto second
            else if (secondIndex == indexTo)
            {
                RemapCell2(cx, cy, maskLUT[firstIndex], maskLUT[secondIndex]);
            }
            //else map first colour into second, swap with dest
            else
            {
                RemapCell2(cx, cy, maskLUT[firstIndex], maskLUT[secondIndex]);
                SwapmaskCell2(cx, cy, maskLUT[secondIndex], targetMask);

                int oldColour = info.col[indexTo];
                int ci = cy * (xsize / 4) + cx;
                SetColor(ci, targetMask, colour);
                SetColor(ci, maskLUT[secondIndex], oldColour);
            }
        }
    }
     */
}

// MARK: - Decompressors
extension PCMCBitmap {
    
    /*
     int MCBitmap::DecompressAmicaStream(const BYTE *stream, int stream_size, BYTE *buffer, int buffer_size)
     {
         int r = 0, w = 0 ,t;
         BYTE b;
         while (r < stream_size)
         {
             if (r == stream_size)
                 return -1;
             b = stream[r];
             r++;

             if (b == 0xc2)
             {
                 //rle
                 if (r == stream_size)
                     return -1;
                 t = stream[r];
                 r++;

                 if (!t)
                     return w;

                 if (r == stream_size)
                     return -1;
                 b = stream[r];
                 r++;

                 while (t)
                 {
                     if (w == buffer_size)
                         return -1;
                     buffer[w] = b;
                     w++;
                     --t;
                 }
             }
             else
             {
                 //Literal
                 if (w == buffer_size)
                     return -1;
                 buffer[w] = b;
                 w++;
             }
         }

         return -1;
     }


     int MCBitmap::DecompressKoalaStream(const BYTE *stream, int stream_size, BYTE *buffer, int buffer_size)
     {
         //Plenty of sanity checks
         int r=0,w=0;
         BYTE b;
         int l;

         while(r < stream_size)
         {
             if(w>=buffer_size)
                 return -1;
             b=stream[r];
             if(b==0xfe)
             {
                 if(r+3>stream_size)
                     return -1;
                 b=stream[r+1];
                 l=stream[r+2];
                 if(l==0)l=256;

                 for(;l>0;l--)
                 {
                     if(w>=buffer_size)
                         return -1;
                     buffer[w]=b;
                     w++;
                 }
                 r+=3;
             }
             else
             {
                 buffer[w]=b;
                 w++;
                 r++;
             }

         }

         return w;
     }

     int MCBitmap::CompressKoalaStream(const BYTE *stream, int stream_size, BYTE *buffer, int buffer_size)
     {
         int r=0,w=0;
         BYTE b;
         int l;

         while(r < stream_size)
         {
             if(w>=buffer_size)return -1;
             b=stream[r];
             l=1;
             while(r+l < stream_size && l < 256 && b==stream[r+l])l++;

             if(l > 3 || b==0xfe)
             {
                 if(w+3>buffer_size)return -1;
                 buffer[w]=0xfe;
                 buffer[w+1]=b;
                 buffer[w+2]=l&255;
                 w+=3;
                 r+=l;
             }
             else
             {
                 buffer[w]=b;
                 w++;
                 r++;
             }
         }

         return w;
     }

     int MCBitmap::DecompressZoomaticStream(const BYTE *stream, int stream_size, BYTE *buffer, int buffer_size)
     {
         //Plenty of sanity checks as usual
         int r = stream_size, w = buffer_size;

         --r; if (r < 0) return -1;
         BYTE code = stream[r];

         while (r > 0)
         {
             --r;
             BYTE b = stream[r];

             if (b == code)
             {
                 --r; if (r < 0) return -1;
                 int l = stream[r];
                 if (!l) l = 256;
                 --r; if (r < 0) return -1;
                 b = stream[r];
                 while (l)
                 {
                     w--; if (w < 0) return -1;
                     buffer[w] = b;
                     l--;
                 }
             }
             else
             {
                 w--; if (w < 0) return -1;
                 buffer[w] = b;
             }
         }

         return w == 0 ? 10001 : -1;
     }
     */
}

// MARK: - Compressors
extension PCMCBitmap {
    
    /*
     int MCBitmap::CompressZoomaticStream(const BYTE *stream, int stream_size, BYTE *buffer, int buffer_size)
     {
         // Get the least used byte, can be more optimal for this type of RLE but does the job
         int codes[256];
         ZeroMemory(codes, sizeof(codes));
         for (int r = 0; r < stream_size; r++)codes[stream[r]]++;
         int lowest = INT_MAX;
         BYTE code = 0;
         for (int r = 0; r < 256; r++)
         {
             if (codes[r] < lowest)
             {
                 code = BYTE(r);
                 lowest = codes[r];
             }
         }

         // Packing it forward
         int r = 0, w = 0;

         // Get the first byte
         BYTE lb = stream[r];
         r++;
         int count = 1;

         while (r < stream_size)
         {
             BYTE b = stream[r];
             r++;

             if (!count)
             {
                 lb = b;
                 count = 1;
             }
             else if (b == lb)
             {
                 count++;
                 if (count == 256)
                 {
                     if (w + 3 > buffer_size)return -1;
                     w = CompressZoomaticStreamFlush(buffer, w, lb, count, code);
                     count = 0;
                 }
             }
             else
             {
                 if (w + 3 > buffer_size)return -1;
                 w = CompressZoomaticStreamFlush(buffer, w, lb, count, code);

                 lb = b;
                 count = 1;
             }

         }

         // Flush last
         if (count)
         {
             if (w + 3 > buffer_size)return -1;
             w = CompressZoomaticStreamFlush(buffer, w, lb, count, code);
         }
         
         if (w == buffer_size)return -1;
         buffer[w] = code;
         w++;

         return w;
     }

     int MCBitmap::CompressZoomaticStreamFlush(BYTE *buffer, int w, BYTE b, int count, BYTE code)
     {
         if (count <= 3 && b != code)
         {
             // Literal
             while (count)
             {
                 buffer[w] = b;
                 w++;
                 count--;
             }
         }
         else
         {
             // RLE
             buffer[w] = b;
             w++;
             buffer[w] = BYTE(count);
             w++;
             buffer[w] = code;
             w++;
         }

         return w;
     }
     */
}

// MARK: - File loaders
extension PCMCBitmap {
       
    fileprivate func loadKoala(file: inout Data, version:Int) throws {
    
        if (file.count != 10003) {
                        
            throw C64InterfaceError.sizeMismatch("Invalid koala file size")
        }
        
        guard self.canvasModel.map != nil,
              self.canvasModel.screen != nil,
              self.canvasModel.color != nil,
              self.canvasModel.background != nil
        else {
            
            throw C64InterfaceError.backbuffersMissing
        }
        
        var addr:UInt16 = 0 // unsigned short addr
        file >> addr;
        
        file.read(self.canvasModel.map, 8000)
        file.read(self.canvasModel.screen, 1000)
        file.read(self.canvasModel.color, 1000)
        file.read(self.canvasModel.background, 1)
        
        
        //Clean up masks
        self.canvasModel.background![0] &= 0x0f
        for r in 0..<1000 { // for(int r=0;r<1000;r++)
        
            self.canvasModel.color![r] &= 0x0f
        }
        
                
        if self.canvasModel.border != nil {
        
            self.canvasModel.border?.pointee = guessBorderColor()
        }
        
        // Success
    }

    // MARK: - OCP (Advanced Art Studio) Load

    fileprivate func loadOCP(file: inout Data) throws {
        guard file.count == 10018 else {
            throw C64InterfaceError.sizeMismatch("Invalid Advanced Art Studio file size")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        var addr: UInt16 = 0
        file >> addr

        file.read(canvasModel.map, 8000)
        file.read(canvasModel.screen, 1000)

        if canvasModel.border != nil {
            file.read(canvasModel.border, 1)
        } else {
            file = file.advanced(by: 1)
        }
        file.read(canvasModel.background, 1)
        file = file.advanced(by: 14)  // skip padding
        file.read(canvasModel.color, 1000)

        canvasModel.background![0] &= 0x0f
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }
    }

    // MARK: - CEN (Cenimate) Load

    fileprivate func loadCEN(file: inout Data) throws {
        guard file.count == 10051 else {
            throw C64InterfaceError.sizeMismatch("Invalid Cenimate file size")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        var addr: UInt16 = 0
        file >> addr

        file.read(canvasModel.color, 1000)
        file = file.advanced(by: 24)  // skip padding
        file.read(canvasModel.screen, 1000)
        file = file.advanced(by: 24)  // skip padding
        file.read(canvasModel.map, 8000)
        file.read(canvasModel.background, 1)

        canvasModel.background![0] &= 0x0f
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }

    // MARK: - MG (Multigraf) Load

    fileprivate func loadMG(file: inout Data) throws {
        guard file.count == 11266 else {
            throw C64InterfaceError.sizeMismatch("Invalid Multigraf file size")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        var addr: UInt16 = 0
        file >> addr

        file.read(canvasModel.map, 8000)
        file = file.advanced(by: 175)  // skip padding
        file.read(canvasModel.background, 1)
        file = file.advanced(by: 16)   // skip "MULTIGRAF V1.30\0"
        file.read(canvasModel.screen, 1000)
        file = file.advanced(by: 24)   // skip padding
        file.read(canvasModel.color, 1000)
        file = file.advanced(by: 24)   // skip padding

        canvasModel.background![0] &= 0x0f
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }

    // MARK: - PMG (Paint Magic) Load

    fileprivate func loadPMG(file: inout Data) throws {
        guard file.count == 9332 else {
            throw C64InterfaceError.sizeMismatch("Invalid Paint Magic file size")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        var addr: UInt16 = 0
        file >> addr
        // addr should be 0x3f8e

        // Skip display routine: 0x4000 - 0x3f8e = 114 bytes
        file = file.advanced(by: 0x4000 - 0x3f8e)

        file.read(canvasModel.map, 8000)
        file.read(canvasModel.background, 1)

        // Throw 2 bytes
        file = file.advanced(by: 2)

        // Read single color byte and fill all color RAM with it
        let c = file[file.startIndex]
        file = file.advanced(by: 1)
        if let color = canvasModel.color {
            for i in 0..<1000 {
                color[i] = c
            }
        }

        // Read border
        if canvasModel.border != nil {
            file.read(canvasModel.border, 1)
        } else {
            file = file.advanced(by: 1)
        }

        // Skip to screen: 0x6000 - 0x5f45 = 187 bytes
        file = file.advanced(by: 0x6000 - 0x5f45)

        file.read(canvasModel.screen, 1000)

        // Clean up masks
        canvasModel.background![0] &= 0x0f
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }

        // Mark color RAM as crippled (single color for all cells)
        if canvasModel.crippled != nil {
            canvasModel.crippled![3] = 1
        }
    }

    // MARK: - GG (Koala Compressed) Load

    fileprivate func loadGG(file: inout Data) throws {
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        // Skip 2-byte PRG header, decompress to 10001 bytes
        let stream = file.advanced(by: 2)
        var buffer = try C64Codecs.decompressKoala(stream: stream, outputSize: 10001)

        buffer.read(canvasModel.map, 8000)
        buffer.read(canvasModel.screen, 1000)
        buffer.read(canvasModel.color, 1000)

        canvasModel.background![0] = buffer[buffer.startIndex] & 0x0f

        // Clean up masks
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }

    // MARK: - ZOM (Zoomatic Compressed) Load

    fileprivate func loadZOM(file: inout Data) throws {
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        // Skip 2-byte PRG header, decompress to 10001 bytes
        let stream = file.advanced(by: 2)
        var buffer = try C64Codecs.decompressZoomatic(stream: stream, outputSize: 10001)

        buffer.read(canvasModel.map, 8000)
        buffer.read(canvasModel.screen, 1000)
        buffer.read(canvasModel.color, 1000)

        let bgBorder = buffer[buffer.startIndex]
        canvasModel.background![0] = bgBorder & 0x0f

        if canvasModel.border != nil {
            canvasModel.border!.pointee = bgBorder >> 4
        }

        // Clean up masks
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }
    }

    // MARK: - BINMC (Multipaint MC) Load

    fileprivate func loadBINMC(file: inout Data) throws {
        guard file.count == 88000 else {
            throw C64InterfaceError.sizeMismatch("Invalid Multipaint MC file size (expected 88000)")
        }
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        // Read border (1 byte), background (1 byte)
        if canvasModel.border != nil {
            file.read(canvasModel.border, 1)
        } else {
            file = file.advanced(by: 1)
        }
        file.read(canvasModel.background, 1)
        canvasModel.background![0] &= 0x0f

        // Seek to position 0x0400 (skip header)
        file = Data(file.suffix(from: file.startIndex.advanced(by: 0x0400 - 2)))

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

        // Read screen low nibbles: 1000 bytes
        for r in 0..<1000 {
            canvasModel.screen![r] = file[file.startIndex]
            file = file.advanced(by: 1)
        }
        // Read screen high nibbles: 1000 bytes
        for r in 0..<1000 {
            let b = file[file.startIndex]
            file = file.advanced(by: 1)
            canvasModel.screen![r] |= b << 4
        }
        // Read color: 1000 bytes
        file.read(canvasModel.color, 1000)

        // Clean up masks
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }
    }

    // MARK: - AMI (Amica Compressed) Load

    fileprivate func loadAMI(file: inout Data) throws {
        guard canvasModel.map != nil, canvasModel.screen != nil,
              canvasModel.color != nil, canvasModel.background != nil else {
            throw C64InterfaceError.backbuffersMissing
        }

        // Skip 2-byte PRG header, decompress to 20000 bytes
        let stream = file.advanced(by: 2)
        var buffer = try C64Codecs.decompressAmica(stream: stream, outputSize: 20000)

        buffer.read(canvasModel.map, 8000)
        buffer.read(canvasModel.screen, 1000)
        buffer.read(canvasModel.color, 1000)

        canvasModel.background![0] = buffer[buffer.startIndex] & 0x0f

        // Clean up masks
        for r in 0..<1000 { canvasModel.color![r] &= 0x0f }

        if canvasModel.border != nil {
            canvasModel.border!.pointee = guessBorderColor()
        }
    }
}
