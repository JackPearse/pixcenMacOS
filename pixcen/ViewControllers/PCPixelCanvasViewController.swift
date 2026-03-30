//
//  PCPixelCanvasViewController.swift
//  pixcen
//
//  Created by Jack Pearse on 06.08.20.
//  Copyright © 2026 Drehwerk. All rights reserved.
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
import MetalKit

/// Hosts the pixel canvas MTKView. The MTKView fills this controller's
/// view entirely - no NSScrollView. All zoom/pan/grid is handled by the
/// Metal shader.
class PCPixelCanvasViewController: NSViewController {

    @IBOutlet weak var scrollView: NSScrollView!  // kept for storyboard outlet, removed at runtime
    @IBOutlet weak var canvasView: PCPixelCanvasView!

    var mainViewController: PixcenMainViewController!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Remove the NSScrollView from the storyboard hierarchy.
        // The MTKView will be placed directly in self.view.
        scrollView?.removeFromSuperview()

        // Create the MTKView programmatically (storyboard creates a plain NSView)
        let metalCanvas = PCPixelCanvasView(frame: self.view.bounds,
                                            device: MTLCreateSystemDefaultDevice())
        metalCanvas.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(metalCanvas)

        NSLayoutConstraint.activate([
            metalCanvas.topAnchor.constraint(equalTo: self.view.topAnchor),
            metalCanvas.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            metalCanvas.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            metalCanvas.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
        ])

        canvasView = metalCanvas

        // Share the canvas reference with other controllers
        if mainViewController != nil {
            mainViewController.pixelCanvasView = canvasView
        }
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.pixelCanvasView = canvasView
        }

        canvasView.initPixelCanvas()
    }
}
