//
//  C64Interface.swift
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
//
// Using Pointers in Unsafe Swift:
// https://www.raywenderlich.com/7181017-unsafe-swift-using-pointers-and-interacting-with-c


import Foundation
import Cocoa
//import PixcenFoundation

let CURRENT_GPX_FILE_VERSION = 4

enum C64InterfaceError: Error {
    case failed(Int32, String)
    case sizeMismatch(String)
    case notEnoughBackbuffers
    case backbufferAllocationError
    case backbuffersMissing
}

/**
 This is the view model for the pixel canvas. We store the lowlevel pixel data here
 */
struct PCPixelModel {
    
    internal var mode:PCC64Interface.tmode = .BITMAP
    internal var overflow:PCC64Interface.toverflow = .REPLACE
        
    fileprivate var par:Int = 0         // 0=PC, 1=PAL, 2=NTSC
    fileprivate var meta:[String:String] = [:]  // std::map<nstrc,nstrw> meta;
     
    internal var xsize:Int = 0
    internal var ysize:Int = 0          // Size in pixels
    internal var xcell:Int = 0
    internal var ycell:Int = 0          // Size of cell in pixels
    internal var sizecell:Int = 0
    internal var offsetcell:Int = 0     // Byte size of cell, byte size of cell offset
    
    internal var rmapsize:Int = 0
    internal var rcolorsize:Int = 0
    internal var rscreensize:Int = 0
    fileprivate var rbackbuffers:Int = 0
    internal var buffersize:Int = 0
     
    fileprivate var rbackbufnum:Int = 0
     
    // Backbuffers
    fileprivate var buffer:UnsafeMutablePointer<UInt8>?
    fileprivate var tbuffer:UnsafeMutablePointer<UInt8>?
    
    internal var crippled:UnsafeMutablePointer<UInt8>?
    internal var lock:UnsafeMutablePointer<UInt8>?
     
    /// Border color number
    internal var border:UnsafeMutablePointer<UInt8>?         // BYTE *border;
    internal var background:UnsafeMutablePointer<UInt8>?        // BYTE *background;
    
    internal var ext:UnsafeMutablePointer<UInt8>?           //3

    internal var ext0:UnsafeMutablePointer<UInt8>?
    internal var ext1:UnsafeMutablePointer<UInt8>?
    internal var ext2:UnsafeMutablePointer<UInt8>?
    
    internal var map:UnsafeMutablePointer<UInt8>?
    internal var color:UnsafeMutablePointer<UInt8>?
    internal var screen:UnsafeMutablePointer<UInt8>?
}

struct ImportHelper {
    
    var p:UnsafeMutablePointer<UInt8>?
    var xsize:Int = 0
    var ysize:Int = 0
    var xcs:Int = 0
    var ycs:Int = 0
    
    func highIndex(_ list:Array<Int>, count:Int) -> Int {
        
        guard let max = list.max() else { return -1 }
        return list.firstIndex(of: max) ?? -1
        
        /*
        var high:Int = 0
        var best:Int = -1
        for r in 0..<count { // for(int r=0;r<count;r++)
        
            if(list[r] > high)
            {
                high = list[r];
                best = r;
            }
        }
        
        return best;
         */
    }
    
    func pixel(_ x:Int, _ y:Int) -> UInt8 {
        
        guard xsize > 0 else {
            
            return 0
        }
        
        if p != nil {
        
            return p![y*xsize + x]
        }
        return 0
    }
    
    func setPixel(_ x:Int, _ y:Int, _ c:UInt8) {
        
        guard xsize > 0 else {
            
            return
        }
        if p != nil {
        
            p![y*xsize + x] = c
        }
    }
    
    /*
     {
     public:
         ImportHelper(C64Interface *p, CImage &img, bool wide);
         ~ImportHelper();

         int CountColors(int cx, int cy, int w, int h, int *colcount);
         int CountTopColors(int cx, int cy, int w, int h, BYTE *col);

         int CountTopColorsPerCell(BYTE *col, int ceil=4);
         void ReduceColors(int maxcolor, BYTE *force, int forcecount);

         static int HighIndex(int *list, int count)
         {
             return highindex(list, count);
         }

     private:
         CImageFast &img;

         COLORREF GetImagePixel(int x, int y);

         BYTE GetPixel(int x, int y) { return p[y*xsize + x]; }
         void SetPixel(int x, int y, BYTE c) { p[y*xsize + x] = c; }

         int xsize, ysize, xcs, ycs;

         C64Interface *parent;

         bool wide;

         int palette;
         BYTE *p;

         bool find(BYTE col, BYTE *p, int count)
         {
             for(int r=0;r<count;r++)
             {
                 if(col == p[r])
                     return true;
             }
             return false;
         }

         static int highindex(int *list, int count)
         {
             int high = 0;
             int best = -1;
             for(int r=0;r<count;r++)
             {
                 if(list[r] > high)
                 {
                     high = list[r];
                     best = r;
                 }
             }

             return best;
         }

     }
     */
}

/**
 C64Interface is the base class of the application. All formats are derived from this core
 */
class PCC64Interface/*: C64InterfaceLowlevel */{
    
    // MARK: Public vars
    
    // MARK: Private vars
    internal var canvasModel:PCPixelModel = PCPixelModel()
    internal var importHelper:ImportHelper = ImportHelper()
    fileprivate var savelock = Array<UInt8>(repeating: 0, count: 6)
    fileprivate static var parvalue = [1.0,0.9365,0.75] //Array<Double>(repeating: 0.0, count: 3)
    
    fileprivate var file_name:String = ""
    internal var dirty:Bool = false {

        willSet {

            #if os(macOS)
            if let window = NSApplication.shared.mainWindow {

                if let windowController = window.windowController {

                    windowController.setDocumentEdited(newValue)
                }
            }
            if let delegate = NSApplication.shared.delegate as? AppDelegate {
                delegate.markEdited = newValue
            }
            #endif
        }
    }
    
    // Delta-compressed undo/redo history (matching original C++ format)
    fileprivate var history_pos:Int = 0
    fileprivate var history_undo:[UnsafeMutablePointer<UInt8>] = [] // narray<BYTE *,int32_t> history_undo;
    fileprivate var history_redo:[UnsafeMutablePointer<UInt8>] = [] // narray<BYTE *,int32_t> history_redo;
    fileprivate var history_previous:PCC64Interface?
    fileprivate var history_next:PCC64Interface?
    
    struct InfoUse {
        
        enum TUse {
            case INFO_NO
            case INFO_VALUE
            case INFO_INDEX
            case INFO_INDEX_LOW
            case INFO_INDEX_HIGH
        }
        
        var use:TUse = .INFO_NO
        var pp:UnsafeMutablePointer<UInt8>?    // BYTE **pp;
    }
    
    internal var infouse = Array<InfoUse>(repeating: InfoUse(), count: 6)
    
