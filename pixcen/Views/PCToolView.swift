//
//  PCToolView.swift
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

class PCToolView: NSView {
    
    var toolViewController:NSViewController!
    var myTrackingArea: NSTrackingArea!

    /*
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    */
    /**
      In updateTrackingAreas you can register the NSTrackingArea functions
     */
    override func updateTrackingAreas() {
        
        if myTrackingArea != nil {
            
            self.removeTrackingArea(myTrackingArea)
        }
        myTrackingArea = NSTrackingArea(rect:self.bounds, options:NSTrackingArea.Options(rawValue: NSTrackingArea.Options.mouseEnteredAndExited.rawValue | NSTrackingArea.Options.activeAlways.rawValue), owner:self, userInfo:nil)
        self.addTrackingArea(myTrackingArea)
    }
    
    /**
     in viewWillMove(toWindow:) you can register the NSTrackingArea functions
    */
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        
        // Setup a new tracking area when the view is added to the window.
        myTrackingArea = NSTrackingArea(rect:self.bounds, options:NSTrackingArea.Options(rawValue: NSTrackingArea.Options.mouseEnteredAndExited.rawValue | NSTrackingArea.Options.activeAlways.rawValue), owner:self, userInfo:nil)
        self.addTrackingArea(myTrackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
                
        self.becomeFirstResponder()
        if let window = self.window {
            
            window.makeKeyAndOrderFront(self)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
                
        self.resignFirstResponder()
    }
}
