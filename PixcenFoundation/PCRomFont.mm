/*
   Pixcen - A windows platform low level pixel editor for C64
   Copyright (C) 2013  John Hammarberg (crt@nospam.binarybone.com)
   Ported to MacOS in 2020-2026 by JackPearse (Drehwerk^Drehwerk)

    This file is part of Pixcen.

    Pixcen is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Pixcen is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Pixcen.  If not, see <http://www.gnu.org/licenses/>.
*/

#import "PCRomFont.h"

// The ROM font data is compiled into the libpixcen static library.
// We declare g_ROMFont directly here to avoid pulling in Romfont.h
// which uses the Windows typedef BYTE.
extern const unsigned char g_ROMFont[];

extern "C" {

const uint8_t *pixcen_romfont_data(void) {
    return g_ROMFont;
}

size_t pixcen_romfont_size(void) {
    return 4096;
}

}
