//
//  SaveFormat.swift
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


struct SaveFormat {

    var name:String
    var ext:[String:Int]
    var good:Bool
    var width, height:Int
    var type:Int

    func matchExt(ex:String) -> Bool {
        
        return ext[ex.lowercased()] != nil
    }
    
    init(a:String, b:String, good:Bool, w:Int=0, h:Int=0, type:Int = -1) {
        
        self.name = a
        self.good = good
        
        self.ext=[:]
        let components = b.split(separator: ";")
        for component in components {
                        
            ext[component.lowercased()] = component.count
        }

        self.type=type
        self.width = w
        self.height = h
    }
}
