//
//  C64Col.m
//  PixcenFoundation
//
//  Created by Jack Pearse on 05.08.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//
#import "C64Col.hpp"
#import "C64Col.h"


@implementation C64Col

+(int)closestMatch:(COLORREF)c list:(COLORREF*)list  num:(int)num {
        
    NSLog(@"ObjC, closestMatch");
    return 0;
}

+(int)setPalette:(int)n {
    
    return SetPalette(n);
}

+(int)getPalette {
    
    return GetPalette();
}

+(LPCTSTR)getPaletteName:(int) n {
    
    return GetPaletteName(n);
}

+(size_t)paletteCount {
                
    return GetPaletteCount();
}

+(COLORREF)colorref:(int) n {
    
    return g_Vic2[n];
}

+(COLORREF)colorref:(COLORREF)c addR:(int)r G:(int)g B:(int)b {
    
    if (r>0xff) {
        
        r = 0xff;
    } else if (r<-0xff) {
        
        r = -0xff;
    }
    
    if (g>0xff) {
        
        g = 0xff;
    } else if (g<-0xff) {
        
        g = -0xff;
    }
    
    if (b>0xff) {
        
        b = 0xff;
    } else if (b<-0xff) {
        
        b = -0xff;
    }
    
    BYTE *bd=(BYTE *)&c;
    int nb = bd[3] + b;
    int ng = bd[2] + g;
    int nr = bd[1] + r;
    if (nb > 0xff) {
        
        bd[3] = 0xff;
    } else if (nb < 0) {
        
        bd[3] = 0;
    } else {
        
        bd[3] = (BYTE) b;
    }
    if (ng > 0xff) {
        
        bd[2] = 0xff;
    } else if (ng < 0) {
        
        bd[2] = 0;
    } else {
        
        bd[2] = (BYTE) g;
    }
    if (nr > 0xff) {
        
        bd[1] = 0xff;
    } else if (nr < 0) {
        
        bd[1] = 0;
    } else {
        
        bd[1] = (BYTE) r;
    }
    
    return c;
}

/**
 increases each color component by 'delta'. If delta would exceed 0xff,
 the value is being decreased. delta must be positive.
 */
+(COLORREF)colorref:(COLORREF)c modifyBy:(BYTE)delta {
    
    BYTE *bd=(BYTE *)&c;
    BYTE threshold = 0xff-delta;
    for(int x=3;x>=1;x--)
    {
        if(bd[x]>=threshold)bd[x]-=delta;
        else bd[x]+=delta;
    }
    return c;
}

+(NSColor*)color:(int) n {
    
    /*
    #define RGB2REF(x)  (((x&0xff0000) >> 16) | (x & 0x00ff00) | ((x&0x0000ff) << 16))
    
    #define REF2R(x) ((x) & 0xff)
    #define REF2G(x) (((x) & 0xff00) >> 8)
    #define REF2B(x) ((x) >> 16)
    */
    COLORREF color = g_Vic2[n];
    unsigned char r = REF2R(color);
    unsigned char g = REF2G(color);
    unsigned char b = REF2B(color);
    NSColor* result = [NSColor colorWithRed:((CGFloat)r)/255.0 green:((CGFloat)g)/255.0 blue:((CGFloat)b)/255.0 alpha:1.0];
    return result;
}

+(COLORREF)rgb2ref:(unsigned int) rgb {
    
    return RGB2REF(rgb);
}

@end