    // Mark: Types
    public enum tmode: Int {
        case BITMAP = 0
        case MC_BITMAP = 1
        case SPRITE = 2
        case MC_SPRITE = 3
        case CHAR = 4
        case MC_CHAR = 5
        case UNUSED1 = 6
        case UNUSED2 = 7
        case UNRESTRICTED = 8
        case W_UNRESTRICTED = 9
    }

    enum toverflow: Int {
        case REPLACE = 0
        case NOTHING = 1
        case CLOSEST = 2
    }
    
    init() throws {
        
        //super.init()
        
        canvasModel.buffer = nil
        canvasModel.tbuffer = nil

        canvasModel.overflow = .REPLACE

        canvasModel.offsetcell = 8
        canvasModel.sizecell = 8
        canvasModel.rbackbufnum = 0
        canvasModel.par = 0

        infouse[5].use = .INFO_VALUE
        infouse[5].pp = canvasModel.border

        setupInfoUse()

        setMetaInt("pmap",0x4000)
        setMetaInt("pscr",0x6000)
        setMetaInt("pcol",0x6400)

        history_previous = nil
        history_next = nil
    }

    deinit {

        resetHistory()
        destroy()
        freeExpandedColorBuffer()

        deleteHistoryPrevious()
        deleteHistoryNext()
    }
    
    /**
     Must overload.
     */
    func pixel(_ x:Int, _ y:Int) -> UInt8 {
        
        /*
         Example:
         COLORREF GetPixel(int x, int y)
         {
             unsigned char *p = (unsigned char *)GetPixelAddress(x, y);
             return p[0] << 16 | p[1] << 8 | p[2];
         }

         void SetPixel(int x, int y, COLORREF color)
         {
             unsigned char *p = (unsigned char *)GetPixelAddress(x, y);
             p[0] = (color >> 16) & 255;
             p[1] = (color >> 8) & 255;
             p[2] = color & 255;
         }
         */
        return 0
    }
    
    /**
     Must overload
     */
    func pixelColourMap(_ x:Int, _ y:Int) -> UInt8 {
        
        return 0
    }
    
    /**
     Must overload
     */
    func setPixel(_ x:Int, _ y:Int, _ color:UInt8) {

    }

    // MARK: - Metal Rendering Buffer

    private var expandedColorBuffer: UnsafeMutablePointer<UInt8>?
    private var expandedBufferSize: Int = 0

    /// Generate an expanded color buffer for Metal rendering
    /// Each byte contains a resolved color index (0-15) instead of packed mask values
    func getExpandedColorBuffer() -> UnsafeMutablePointer<UInt8>? {
        let width = canvasModel.xsize
        let height = canvasModel.ysize
        let requiredSize = width * height

        guard requiredSize > 0 else { return nil }

        // Reallocate buffer if size changed
        if expandedColorBuffer == nil || expandedBufferSize != requiredSize {
            if let oldBuffer = expandedColorBuffer {
                oldBuffer.deallocate()
            }
            expandedColorBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: requiredSize)
            expandedBufferSize = requiredSize
        }

        guard let buffer = expandedColorBuffer else { return nil }

        // Fill buffer with resolved color indices
        for y in 0..<height {
            for x in 0..<width {
                buffer[y * width + x] = pixel(x, y)
            }
        }

