//
//  C64Col.swift
//  pixcen
//
//  Created by Jack Pearse on 28.01.21.
//

import Foundation
import Cocoa

typealias COLORREF = UInt32

fileprivate let c64Col_sharedInstance = C64Col()
class C64Col {
    
    /// Use calibrated colors? MacOS feature
    var calibrated:Bool = false
    
    class var shared:C64Col{
      
        return c64Col_sharedInstance
    }
    
    fileprivate var paletteIndex:Int = 0
    var g_Vic2:[UInt32]!
    var color:[NSColor] = []
    var borderColor:[NSColor] = []
    
    let palette:[String:[UInt32]] = [
        "default":[0x000000,
                    0xffffff,
                    0x894036,
                    0x7abfc7,
                    0x8a46ae,
                    0x68a941,
                    0x3e31a2,
                    0xd0dc71,
                    0x905f25,
                    0x5c4700,
                    0xbb776d,
                    0x555555,
                    0x808080,
                    0xacea88,
                    0x7c70da,
                    0xababab],
         "pepto": [0x000000,
                    0xFFFFFF,
                    0x68372B,
                    0x70A4B2,
                    0x6F3D86,
                    0x588D43,
                    0x352879,
                    0xB8C76F,
                    0x6F4F25,
                    0x433900,
                    0x9A6759,
                    0x444444,
                    0x6C6C6C,
                    0x9AD284,
                    0x6C5EB5,
                    0x959595],
        "c64hq":  [0x0A0A0A,
                    0xFFF8FF,
                    0x851F02,
                    0x65CDA8,
                    0xA73B9F,
                    0x4DAB19,
                    0x1A0C92,
                    0xEBE353,
                    0xA94B02,
                    0x441E00,
                    0xD28074,
                    0x464646,
                    0x8B8B8B,
                    0x8EF68E,
                    0x4D91D1,
                    0xBABABA],
        "c64s":   [0x000000,
                    0xFCFCFC,
                    0xA80000,
                    0x54FCFC,
                    0xA800A8,
                    0x00A800,
                    0x0000A8,
                    0xFCFC00,
                    0xA85400,
                    0x802C00,
                    0xFC5454,
                    0x545454,
                    0x808080,
                    0x54FC54,
                    0x5454FC,
                    0xA8A8A8],
        "ccs64":  [0x101010,
                    0xFFFFFF,
                    0xE04040,
                    0x60FFFF,
                    0xE060E0,
                    0x40E040,
                    0x4040E0,
                    0xFFFF40,
                    0xE0A040,
                    0x9C7448,
                    0xFFA0A0,
                    0x545454,
                    0x888888,
                    0xA0FFA0,
                    0xA0A0FF,
                    0xC0C0C0],
        "frodo":   [0x000000,
                    0xFFFFFF,
                    0xCC0000,
                    0x00FFCC,
                    0xFF00FF,
                    0x00CC00,
                    0x0000CC,
                    0xFFFF00,
                    0xFF8800,
                    0x884400,
                    0xFF8888,
                    0x444444,
                    0x888888,
                    0x88FF88,
                    0x8888FF,
                    0xCCCCCC],
        "godot":  [0x000000,
                    0xFFFFFF,
                    0x880000,
                    0xAAFFEE,
                    0xCC44CC,
                    0x00CC55,
                    0x0000AA,
                    0xEEEE77,
                    0xDD8855,
                    0x664400,
                    0xFE7777,
                    0x333333,
                    0x777777,
                    0xAAFF66,
                    0x0088FF,
                    0xBBBBBB],
        "pc64":    [0x212121,
                    0xFFFFFF,
                    0xB52121,
                    0x73FFFF,
                    0xB521B5,
                    0x21B521,
                    0x2121B5,
                    0xFFFF21,
                    0xB57321,
                    0x944221,
                    0xFF7373,
                    0x737373,
                    0x949494,
                    0x73FF73,
                    0x7373FF,
                    0xB5B5B5],
        "colodore":[0x000000,
                    0xffffff,
                    0x813338,
                    0x75cec8,
                    0x8e3c97,
                    0x56ac4d,
                    0x2e2c9b,
                    0xedf171,
                    0x8e5029,
                    0x553800,
                    0xc46c71,
                    0x4a4a4a,
                    0x7b7b7b,
                    0xa9ff9f,
                    0x706deb,
                    0xb2b2b2],
        "PALette": [0x000000,
                    0xd5d5d5,
                    0x72352c,
                    0x659fa6,
                    0x733a91,
                    0x568d35,
                    0x2e237d,
                    0xaeb75e,
                    0x774f1e,
                    0x4b3c00,
                    0x9c635a,
                    0x474747,
                    0x6b6b6b,
                    0x8fc271,
                    0x675db6,
                    0x8f8f8f]]
    
    
    let paletteName = ["default",
                        "pepto",
                        "c64hq",
                        "c64s",
                        "ccs64",
                        "frodo",
                        "godot",
                        "pc64",
                        "colodore",
                        "PALette"]
    
