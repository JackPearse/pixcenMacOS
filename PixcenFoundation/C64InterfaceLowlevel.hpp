//
//  C64InterfaceLowlevel.hpp
//  PixcenFoundation
//
//  Created by Jack Pearse on 20.11.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#include "libpixcen.h"
//#include "platform.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct _viewModelLink {
    
    unsigned char* map;
    unsigned char* screen;
    unsigned char* color;
    unsigned char* background;
    unsigned char* border;
} viewModelLink;

@interface C64InterfaceLowlevel : NSObject {
    
}

@property viewModelLink vm;

/**
 Loads a koala file. Retunrs nil on success, or a string with the error description.
 */
-(NSString*) _loadKoala:(NSData*)file version:(int)version;
              

/*+(int)closestMatch:(COLORREF)c list:(COLORREF*)list  num:(int)num;
+(int)setPalette:(int)n;
+(int)getPalette;
+(LPCTSTR)getPaletteName:(int) n;
+(size_t)paletteCount;
+(COLORREF)colorref:(int) n;
+(NSColor*)color:(int) n;
+(COLORREF)rgb2ref:(unsigned int) rgb;
*/
@end

NS_ASSUME_NONNULL_END
