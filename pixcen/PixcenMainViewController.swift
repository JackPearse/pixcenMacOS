//
//  ViewController.swift
//  pixcen
//
//  Created by JackPearse on 27.06.20.
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

class PixcenMainViewController: NSViewController {
    
    /// WIll be connected by prepare(for segue:, sender:)
    var pixelCanvasViewController: PCPixelCanvasViewController!
    var pixelCanvasView: PCPixelCanvasView!
    @IBOutlet weak var statusTextLabel: NSTextField!
    @IBOutlet weak var statusHintLabel: NSTextField!
    
    var statusText:String {
        
        set {
            
            self.statusTextLabel.stringValue = newValue
        }
        
        get {
            
            return self.statusTextLabel.stringValue
        }
    }
    
    @IBOutlet weak var statusBarHeightConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.mainViewController = self
        }

        // Initialize hint label with default text in gray, right-aligned
        let initFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let initPara = NSMutableParagraphStyle()
        initPara.alignment = .right
        statusHintLabel?.attributedStringValue = NSAttributedString(
            string: "\u{2325}+Drag = Select",
            attributes: [.foregroundColor: NSColor.tertiaryLabelColor, .font: initFont, .paragraphStyle: initPara]
        )
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "MSG_STATUS_TEXT"), object: nil, queue: nil) { (notification:Notification) in
            guard let userInfo = notification.userInfo,
                  let text = userInfo["status"] as? String else { return }

            // Left label: coordinates, zoom, selection info only
            self.statusTextLabel.stringValue = text

            // Right label: hints and indicators only (right-aligned)
            let boldFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let rightAlign = NSMutableParagraphStyle()
            rightAlign.alignment = .right
            let hint = NSMutableAttributedString()

            let hasPaste = userInfo["hasPasteBuffer"] as? Bool ?? false
            let isPasting = userInfo["isPasting"] as? Bool ?? false
            let hasSelection = userInfo["hasSelection"] as? Bool ?? false

            // Order: hint/action first (gray), then status indicator last (green/orange)
            // Most relevant info is rightmost
            if isPasting {
                hint.append(NSAttributedString(string: "Click target or ESC to abort",
                    attributes: [.foregroundColor: NSColor.systemOrange, .font: boldFont, .paragraphStyle: rightAlign]))
            } else if hasSelection {
                hint.append(NSAttributedString(string: "ESC = clear selection  ",
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: font, .paragraphStyle: rightAlign]))
                if hasPaste {
                    hint.append(NSAttributedString(string: "copybuffer",
                        attributes: [.foregroundColor: NSColor.systemGreen, .font: boldFont, .paragraphStyle: rightAlign]))
                }
            } else {
                hint.append(NSAttributedString(string: "\u{2325}+Drag = Select  ",
                    attributes: [.foregroundColor: NSColor.tertiaryLabelColor, .font: font, .paragraphStyle: rightAlign]))
                if hasPaste {
                    hint.append(NSAttributedString(string: "copybuffer",
                        attributes: [.foregroundColor: NSColor.systemGreen, .font: boldFont, .paragraphStyle: rightAlign]))
                }
            }

            self.statusHintLabel?.attributedStringValue = hint
        }
    }

    override var representedObject: Any? {
        didSet {
        
            // Update the view, if already loaded.
            // make the pointers to this view controller and
            // the pixel canvas available in app delegate
            // for quick access.
            if let delegate = NSApp.delegate as? AppDelegate {
                
                delegate.mainViewController = self
                delegate.pixelCanvasView = self.pixelCanvasView
            }
        }
    }
    
    /*
     Will be called by the selected menu item.
     - parameter n: n is the number of the menu items index, which is the same like the palette index of the pixcen lib.
     */
    func onModePalette(_ n:Int) {
        
        // in the windows original this function was part of CChildView
        // void CChildView::OnModePalette(UINT nID),
        // which is self.pixelCanvasView in the macOS-Version
        if self.pixelCanvasView != nil {
        
            self.pixelCanvasView.onModePalette(n)
        }
    }
    
    /**
     Toggles the status bar and returns the visibility state
     */
    func onToggleStatusBar() -> Bool {
        
        if self.statusBarHeightConstraint.constant > 0 {
            
            self.statusBarHeightConstraint.constant = 0
            return false
        } else {
            
            self.statusBarHeightConstraint.constant = 22
            return true
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        if let pcvc = segue.destinationController as? PCPixelCanvasViewController {
            
            self.pixelCanvasViewController = pcvc
            pcvc.mainViewController = self
        }
    }
}