        return buffer
    }

    /// Deallocate expanded buffer when no longer needed
    func freeExpandedColorBuffer() {
        if let buffer = expandedColorBuffer {
            buffer.deallocate()
            expandedColorBuffer = nil
            expandedBufferSize = 0
        }
    }

    // MARK: - InfoUse Setup

    /// Subclasses override to rebind infouse[].pp after setBackBuffer changes pointers.
    func setupInfoUse() {
        infouse[5].use = .INFO_VALUE
        infouse[5].pp = canvasModel.border
    }

    // MARK: - Color Resolution Helpers

    func getColor(ci: Int, mask: Int) -> UInt8 {
        guard mask >= 0, mask < 6 else { return 0 }
        guard let pp = infouse[mask].pp else { return 0 }

        switch infouse[mask].use {
        case .INFO_NO:
            return 0
        case .INFO_VALUE:
            return pp.pointee
        case .INFO_INDEX:
            return pp[ci]
        case .INFO_INDEX_LOW:
            return pp[ci] & 0x0f
        case .INFO_INDEX_HIGH:
            return pp[ci] >> 4
        }
    }

    func setColor(ci: Int, mask: Int, col: UInt8) {
        guard mask >= 0, mask < 6 else { return }
        guard let pp = infouse[mask].pp else { return }

        switch infouse[mask].use {
        case .INFO_NO:
            break
        case .INFO_VALUE:
            pp.pointee = col
        case .INFO_INDEX:
            pp[ci] = col
        case .INFO_INDEX_LOW:
            pp[ci] = (pp[ci] & 0xf0) | (col & 0x0f)
        case .INFO_INDEX_HIGH:
            pp[ci] = (pp[ci] & 0x0f) | ((col & 0x0f) << 4)
        }
    }

    func isMaskGlobal(_ mask: Int) -> Bool {
        guard mask >= 0, mask < 6 else { return false }
        return infouse[mask].use == .INFO_VALUE
    }

    func isMaskLocal(_ mask: Int) -> Bool {
        guard mask >= 0, mask < 6 else { return false }
        let use = infouse[mask].use
        return use == .INFO_INDEX || use == .INFO_INDEX_LOW || use == .INFO_INDEX_HIGH
    }

    func getMapIndexFromCell(_ cx: Int, _ cy: Int) -> Int {
        return (getCellCountX() * cy + cx) * canvasModel.offsetcell
    }

    func countCell2(_ cx: Int, _ cy: Int, _ numOut: inout [Int]) {
        guard let map = canvasModel.map else { return }
        let mi = getMapIndexFromCell(cx, cy)
        for t in 0..<canvasModel.sizecell {
            let d = map[mi + t]
            numOut[Int(d & 3)] += 1
            numOut[Int((d >> 2) & 3)] += 1
            numOut[Int((d >> 4) & 3)] += 1
            numOut[Int(d >> 6)] += 1
        }
    }

    func countCell2(_ cx: Int, _ cy: Int, _ w: Int, _ h: Int, _ numOut: inout [Int]) {
        for y in 0..<h {
            for x in 0..<w {
                countCell2(cx + x, cy + y, &numOut)
            }
        }
    }

    func remapByte2(_ input: UInt8, _ maskFrom: Int, _ maskTo: Int) -> UInt8 {
        var b = input
        let from = UInt8(maskFrom)
        let to = UInt8(maskTo)
        if (b & 3) == from       { b = (b & ~3) | to }
        if ((b >> 2) & 3) == from { b = (b & ~12) | (to << 2) }
        if ((b >> 4) & 3) == from { b = (b & ~48) | (to << 4) }
        if ((b >> 6) & 3) == from { b = (b & ~192) | (to << 6) }
        return b
    }

    func remapCell2(_ cx: Int, _ cy: Int, _ maskFrom: Int, _ maskTo: Int) {
        guard canvasModel.map != nil else { return }
        let mi = getMapIndexFromCell(cx, cy)
        for t in 0..<canvasModel.sizecell {
            canvasModel.map![mi + t] = remapByte2(canvasModel.map![mi + t], maskFrom, maskTo)
        }
    }

    func resolveMask2(ci: Int, col: UInt8, pointMask: Int) -> Int? {
        let ccx = getCellCountX()
        guard ccx > 0 else { return nil }
        let cx = ci % ccx
        let cy = ci / ccx

        var c = [UInt8](repeating: 0, count: 4)
        var uglobal = false

        // Collect colors available
        for r in 0..<4 {
            if isMaskGlobal(r) && (canvasModel.lock == nil || canvasModel.lock![r] == 0) {
                uglobal = true
            }
            c[r] = getColor(ci: ci, mask: r)
        }

        // Direct color match
        for r in 0..<4 {
            if c[r] == col {
                return r
            }
        }

        // See if any indexed color is unused for the cell
        var num = [Int](repeating: 0, count: 4)
        countCell2(cx, cy, &num)

        for r in (0..<4).reversed() {
            if isMaskLocal(r) {
                if num[r] == 0 && (canvasModel.lock == nil || canvasModel.lock![r] == 0) {
                    return r
                }
            }
        }

        // Expensive: see if any global color is unused across all cells
        if uglobal {
            num = [Int](repeating: 0, count: 4)
            countCell2(0, 0, getCellCountX(), getCellCountY(), &num)

            for r in (0..<4).reversed() {
                if isMaskGlobal(r) {
                    if num[r] == 0 && (canvasModel.lock == nil || canvasModel.lock![r] == 0) {
                        return r
                    }
                }
            }
        }

        // See if any color can be remapped (same colors on different masks)
        for t in 0..<4 {
            for r in (0..<4).reversed() {
                if t == r { continue }
                if isMaskLocal(r) && c[t] == c[r] && (canvasModel.lock == nil || canvasModel.lock![r] == 0) {
                    remapCell2(cx, cy, r, t)
                    return r
                }
            }
        }

        // Replace mode
        if canvasModel.overflow == .REPLACE && (canvasModel.lock == nil || canvasModel.lock![pointMask] == 0) {
            return pointMask
        }

        // Closest color mode
        if canvasModel.overflow == .CLOSEST {
            return pointMask
        }

        return nil
    }

    func getCellCountX() -> Int {
        guard canvasModel.xcell > 0 else { return 0 }
        return canvasModel.xsize / canvasModel.xcell
    }

    func getCellCountY() -> Int {
        guard canvasModel.ycell > 0 else { return 0 }
        return canvasModel.ysize / canvasModel.ycell
    }

    ///Should overload
    func cellInfo(cx:Int, cy:Int, w:Int, h:Int, info:inout CellInfo) {

    }
    
    ///Should overload
    func setCellInfo(cx:Int, cy:Int, w:Int, h:Int, info:inout CellInfo) {
        
    }
    
    ///Should overload
    var pixelWidth:Int {
        
        get {
            
            return 1
        }
    }
    
    /*
     Contains an array of all available file formats.
     */
    var saveFormats:[SaveFormat] {
        
        var formats:[SaveFormat] = []
        
        formats.append(SaveFormat(a: "Pixcen", b: "gpx", good: true))
        formats.append(SaveFormat(a: "BMP", b: "bmp", good: false))
        formats.append(SaveFormat(a: "PNG", b: "png", good: false))
        formats.append(SaveFormat(a: "JPG", b: "jpg", good: false))
        formats.append(SaveFormat(a: "GIF", b: "gif", good: false))
        if canvasModel.rscreensize != 0 {
            
            formats.append(SaveFormat(a: "Screen RAM", b: "scr", good: false))
            formats.append(SaveFormat(a: "PRG Screen RAM", b: "pscr", good: false))
        }
        
        if canvasModel.rcolorsize != 0 {
            
            formats.append(SaveFormat(a: "Color RAM", b: "col",good: false))
            formats.append(SaveFormat(a: "PRG Color RAM", b: "pcol",good: false))
        }
        
        formats.append(SaveFormat(a: "Bitmap RAM", b: "map",good: false))
        formats.append(SaveFormat(a: "PRG Bitmap RAM", b: "pmap",good: false))
        
        return formats
    }
    
    var canOptimize:Bool {
        
        get {
            
            return false
        }
    }
    
    /// Windows version: GetCharCount()
    var charCount:Int {
        
        get {
            
            return 0
        }
    }
    
    // MARK: - Allocators
    
    func allocate(mode:tmode, w:Int, h:Int, buffers:Int) {
    
        /*
        C64Interface *i;

        switch(mode)
        {
        case MC_BITMAP:
            i = new class MCBitmap(w,h,buffers);
            break;
        case BITMAP:
            i = new class Bitmap(w,h,buffers);
            break;
        case MC_CHAR:
            i = new class MCFont(w,h,buffers);
            break;
        case CHAR:
            i = new class SFont(w,h,buffers);
            break;
        case SPRITE:
            i = new class Sprite(w,h,buffers);
            break;
        case MC_SPRITE:
            i = new class MCSprite(w,h,buffers);
            break;
        case UNRESTRICTED:
            i = new class Unrestricted(w, h, false, buffers);
            break;
        case W_UNRESTRICTED:
            i = new class Unrestricted(w, h, true, buffers);
            break;
        default:
            throw _T("Wooh, unknown format.");
        };

        return i;
        */
    }
    
    func create(mapsize:Int, colorsize:Int, screensize:Int, backbuffers:Int) throws {
        
        guard backbuffers>0 else {
            
            throw C64InterfaceError.notEnoughBackbuffers
        }

        canvasModel.rmapsize = mapsize
        canvasModel.rcolorsize = colorsize
        canvasModel.rscreensize = screensize
        canvasModel.rbackbuffers = backbuffers

        canvasModel.buffersize = 64 + (64 + mapsize + screensize + colorsize) * backbuffers

        // Original: (BYTE *)_aligned_malloc(buffersize, 16);
        canvasModel.buffer  = UnsafeMutablePointer<UInt8>.allocate(capacity: canvasModel.buffersize)
        canvasModel.tbuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: canvasModel.buffersize)
        
        guard canvasModel.buffer != nil, canvasModel.tbuffer != nil else {
            
            throw C64InterfaceError.backbufferAllocationError
        }
        
        // ZeroMemory
        canvasModel.buffer!.initialize(repeating: 0, count: canvasModel.buffersize)
        canvasModel.tbuffer!.initialize(repeating: 0, count: canvasModel.buffersize)
        
        // for(int r=backbuffers-1;r>=0;r--)
        for r in (0..<backbuffers).reversed() {
                
            do {
                try setBackBuffer(r)
                if canvasModel.border != nil {
                
                    canvasModel.border!.pointee = 14
                }
            } catch {
                
                throw error
            }
        }

        resetHistory()

        dirty = false
    }
    
    func duplicateGlobalsToBackBuffers() {
                       
        // TODO: mspixcen
        /*
        BYTE *src = map-64;
        int restore=GetBackBuffer();

        for(int r=0;r<rbackbuffers;r++)
        {
            SetBackBuffer(r);
            memcpy(map-64, src, 64);
        }

        SetBackBuffer(restore);
         */
    }
     
    func destroy() {
        
        if canvasModel.buffer != nil {
            
            canvasModel.buffer!.deallocate()
            canvasModel.buffer = nil
        }
        
        if canvasModel.tbuffer != nil {
            
            canvasModel.tbuffer!.deallocate()
            canvasModel.tbuffer = nil
        }
    }
    
    // MARK: - File Formats
    class var loadFormats:[SaveFormat] {

        var formats:[SaveFormat] = []

        formats.append(SaveFormat(a: "Pixcen", b: "gpx", good: true))

        // MC Bitmap formats
        formats.append(SaveFormat(a: "Koala", b: "kla;koa;gg", good: true, w: 160, h: 200))
        formats.append(SaveFormat(a: "Zoomatic", b: "zom", good: true, w: 160, h: 200))
        formats.append(SaveFormat(a: "Cenimate", b: "cen", good: true, w: 160, h: 200))
        formats.append(SaveFormat(a: "Advanced Art Studio", b: "ocp", good: true, w: 160, h: 200))
        formats.append(SaveFormat(a: "Paint Magic", b: "pmg", good: true, w: 160, h: 200))
        formats.append(SaveFormat(a: "Multigraf", b: "mg", good: true, w: 160, h: 200))
        formats.append(SaveFormat(a: "Multipaint", b: "bin;binmc", good: true, w: 160, h: 200))

        // Bitmap formats
        formats.append(SaveFormat(a: "Art Studio", b: "art", good: true, w: 320, h: 200))
        formats.append(SaveFormat(a: "Doodle", b: "dd;ddl;jj", good: true, w: 320, h: 200))
        formats.append(SaveFormat(a: "Multipaint", b: "binhi", good: true, w: 320, h: 200))

        // Image formats
        formats.append(SaveFormat(a: "BMP", b: "bmp", good: false))
        formats.append(SaveFormat(a: "PNG", b: "png", good: false))
        formats.append(SaveFormat(a: "JPG", b: "jpg", good: false))
        formats.append(SaveFormat(a: "GIF", b: "gif", good: false))

        return formats
    }
    
    /**
     Returns the name of the file format.
     */
    func identifyFile(_ data:Data) -> String {
        
        return ""
    }
    
    // MARK: import, load, save
    /*
     In the original pixcen this function was name "import".
     But "import" is a reserved keyword in swift, so it's renamed here.
     **/
    func importImage(img: inout PCImage){}

    /// Save the bitmap to GPX format. Returns compressed file data ready to write to disk.
    func saveGPX() throws -> Data {
        var file = Data()

        // Version + mode header
        file.appendInt32(Int32(CURRENT_GPX_FILE_VERSION))
        file.appendInt32(Int32(canvasModel.mode.rawValue))

        // Build metadata
        var meta: [String: String] = [:]
        meta["xsize"] = String(canvasModel.xsize)
        meta["ysize"] = String(canvasModel.ysize)
        meta["mapsize"] = String(canvasModel.rmapsize)
        meta["colorsize"] = String(canvasModel.rcolorsize)
        meta["screensize"] = String(canvasModel.rscreensize)
        meta["backbuffers"] = String(canvasModel.rbackbuffers)
        meta["backbufsel"] = String(canvasModel.rbackbufnum)
        meta["par"] = String(canvasModel.par)
        meta["overflow"] = String(canvasModel.overflow.rawValue)

        // Write metacount
        file.appendInt32(Int32(meta.count))

        // Write each key-value pair as nstrc (null-terminated ASCII) + nstrw (null-terminated UTF-16LE)
        for (key, value) in meta {
            // nstrc: ASCII bytes + 0x00
            if let keyData = key.data(using: .ascii) {
                file.append(keyData)
            }
            file.append(0 as UInt8)  // null terminator

            // nstrw: UTF-16LE code units + 0x0000
            for scalar in value.unicodeScalars {
                let code = UInt16(scalar.value)
                file.append(UInt8(code & 0xFF))
                file.append(UInt8(code >> 8))
            }
            file.append(contentsOf: [0, 0] as [UInt8])  // null terminator (2 bytes)
        }

        // Write raw buffer
        if let buffer = canvasModel.buffer {
            file.append(buffer, count: canvasModel.buffersize)
        }

        // Write history
        file.appendInt32(Int32(history_pos))

        // Undo entries
        file.appendInt32(Int32(history_undo.count))
        for entry in history_undo {
            let size = entry.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
            file.append(entry, count: Int(size))
        }

        // Redo entries
        file.appendInt32(Int32(history_redo.count))
        for entry in history_redo {
            let size = entry.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
            file.append(entry, count: Int(size))
        }

        // Compress entire file
        let compressed = try ZlibCompression.compress(file)
        return compressed
    }

    /// Save to a file format. Override in subclass for format-specific saving.
    func saveToFile(type: String) throws -> Data {
        if type == "gpx" { return try saveGPX() }

        var file = Data()

        switch type {
        // RAM exports - raw buffer data
        case "scr":
            if let screen = canvasModel.screen, canvasModel.rscreensize > 0 {
                file.append(screen, count: canvasModel.rscreensize)
            }
        case "pscr":
            file.appendUInt32(0)  // placeholder address (2 bytes used)
            // TODO: read address from metadata
            if let screen = canvasModel.screen, canvasModel.rscreensize > 0 {
                file.append(screen, count: canvasModel.rscreensize)
            }
        case "col":
            if let color = canvasModel.color, canvasModel.rcolorsize > 0 {
                file.append(color, count: canvasModel.rcolorsize)
            }
        case "pcol":
            file.appendUInt32(0)
            if let color = canvasModel.color, canvasModel.rcolorsize > 0 {
                file.append(color, count: canvasModel.rcolorsize)
            }
        case "map":
            if let map = canvasModel.map, canvasModel.rmapsize > 0 {
                file.append(map, count: canvasModel.rmapsize)
            }
        case "pmap":
            file.appendUInt32(0)
            if let map = canvasModel.map, canvasModel.rmapsize > 0 {
                file.append(map, count: canvasModel.rmapsize)
            }

        // Image exports using Cocoa
        case "png", "bmp", "jpg", "gif":
            return try saveAsImage(type: type)

        default:
            throw C64InterfaceError.failed(0, "Save format '\(type)' not implemented")
        }

        return file
    }

    /// Render the bitmap to an image and export as PNG/BMP/JPG/GIF
    private func saveAsImage(type: String) throws -> Data {
        let w = canvasModel.xsize * pixelWidth
        let h = canvasModel.ysize
        guard w > 0, h > 0 else {
            throw C64InterfaceError.failed(0, "Invalid image dimensions")
        }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: w * 4, bitsPerPixel: 32
        ) else {
            throw C64InterfaceError.failed(0, "Could not create bitmap rep")
        }

        let pixels = rep.bitmapData!
        let palette = C64Col.shared

        for y in 0..<canvasModel.ysize {
            for x in 0..<canvasModel.xsize {
                let colorIdx = Int(pixel(x, y) & 0x0f)
                let c = palette.color[colorIdx]
                let r = UInt8(c.redComponent * 255)
                let g = UInt8(c.greenComponent * 255)
                let b = UInt8(c.blueComponent * 255)

                for px in 0..<pixelWidth {
                    let offset = (y * w + x * pixelWidth + px) * 4
                    pixels[offset] = r; pixels[offset+1] = g
                    pixels[offset+2] = b; pixels[offset+3] = 255
                }
            }
        }

        let fileType: NSBitmapImageRep.FileType
        switch type {
        case "png": fileType = .png
        case "bmp": fileType = .bmp
        case "jpg": fileType = .jpeg
        case "gif": fileType = .gif
        default: fileType = .png
        }

        guard let data = rep.representation(using: fileType, properties: [:]) else {
            throw C64InterfaceError.failed(0, "Image encoding failed")
        }
        return data
    }
    
    /**
        Decodes the image, wich is buffered in "file", into this class.
        This function **is** the loader.
     */
    //void C64Interface::Load(nmemfile &file, LPCTSTR type, int version)
    func load(file:inout Data, type:String, version:Int) throws {
                        
        if type == "gpx" {
            
            // ## gpx files
            var tmp:UInt32 = 0 // int32_t tmp;
            
            if version >= 4 {

                var metacount:UInt32 = 0

                // >> operator was defined in DataExtensions.swift
                file >> metacount

                // Read metadata key-value pairs (nstrc key, nstrw value)
                for _ in 0..<metacount {
                    let key = file.readNullTerminatedASCII()
                    let value = file.readNullTerminatedUTF16LE()
                    canvasModel.meta[key] = value
                }

                // Extract dimensions from metadata
                canvasModel.par = metaInt("par")
                canvasModel.xsize = metaInt("xsize")
                canvasModel.ysize = metaInt("ysize")
                canvasModel.rmapsize = metaInt("mapsize")
                canvasModel.rcolorsize = metaInt("colorsize")
                canvasModel.rscreensize = metaInt("screensize")
                canvasModel.rbackbuffers = metaInt("backbuffers")
                canvasModel.rbackbufnum = metaInt("backbufsel")

                let overflowInt = metaInt("overflow")
                switch overflowInt {
                case 0: canvasModel.overflow = .REPLACE
                case 1: canvasModel.overflow = .NOTHING
                case 2: canvasModel.overflow = .CLOSEST
                default: canvasModel.overflow = .NOTHING
                }

                destroy()
                try create(mapsize: canvasModel.rmapsize,
                           colorsize: canvasModel.rcolorsize,
                           screensize: canvasModel.rscreensize,
                           backbuffers: canvasModel.rbackbuffers)

                // Read raw pixel buffer
                file.read(canvasModel.buffer, canvasModel.buffersize)

                // Read history position
                var histPos:Int32 = 0
                file >> histPos
                history_pos = Int(histPos)

                // Read undo entries
                var undoCount:UInt32 = 0
                file >> undoCount
                history_undo.removeAll()
                for _ in 0..<undoCount {
                    file >> tmp  // size including the 4-byte header
                    let size = Int(tmp)
                    let p = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                    // Store size as first 4 bytes (int32_t)
                    p.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee = Int32(size) }
                    // Read remaining bytes after the 4-byte header
                    file.read(p.advanced(by: 4), size - 4)
                    history_undo.append(p)
                }

                // Read redo entries
                var redoCount:UInt32 = 0
                file >> redoCount
                history_redo.removeAll()
                for _ in 0..<redoCount {
                    file >> tmp
                    let size = Int(tmp)
                    let p = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                    p.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee = Int32(size) }
                    file.read(p.advanced(by: 4), size - 4)
                    history_redo.append(p)
                }
            }
            else
            {
                // ## Legacy GPX load
                var tmplock:Int32 = 0 // int32_t tmplock;

                // TODO: PORTING WAS DONE UNIL HERE,
                // TODO: NEXT TIME GO ON WITH THIS COMMENTED BLOCK
                /*
                file >> tmp; overflow = toverflow(tmp);

                if(version >= 2)
                {
                    file >> tmplock;
                }
                else
                {
                    tmplock=0;
                }

                file >> tmp; xsize = tmp;
                file >> tmp; ysize = tmp;
                file >> tmp; xcell = tmp;
                file >> tmp; ycell = tmp;

                file >> tmp; rmapsize = tmp;
                file >> tmp; rcolorsize = tmp;
                file >> tmp; rscreensize = tmp;

                if(version >= 3)
                {
                    file >> tmp; rbackbuffers = tmp;
                }
                else
                    rbackbuffers = 1;

                //The old size calculation
                int temp_buffersize = 1 + (5 + rmapsize + rscreensize + rcolorsize) * 1;
                BYTE *temp_buffer = (BYTE *)_aligned_malloc(temp_buffersize, 16);

                //Expand from crippled to full
                if(mode == CHAR || mode == MC_CHAR)
                    rcolorsize = rmapsize/8;

                Destroy();
                Create(rmapsize, rcolorsize, rscreensize, rbackbuffers);

                file.read(temp_buffer, temp_buffersize);

                //Copy over lock
                for(int r=0;r<6;r++)
                    lock[r]=BYTE(tmplock);

                //Copy over background
                *background = temp_buffer[1];

                //Copy over map
                memcpy(map, temp_buffer+1+4, rmapsize);

                //Copy over color
                if(mode == MC_CHAR)
                {
                    memset(color, temp_buffer[1+4+rmapsize + 2], rcolorsize);
                    ext[1] = temp_buffer[1+4+rmapsize + 1];
                    ext[0] = temp_buffer[1+4+rmapsize + 0];

                    //Copy over screen
                    //memcpy(screen, temp_buffer+1+4+rmapsize+3, rscreensize);
                }
                else if(mode == CHAR)
                {
                    memset(color, temp_buffer[1+4+rmapsize + 0], rcolorsize);

                    //Copy over screen
                    //memcpy(screen, temp_buffer+1+4+rmapsize+1, rscreensize);
                }
                else
                {
                    memcpy(color, temp_buffer+1+4+rmapsize, rcolorsize);
                    //Copy over screen
                    memcpy(screen, temp_buffer+1+4+rmapsize+rcolorsize, rscreensize);
                }


                _aligned_free(temp_buffer);
                 */
            }
            
            // TODO: implement SetPalette
            // SetPalette(GetMetaInt("palette"));
        } // if type == "gpx"
    }

    
    /*
    func customCommand(n:Int) {
        
    }
    */
    
    
    // MARK: Font
    func setFontDisplay(mode:Int) {}
    func getFontDisplay() -> Int { return 0 }
    
    // Mark: Sizes
    var sizeX:Int { get{return canvasModel.xsize} } // TODO: Refactor to width
    var sizeY:Int { get{return canvasModel.ysize} } // TODO: Refactor to height
    /// Window version: GetCellSizeX
    var cellSizeX:Int { get{return canvasModel.xcell} } // TODO: Refactor to cellWidth
    /// Window version: GetCellSizeY
    var cellSizeY:Int { get{return canvasModel.ycell} } // TODO: Refactor to cellHeight
    var cellCountX:Int {
        
        get{
            if canvasModel.xcell != 0 {
                
                return canvasModel.xsize/canvasModel.xcell
            }
            return 0
        }
    }
    
    var cellCountY:Int {
        
        get{
            
            if canvasModel.ycell != 0 {
                
                return canvasModel.ysize/canvasModel.ycell
            }
            return 0
        }
    }
    
    // MARK: Color
    var background:UInt8 {
        
        get {
            
            // Original: infouse[0].use != .INFO_NO ?? *infouse[0].pp[0] : 0;
            if infouse[0].use != .INFO_NO {
                
                if infouse[0].pp != nil {
                
                    return infouse[0].pp!.pointee
                }
            }
            return 0
        }
    }
    
    func guessBorderColor() -> UInt8 {
                     
        // Default:
        // return 0x0e
        
        var colcount:Array<Int> = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        //var high:Int = -1
        //var best:Int = 0

        for x in 0..<canvasModel.xsize { // for(x=0;x<xsize;x++)
            
            //colcount[GetPixel(x,0)]++;
            colcount[Int(pixel(x, 0))] += 1   // getPixel was renamed to pixel
            
            //colcount[GetPixel(x,ysize-1)]++;
            colcount[Int(pixel(x, canvasModel.ysize-1))] += 1   // getPixel was renamed to pixel
        }

        for y in 0..<canvasModel.ysize {  // for(y=0;y<ysize;y++)
        
            //colcount[GetPixel(0,y)]++;
            colcount[Int(pixel(0, y))] += 1   // getPixel was renamed to pixel
            //colcount[GetPixel(xsize-1,y)]++;
            colcount[Int(pixel(canvasModel.xsize-1, y))] += 1   // getPixel was renamed to pixel
        }

        return UInt8(importHelper.highIndex(colcount, count: 16))
    }
    var borderColor:Int32 {
        get {
            
            if let border = canvasModel.border {
            
                
                return Int32(border.pointee)
            }
            return 0
        }
    }
    
    func remapCellColour(cx:Int, cy:Int, colour:Int, indexTo:Int) {}
    func swapCellColours(cx:Int, cy:Int) {}
    
    // MARK: Undo and Redo

    /// Snapshot the buffer before a modification. Call before any pixel changes.
    func beginHistory() {
        guard let buffer = canvasModel.buffer else { return }

        // Copy current buffer to tbuffer for later delta comparison
        if canvasModel.tbuffer == nil {
            canvasModel.tbuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: canvasModel.buffersize)
        }
        canvasModel.tbuffer!.initialize(from: buffer, count: canvasModel.buffersize)

        // History limit: keep at most 100 entries
        while history_pos > 100 {
            history_undo[0].deallocate()
            history_redo[0].deallocate()
            history_undo.remove(at: 0)
            history_redo.remove(at: 0)
            history_pos -= 1
        }

        // If we're not at the end of the history, discard future redo states
        if history_pos < history_redo.count {
            deleteHistoryNext()

            for r in history_pos..<history_redo.count {
                history_undo[r].deallocate()
                history_redo[r].deallocate()
            }
            // Truncate arrays to current position
            history_undo.removeSubrange(history_pos..<history_undo.count)
            history_redo.removeSubrange(history_pos..<history_redo.count)
        }
    }

    /// Compute delta between tbuffer (old) and buffer (new), store compressed undo/redo.
    func endHistory() {
        guard let buffer = canvasModel.buffer,
              let tbuffer = canvasModel.tbuffer else { return }

        let size = canvasModel.buffersize

        // Build delta-compressed undo and redo data
        // Format: [int32 totalSize] then repeating [uint16 skip] [uint16 changed] [bytes...]
        // Terminated by skip=0
        var undoData = Data(count: 4)  // reserve 4 bytes for size header
        var redoData = Data(count: 4)

        var r = 0
        while true {
            // Count unchanged bytes (skip)
            var skipcount: UInt16 = 0
            while r < size && skipcount < 0xffff {
                if buffer[r] != tbuffer[r] { break }
                r += 1
                skipcount += 1
            }

            // Write skipcount to both streams
            undoData.append(UInt8(skipcount & 0xff))
            undoData.append(UInt8(skipcount >> 8))
            redoData.append(UInt8(skipcount & 0xff))
            redoData.append(UInt8(skipcount >> 8))

            // skipcount == 0 means we reached the end or no more skips
            if skipcount == 0 { break }

            // Count changed bytes
            var changedcount: UInt16 = 0
            let t = r
            var end = r
            while end < size && changedcount < 0xffff {
                if buffer[end] == tbuffer[end] { break }
                end += 1
                changedcount += 1
            }

            // Write changedcount
            undoData.append(UInt8(changedcount & 0xff))
            undoData.append(UInt8(changedcount >> 8))
            redoData.append(UInt8(changedcount & 0xff))
            redoData.append(UInt8(changedcount >> 8))

            // Write the actual changed bytes
            for i in t..<end {
                undoData.append(tbuffer[i])  // old data for undo
                redoData.append(buffer[i])   // new data for redo
            }
            r = end
        }

        // Write total size into the first 4 bytes
        let undoSize = Int32(undoData.count)
        let redoSize = Int32(redoData.count)
        withUnsafeBytes(of: undoSize) { undoData.replaceSubrange(0..<4, with: $0) }
        withUnsafeBytes(of: redoSize) { redoData.replaceSubrange(0..<4, with: $0) }

        // Allocate and copy to UnsafeMutablePointer (matching existing array type)
        let undoPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: undoData.count)
        undoData.copyBytes(to: undoPtr, count: undoData.count)
        let redoPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: redoData.count)
        redoData.copyBytes(to: redoPtr, count: redoData.count)

        history_undo.append(undoPtr)
        history_redo.append(redoPtr)
        history_pos += 1

        dirty = true
    }

    func inheritHistory(old:PCC64Interface!){
                
        old.history_next = self
        history_previous = old
    }
    
    func deleteHistoryPrevious() {
    
        if history_previous != nil {
            
            history_previous!.history_next = nil
            history_previous = nil;
        }
    }

    
    func deleteHistoryNext() {
        
        if history_next != nil {
            
            history_next!.history_previous = nil
            history_next = nil
        }
    }
    
    /**
        Clears the undi bufer
     */
    func resetHistory() {
        
        // for int t=history_undo.count()-1;t>=0;t--)
        history_undo.removeAll()
        history_redo.removeAll()
        
        history_pos = 0
    }
    
    /// Apply a delta-compressed history entry to the current buffer.
    /// Format: repeating [uint16 skip] [uint16 changed] [bytes...], terminated by skip=0
    func playHistory(_ data: UnsafeMutablePointer<UInt8>) {
        guard let buffer = canvasModel.buffer else { return }

        var pos = 0       // read position in data
        var bufPos = 0    // write position in buffer

        while true {
            // Read skipcount (little-endian uint16)
            let skipcount = Int(data[pos]) | (Int(data[pos + 1]) << 8)
            pos += 2

            if skipcount == 0 { break }

            bufPos += skipcount

            // Read changedcount (little-endian uint16)
            let changedcount = Int(data[pos]) | (Int(data[pos + 1]) << 8)
            pos += 2

            // Copy changed bytes into buffer
            for _ in 0..<changedcount {
                buffer[bufPos] = data[pos]
                bufPos += 1
                pos += 1
            }
        }
    }
     
    /// bool CanUndo(void){return history_pos > 0 || history_previous;}
    var canUndo:Bool { get {return history_pos > 0 || history_previous != nil} }
    
    /// bool CanRedo(void){return history_pos < history_redo.count() || history_next;}
    var canRedo:Bool { get {return history_pos < history_redo.count || history_next != nil} }
    
    func undo() -> PCC64Interface? {
        // If at the beginning and there's a previous object, switch to it
        if history_pos == 0 && history_previous != nil {
            history_previous!.file_name = ""
            return history_previous
        }

        guard history_pos > 0 else { return self }

        history_pos -= 1
        playHistory(history_undo[history_pos].advanced(by: 4))
        return self
    }
    
    func redo() -> PCC64Interface? {
        // If at the end and there's a next object, switch to it
        if history_pos == history_redo.count && history_next != nil {
            history_next!.file_name = ""
            return history_next
        }

        guard history_pos < history_redo.count else { return self }

        playHistory(history_redo[history_pos].advanced(by: 4))
        history_pos += 1
        return self
    }
     
    // MARK: Mark dirty
    var isDirty:Bool { get {return dirty} }
    func setDirty(){ dirty=true }
    func clearDirty(){ dirty=false }
     
    // MARK: Filename
    var fileName:String { get{ return file_name } }
    func setFileName(_ s:String) { file_name=s; }
    var fileExt:String {
     
        let url = URL(fileURLWithPath: file_name)
        return url.pathExtension
    }
     /*
     void Save(LPCTSTR pszFileName, LPCTSTR type);
     
     static nstr IdentifyFile(LPCTSTR pszFileName);
     static C64Interface *Load(LPCTSTR pszFileName, LPCTSTR type, tmode importmode, int width, int height);
     static C64Interface *CreateFromImage(CImage *img, int count, tmode type);
     static C64Interface *Allocate(tmode mode, int w, int h, int buffers=1);
     
     virtual C64Interface *CreateFromSelection(int x, int y, int w, int h);
     
     void Optimize(void);
     
     bool IsBitmap(void){return mode == BITMAP || mode == MC_BITMAP;}
     bool IsSprite(void){return mode == SPRITE || mode == MC_SPRITE;}
     */
    var isChar:Bool {
        
        get {
        
            return self.canvasModel.mode == .CHAR || self.canvasModel.mode == .MC_CHAR
        }
    }
     /*
     bool IsMultiColor(void){return mode == MC_CHAR || mode == MC_SPRITE || mode == MC_BITMAP || mode == W_UNRESTRICTED;}
     bool IsSingleColor(void){return !IsMultiColor();}
     bool IsUnrestricted(void){return mode == W_UNRESTRICTED || mode == UNRESTRICTED;}
     tmode GetMode(void){return mode;}
     
     void RenderImage(CImage &img, int startx=0, int starty=0, int width=-1, int height=-1);
     void RenderColourUsageImage(CImage & inimg, int startx=0, int starty=0, int width=-1, int height=-1);
     */
     
    /// Windows version: int GetBackBuffer(void){return rbackbufnum;}
    var backBuffer:Int {
        
        get {
            
            return canvasModel.rbackbufnum
        }
    }
    
    /// Windows version: int GetBackBufferCount(void){return rbackbuffers;}
    var backBufferCount:Int {
        
        get {
        
            return canvasModel.rbackbuffers
        }
     }
    
    /**
        Returns the pixel aspect ratio.
     */
    func getPAR() -> Int {
        
        return canvasModel.par
    }
    
    /**
        Returns the double value for the Pixel Apset Ratio
     */
    func getPARValue() -> Double {
        
        return PCC64Interface.parvalue[canvasModel.par]
    }
     
    
    /**
        Sets the pixel aspect ratio.
     */
    func setPAR(_ n:Int) {
        
        canvasModel.par = n
    }
     /*
     toverflow GetOverflow(void){return overflow;}
     void SetOverflow(toverflow n){overflow = n;}
     */
     
    func setMetaInt(_ tag:String, _ value:Int) {
        
        canvasModel.meta[tag]=String(value)
    }
     
    func metaInt(_ tag:String) -> Int {
        
        if let value = canvasModel.meta[tag] {
        
            if let iValue = Int(value) {
            
                return iValue
            }
        }
        return 0
    }
    
    func setMetaStr(_ tag:String, _ value:String){
        
        canvasModel.meta[tag] = value
    }
    
    func metaStr(_ tag:String) -> String {
        
        if let value = canvasModel.meta[tag] {
         
            return value
        }
        return ""
    }
     /*
     //Specialized threaded for, for cell boundary
     template<typename Function>
     void paralell_for_ycell(int from, int to, Function &&fn)
     {
     int csy = GetCellSizeY();
     int afrom = (from % csy) ? from + (csy - (from % csy)) : from;
     
     if (afrom >= to)
     {
     while (from < to)
     {
     fn(from);
     from++;
     }
     return;
     }
     
     int ato = (to % csy) ? to - (to % csy) : to;
     if (ato < afrom)ato = afrom;
     int s;
     threadpool::waitable *w = nullptr;
     
     int cells = (ato - afrom) / csy;
     if (cells)
     {
     int tnum = g_pThreadPool->get_thread_num();
     s = cells < tnum ? cells : tnum;
     
     int slice = (cells / s) * csy;
     
     w = new threadpool::waitable[s];
     
     for (int r = 0; r < s; r++)
     {
     int f = r * slice + afrom;
     int t = r != s - 1 ? f + slice : ato;
     
     w[r] = schedule([f, t, &fn]
     {
     for (int r = f; r < t; r++)
     {
     fn(r);
     }
     });
     }
     }
     
     while (from < afrom)
     {
     fn(from);
     from++;
     }
     
     while (ato < to)
     {
     fn(ato);
     ato++;
     }
     
     if (w)
     {
     for (int r = 0; r < s; r++)
     w[r]->wait();
     
     delete[] w;
     }
     
     }
     
               
     bool IsMaskGlobal(int mask){return infouse[mask].use == InfoUse::INFO_VALUE || crippled[mask];}
     bool IsMaskLocal(int mask){return !IsMaskGlobal(mask);}
               
     void DeleteHistoryPrevious(void);
     void DeleteHistoryNext(void);
          
     */
    
    func setBackBuffer(_ n:Int) throws {
        
        if let buffer = canvasModel.buffer {
            
            // BYTE *p = buffer + 64 + (64 + rmapsize + rscreensize + rcolorsize) * n;
            let ofs = 64 + (64 + canvasModel.rmapsize + canvasModel.rscreensize + canvasModel.rcolorsize) * n
            var p:UnsafeMutablePointer<UInt8> = buffer.advanced(by: ofs)

            p = p.advanced(by: 47) // p+=47;    //Extra bytes
            
            canvasModel.crippled = p
            p = p.advanced(by: 6) // p+=6;

            canvasModel.lock = p
            p = p.advanced(by: 6) // p+=6;
                                                            
            canvasModel.border = p
            p = p.advanced(by: 1) // p++;

            canvasModel.background = p
            p = p.advanced(by: 1) // p++;

            canvasModel.ext = p
            canvasModel.ext0 = p
            p = p.advanced(by: 1) // p++;
            canvasModel.ext1 = p
            p = p.advanced(by: 1) // p++;
            canvasModel.ext2 = p
            p = p.advanced(by: 1) // p++;
            
            canvasModel.map = p
            p = p.advanced(by: canvasModel.rmapsize)  // p += rmapsize;

            canvasModel.color = p
            p = p.advanced(by: canvasModel.rcolorsize)  // p += rcolorsize;
            
            canvasModel.screen = p
            canvasModel.rbackbufnum = n;

            setupInfoUse()
        } else {

            throw C64InterfaceError.backbuffersMissing
        }
    }


    func clearBackBuffer() {

        if let buffer = canvasModel.buffer {

            // BYTE *p = buffer + 64 + (64 + rmapsize + rscreensize + rcolorsize) * rbackbufnum;
            // ZeroMemory(p+64, (rmapsize + rscreensize + rcolorsize));
            let ofs = 64 + (64 + canvasModel.rmapsize + canvasModel.rscreensize + canvasModel.rcolorsize) * canvasModel.rbackbufnum
            let p:UnsafeMutablePointer<UInt8> = buffer.advanced(by: ofs + 64)
            p.assign(repeating: 0, count: (canvasModel.rmapsize + canvasModel.rscreensize + canvasModel.rcolorsize))
        }
    }

    /// Zeros the map, screen, and color data buffers while preserving pointer assignments.
    /// Used by Optimize to clear pixel data before re-painting.
    func zeroDataBuffers() {
        if let map = canvasModel.map {
            map.assign(repeating: 0, count: canvasModel.rmapsize)
        }
        if let screen = canvasModel.screen, canvasModel.rscreensize > 0 {
            screen.assign(repeating: 0, count: canvasModel.rscreensize)
        }
        if let color = canvasModel.color, canvasModel.rcolorsize > 0 {
            color.assign(repeating: 0, count: canvasModel.rcolorsize)
        }
    }


   
     /*
     void RemapCell1(int cx, int cy, int maskfrom, int maskto);
     void RemapCell2(int cx, int cy, int maskfrom, int maskto);
     void RemapCell2(int cx, int cy, int w, int h, int maskfrom, int maskto);
     
     void SwapmaskCell2(int cx, int cy, int maskfrom, int maskto);
     void SwapmaskCell2(int cx, int cy, int w, int h, int maskfrom, int maskto);
     
     static BYTE RemapByte2(BYTE in, int maskfrom, int maskto);
     static BYTE SwapmaskByte2(BYTE in, int maskfrom, int maskto);
     
     void CountCell2(int cx, int cy, int *c);
     void CountCell2(int cx, int cy, int w, int h, int *c);
     
     void CountCell1(int cx, int cy, int *c);
     void CountCell1(int cx, int cy, int w, int h, int *c);
     
     BYTE GetCommonColorFromMask(int mask, BYTE *index, int size, bool high=false);
     
     BYTE GetColor(int ci, int infoindex);
     void SetColor(int ci, int infoindex, BYTE col);
     
     int ResolveMask1(int ci, BYTE &col, int pointmask);
     int ResolveMask2(int ci, BYTE &col, int pointmask, bool charmode=false);
     int ResolveRemask2(BYTE *c);
     int ResolveReplaceRemask2(BYTE *c);
     */
    
    
    /*
     
     int GetMapIndexFromCell(int cx, int cy){return ((xsize/xcell) * cy + cx) * offsetcell;}
     int GetMapIndex(int x, int y){return 0 ;}
     
     void PushLocks(void){memcpy(savelock, lock, 6);}
     void PopLocks(void){memcpy(lock, savelock, 6);}
     
     
     class ImportHelper
     {
     public:
     ImportHelper(C64Interface *p, CImage &img, bool wide);
     ~ImportHelper();
     
     int CountColors(int cx, int cy, int w, int h, int *colcount);
     int CountTopColors(int cx, int cy, int w, int h, BYTE *col);
     
     int CountTopColorsPerCell(BYTE *col, int ceil=4);
     void ReduceColors(int maxcolor, BYTE *force, int forcecount);
     
     static int HighIndex(int *list, int count)
     {
     return highindex(list, count);
     }
     
     private:
     CImageFast &img;
     
     COLORREF GetImagePixel(int x, int y);
     
     BYTE GetPixel(int x, int y) { return p[y*xsize + x]; }
     void SetPixel(int x, int y, BYTE c) { p[y*xsize + x] = c; }
     
     int xsize, ysize, xcs, ycs;
     
     C64Interface *parent;
     
     bool wide;
     
     int palette;
     BYTE *p;
     
     bool find(BYTE col, BYTE *p, int count)
     {
     for(int r=0;r<count;r++)
     {
     if(col == p[r])
     return true;
     }
     return false;
     }
     
     static int highindex(int *list, int count)
     {
     int high = 0;
     int best = -1;
     for(int r=0;r<count;r++)
     {
     if(list[r] > high)
     {
     high = list[r];
     best = r;
     }
     }
     
     return best;
     }
     
     };
     
     private:
     
     
          
     
     void GetMaskInfo(int cx, int cy, int w, int h, int infoindex, CellInfo &info);
     void SetMaskInfo(int cx, int cy, int w, int h, int infoindex, CellInfo &info);
     
     bool mymemspn_low(const BYTE *ptr, BYTE value, int num)
     {
     for(;num>1;num--,ptr++)
     {
     if(((*ptr)&0x0f)!=value)
     return false;
     }
     return true;
     }
     
     bool mymemspn_high(const BYTE *ptr, BYTE value, int num)
     {
     for(;num>1;num--,ptr++)
     {
     if(((*ptr)&0xf0)!=value)
     return false;
     }
     return true;
     }
     };
     */
}
