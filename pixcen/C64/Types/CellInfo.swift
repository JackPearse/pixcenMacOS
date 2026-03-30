//
//  CellInfo.swift
//  PixcenFoundation
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

struct CellInfo {
    
    var w:Int = -1
    var h:Int = -1
    var col = Array<UInt8>(repeating: 0xff, count: 6)
    var lock = Array<Int>(repeating: -1, count: 6)
    var crippled = Array<Int>(repeating: -1, count: 6)
   
    /*
     Hint:
     If you want to use the array in c-style, use
     
     array.withUnsafeBufferPointer() { (cArray: UnsafePointer<Float>) -> () in
         // do something with the C array
     }
     */        
}
