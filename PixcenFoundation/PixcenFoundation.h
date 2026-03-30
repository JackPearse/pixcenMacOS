//
//  PixcenFoundation.h
//  PixcenFoundation
//
//  Created by Jack Pearse on 29.07.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//
// if compile fails, because system headers are missing, try
// (sudo) rm -rf /Library/Developer/CommandLineTools
// and reinstall it using: xcode-select --install.

#import <Foundation/Foundation.h>

//! Project version number for PixcenFoundation.
FOUNDATION_EXPORT double PixcenFoundationVersionNumber;

//! Project version string for PixcenFoundation.
FOUNDATION_EXPORT const unsigned char PixcenFoundationVersionString[];

// Public headers
#import "PCByteBoozer.h"
#import "PCC64Codecs.h"
#import "PCRomFont.h"