    let s_VICColourName = ["Black",
                            "White",
                            "Red",
                            "Cyan",
                            "Purple",
                            "Green",
                            "Blue",
                            "Yellow",
                            "Orange",
                            "Brown",
                            "Pink",
                            "D.Grey",
                            "M.Grey",
                            "L.Green",
                            "L.Blue",
                            "L.Grey"]
    

    func closestMatch(_ c:COLORREF, list:[COLORREF], num:Int) -> Int {
        
        return 0
    }

    func toC64Index(c:COLORREF) -> UInt8 {
        
        return 0x000000
    }

    func closestPalette(list:[COLORREF], num:Int) -> Int {
        
        return 0
    }
    
    /**
        Same like setPalette in the windows version.
        selects the new palette, prepares objects
        and returns the last value.
     */
    func selectPalette(_ n:Int) -> Int {
        
        let old = currentPalette
        if n < paletteName.count {
        
            let palName = paletteName[n]
            g_Vic2 = palette[palName]
            
            // precalc both color and
            // possible border colors
            var c:NSColor!
            var bc:NSColor!
            if g_Vic2 != nil {
            
                for (i, color) in g_Vic2.enumerated() {
                
                    let r = UInt8((color >> 16) & 0xff)
                    let g = UInt8((color >> 8) & 0xff)
                    let b = UInt8(color & 0xff)
                    
                    // chance the color slightly for
                    // possible border colors
                    /*
                     //Change border color slightly from palette
                     BYTE *bd=(BYTE *)&border;
                     for(int x=3;x>=1;x--)
                     {
                         if(bd[x]>=0xf0)bd[x]-=0x10;
                         else bd[x]+=0x10;
                     }
                     */                                        
                    let br = (r >= 0xf0) ? r-0x04 : r+0x04
                    let bg = (g >= 0xf0) ? g-0x11 : g+0x11
                    let bb = (b >= 0xf0) ? b-0x11 : b+0x11
                                
                    if calibrated {
                     
                        c = NSColor(calibratedRed: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: 1.0)
                        
                        bc = NSColor(calibratedRed: CGFloat(br)/255.0, green: CGFloat(bg)/255.0, blue: CGFloat(bb)/255.0, alpha: 1.0)
                    } else {
                        
                        
                        c = NSColor(deviceRed: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: 1.0)
                                                
                        bc = NSColor(deviceRed: CGFloat(br)/255.0, green: CGFloat(bg)/255.0, blue: CGFloat(bb)/255.0, alpha: 1.0)
                        
                        /*
                         // No color space
                        c = NSColor(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: 1.0)
                        */
                    }
                    if i < self.color.count {
                    
                        self.color[i] = c
                        self.borderColor[i] = bc
                    } else {
                        
                        self.color.append(c)
                        self.borderColor.append(bc)
                    }
                }
            }
        }
        return old
    }
    
    var currentPalette : Int {
        
        return paletteIndex
    }

    func blend(aa:COLORREF, bb:COLORREF) -> COLORREF {
        
        let a:UInt8 = UInt8(((aa)&0xff) + ((bb)&0xff)) / 2
        let b:UInt8 = UInt8(((aa>>8)&0xff) + ((bb>>8)&0xff)) / 2
        let c:UInt8 = UInt8(((aa>>16)&0xff) + ((bb>>16)&0xff)) / 2

        return COLORREF((c << 16) | (b << 8) | a)
    }
    
    init() {
        
        _ = selectPalette(0)
    }
}
