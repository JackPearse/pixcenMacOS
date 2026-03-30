//
//  PCC64PaletteView.swift
//  pixcen
//
//  Created by Jack Pearse on 03.08.20.
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

import Cocoa
//import PixcenFoundation

class PCC64PaletteView: PCToolView {

    var col1:Int = 1
    var col2:Int = 0
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        /*
        NSColor.clearColor().set()
        if backgroundColor != nil {
        
            backgroundColor?.set()
            __NSRectFill(dirtyRect)
        }
         */
        var p = NSBezierPath()
        let h = bounds.size.height / 8
        let w = bounds.size.width / 2

        for x in 0..<2 {
            
            for y in 0..<8 {
                        
                // In MacOS the y-coordinate is in the bottom left corner,
                // therefore transform y.
                // Use x*8+(7-y) instead of x*8+y
                let squareIndex = x*8+(7-y)
                
                let rect = NSRect(x: CGFloat(x)*w, y: CGFloat(y)*h, width: w, height: h)
                p = NSBezierPath()
                p.appendRect(rect)
                                
                // y coord transform for MacOS!
                let color = C64Col.shared.color[x*8+(7-y)] //g_Vic2[x*8+y]
                color.set()
                p.fill()
        
                if squareIndex == col1 {
                
                    //drawSquare(x:CGFloat(x)*w, y:CGFloat(y)*h, w:w, h:h, c:col1)
                    drawSquare(x:CGFloat(x)*w, y:CGFloat(y)*h, w:w, h:h, c:col1)
                }
                if squareIndex == col2 {
                
                    //drawEx(x:CGFloat(x)*w, y:CGFloat(y)*h, w:w, h:h, c:col2)
                    drawEx(x:CGFloat(x)*w, y:CGFloat(y)*h, w:w, h:h, c:col2)
                }
            }
        }
    }
    
    
    func drawSquare(x:CGFloat, y:CGFloat, w:CGFloat, h:CGFloat, c:Int) {
                        
        let dc = NSBezierPath()
        dc.move(to:CGPoint(x: x+3,y: y+3))
        dc.line(to:CGPoint(x: x+w-3,y: y+3))
        dc.line(to:CGPoint(x: x+w-3,y: y+h-3))
        dc.line(to:CGPoint(x: x+3,y: y+h-3))
        dc.line(to:CGPoint(x: x+3,y: y+3))
    
        dc.lineWidth = 2
        dc.lineCapStyle = .round
        if c == 0 {
            
            NSColor.white.set()
        } else {
            
            NSColor.black.set()
        }
        dc.stroke()
    }
    
    func drawEx(x:CGFloat, y:CGFloat, w:CGFloat, h:CGFloat, c:Int) {
                     
        //CPen *old=dc.SelectObject(c==0?&(m_wpen):(&m_bpen));
        let dc = NSBezierPath()
        dc.move(to:CGPoint(x: x+8,y: y+8))
        dc.line(to:CGPoint(x: x+w-8,y: y+h-8))
        dc.move(to:CGPoint(x: x+w-8,y: y+8))
        dc.line(to:CGPoint(x: x+8,y: y+h-8))
        
        dc.lineWidth = 2
        dc.lineCapStyle = .round
        if c == 0 {
            
            NSColor.white.set()
        } else {
            
            NSColor.black.set()
        }
        dc.stroke()
    }
    
    override func mouseDown(with event: NSEvent) {

        var left = true
        if NSEvent.modifierFlags.contains(.control) {
            left = false
        }

        let location = convert(event.locationInWindow, from: nil)
        if left {
            self.col1 = self.getIndex(point: location)
        } else {
            self.col2 = self.getIndex(point: location)
        }

        // Update the canvas active colors
        if let delegate = NSApp.delegate as? AppDelegate,
           let canvas = delegate.pixelCanvasView {
            canvas.m_Col1 = self.col1
            canvas.m_Col2 = self.col2
        }

        self.needsDisplay = true
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {

        let location = convert(event.locationInWindow, from: nil)
        self.col2 = self.getIndex(point: location)

        if let delegate = NSApp.delegate as? AppDelegate,
           let canvas = delegate.pixelCanvasView {
            canvas.m_Col2 = self.col2
        }

        self.needsDisplay = true
        super.rightMouseDown(with: event)
    }

    
    /*
    override func mouseUp(with event: NSEvent) {
        
    }
    
    override func rightMouseUp(with event: NSEvent) {
        
    }
    */
    
       
    func getIndex(point: CGPoint) -> Int {
        let h = self.bounds.size.height / 8
        let w = self.bounds.size.width / 2

        let x = max(0, min(1, Int(point.x / w)))
        let y = max(0, min(7, Int(point.y / h)))

        // macOS origin is bottom-left, transform Y
        return x * 8 + (7 - y)
    }
}
