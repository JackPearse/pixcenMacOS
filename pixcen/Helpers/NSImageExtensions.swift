//
//  NSImageExtensions.swift
//  pixcen
//
//  Created by Jack Pearse on 21.11.20.
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
import CoreImage
import CoreImage.CIFilterBuiltins

public extension NSImage {
    
    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
            ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            
            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }
        
        return nil
    }
    
    /// The height of the image.
    var height: CGFloat {
        return size.height
    }

    /// The width of the image.
    var width: CGFloat {
        return size.width
    }
    
    /// Copy the image and resize it to the supplied size, while maintaining it's
    /// original aspect ratio.
    ///
    /// - Parameter size: The target size of the image.
    /// - Returns: The resized image.
    func resizeMaintainingAspectRatio(withSize targetSize: NSSize) -> NSImage? {
        
        let newSize: NSSize
        let widthRatio  = targetSize.width / self.width
        let heightRatio = targetSize.height / self.height
        
        if self.width > self.height {
            newSize = NSSize(width: floor(self.width * widthRatio),
                             height: floor(self.height * widthRatio))
        } else {
            newSize = NSSize(width: floor(self.width * heightRatio),
                             height: floor(self.height * heightRatio))
        }
        
        return self.resized(to: newSize)
    }
    
    func rotatedByDegreess(degrees:CGFloat) -> NSImage {

        var imageBounds = NSZeroRect ; imageBounds.size = self.size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
        transform.rotate(byDegrees: degrees)
        pathBounds.transform(using: transform as AffineTransform)
        let rotatedBounds:NSRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y, pathBounds.bounds.size.width, pathBounds.bounds.size.height )
        let rotatedImage = NSImage(size: rotatedBounds.size)

        //Center the image within the rotated bounds
        imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2)
        imageBounds.origin.y  = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2)

        // Start a new transform
        transform = NSAffineTransform()
        // Move coordinate system to the center (since we want to rotate around the center)
        transform.translateX(by: +(NSWidth(rotatedBounds) / 2 ), yBy: +(NSHeight(rotatedBounds) / 2))
        transform.rotate(byDegrees: degrees)
        // Move the coordinate system bak to normal
        transform.translateX(by: -(NSWidth(rotatedBounds) / 2 ), yBy: -(NSHeight(rotatedBounds) / 2))
        // Draw the original image, rotated, into the new image
        rotatedImage.lockFocus()
        transform.concat()
        self.draw(in: imageBounds, from: NSZeroRect, operation: NSCompositingOperation.copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }
    
    /**
        Invert colors using core Image filters, if availyble, else the original image is returned
     */
    func inverted() -> NSImage {
                
        if #available(OSX 10.15, *) {
            
            let filter = CIFilter.colorInvert()
            let context = CIContext()
                        
            if let tiffData = self.tiffRepresentation {
                
                if let bitmap = NSBitmapImageRep(data: tiffData) {
                    
                    let ciImage = CIImage(bitmapImageRep: bitmap)
                    
                    filter.inputImage = ciImage
                    //filter.intensity = Float(1.0) // Used by i.e. sepia

                    guard let outputImage = filter.outputImage else { return self }

                    if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                         
                        let nsImage = NSImage(cgImage: cgimg, size: self.size)
                        return nsImage
                    }
                }
            }
            // Bypass original, if any error occured.
            return self
        } else {
            
            return self
        }
    }
}
