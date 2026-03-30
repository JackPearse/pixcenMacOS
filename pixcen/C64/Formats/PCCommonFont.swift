//
//  CommonFont.swift
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
//  If you need a process synchronized var, consider using this MVar approach:
//  https://github.com/typelift/Concurrent/blob/master/Sources/Concurrent/MVar.swift

import Foundation

/// Base class for SFont and MCFont, providing character counting and font display mode.
class PCCommonFont: PCC64Interface {

    enum FontDisplay: Int {
        case FONT_1X1 = 0
        case FONT_1X2 = 1
        case FONT_2X1 = 2
        case FONT_2X2 = 3
    }

    var fontdisplay: FontDisplay = .FONT_1X1
    var charcount: Int = 0

    /// Windows version: GetCharCount
    override var charCount: Int {
        get {
            return charcount
        }
    }

    /// Translate cell coordinates based on font display mode.
    /// In FONT_1X1 mode this is a no-op; other modes remap for grouped display.
    func translateFontDisplay(_ cx: inout Int, _ cy: inout Int) {
        switch fontdisplay {
        case .FONT_1X1:
            break
        case .FONT_1X2:
            let c = cx + (cy / 2) * getCellCountX()
            cx = (c & 63) + (c / 64) * 128 + (cy & 1) * 64
            cy = 0
        case .FONT_2X1:
            let c = (cx / 2) + cy * getCellCountX() / 2
            cx = (c & 63) + (c / 64) * 128 + (cx & 1) * 64
            cy = 0
        case .FONT_2X2:
            let c = (cx / 2) + (cy / 2) * getCellCountX() / 2
            cx = c + (cx & 1) * 64 + (cy & 1) * 128
            cy = 0
        }
    }
}
