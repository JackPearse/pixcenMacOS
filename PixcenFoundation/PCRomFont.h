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

#ifndef PCRomFont_h
#define PCRomFont_h

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Returns a pointer to the 4096-byte C64 ROM font data.
/// First 2048 bytes = uppercase, next 2048 bytes = lowercase.
const uint8_t *pixcen_romfont_data(void);

/// Returns the total size of the ROM font data (4096).
size_t pixcen_romfont_size(void);

#ifdef __cplusplus
}
#endif

#endif /* PCRomFont_h */
