//
//  C64Col.h
//  PixcenFoundation
//
//  Created by Jack Pearse on 05.08.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h> // NSColor
#import <Cocoa/Cocoa.h>
#include "platform.h"

NS_ASSUME_NONNULL_BEGIN

@interface C64Col : NSObject

+(int)closestMatch:(COLORREF)c list:(COLORREF*)list  num:(int)num;
+(COLORREF)colorref:(COLORREF)c addR:(int)r G:(int)g B:(int)b;
+(COLORREF)colorref:(COLORREF)c modifyBy:(BYTE)delta;
+(int)setPalette:(int)n;
+(int)getPalette;
+(LPCTSTR)getPaletteName:(int) n;
+(size_t)paletteCount;
+(COLORREF)colorref:(int) n;
+(NSColor*)color:(int) n;
+(COLORREF)rgb2ref:(unsigned int) rgb;

@end

NS_ASSUME_NONNULL_END
