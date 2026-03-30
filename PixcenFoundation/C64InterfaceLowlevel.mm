//
//  C64InterfaceLowlevel.m
//  PixcenFoundation
//
//  Created by Jack Pearse on 20.11.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//

#import "C64InterfaceLowlevel.hpp"
#include "libpixcen.h"
@interface C64InterfaceLowlevel (internal)
    
    
@end

@implementation C64InterfaceLowlevel

/*
// A custom designated initializer for an UIView subclass.
- (id)init {
    
    // Initialize the superclass first.
    //
    // Make sure initialization was successful by making sure
    // an instance was returned. If initialization fails, e.g.
    // because we run out of memory, the returned value would
    // be nil.
    if (self = [super init]) {
    
    
        MCBitmap_init(&cppInstance);
        //NSLog(@"self.cppInstance: %@", cppInstance.instance);
    }
    return self;
}
 */

-(NSString*) _loadKoala:(NSData*)file version:(int)version {
    
    char* bytes = (char*)[file bytes];
    NSUInteger size = [file length];
    if (size != 10003) {
        
        return @"Invalid koala file size";
    }

    //file >> addr;
    unsigned short* addrp = (unsigned short*)bytes;
    unsigned short addr = *addrp;
    bytes += sizeof(unsigned short);
    
    memcpy(self.vm.map, bytes, 8000);    // file.read(vm.map, 8000);
    bytes += 8000;
    memcpy(self.vm.screen, bytes, 1000); // file.read(vm.screen, 1000);
    bytes += 1000;
    memcpy(self.vm.color, bytes, 1000);  // file.read(vm.color, 1000);
    bytes += 1000;
    memcpy(self.vm.background, bytes, 1);// file.read(vm.background, 1);
    bytes += 1;
    
    //Clean up masks
    *self.vm.background &= 0x0f;
    for(int r=0;r<1000;r++)
    self.vm.color[r] &= 0x0f;
    
    // Success
    return nil;
}

/*
-(void) MCBitmap_Load:(NSData*)file type:(NSString*)type version:(int)version {
    
        //__super::Load(file,type,version);
        
        else if(lstrcmpi(_T("gg"),type)==0)
        {
            BYTE buffer[10001];    //Decompress will skip PRG header
            if(DecompressKoalaStream(((BYTE *)file)+2, int(file.len()-2), buffer, 10001)!=10001)
            {
                throw _T("Invalid Koala stream");
            }

            memcpy(map, buffer, 8000);
            memcpy(screen, buffer+8000, 1000);
            memcpy(color, buffer+9000, 1000);

            *background = buffer[10000]&0x0f;

            //Clean up masks
            for(int r=0;r<1000;r++)
                color[r] &= 0x0f;

            *border = GuessBorderColor();
        }
        else if (lstrcmpi(_T("ami"), type) == 0)
        {
            BYTE buffer[20000];    //Decompress will skip PRG header
            if (DecompressAmicaStream(((BYTE *)file) + 2, int(file.len() - 2), buffer, 20000) < 0)
            {
                throw _T("Invalid Amica stream");
            }

            memcpy(map, buffer, 8000);
            memcpy(screen, buffer + 8000, 1000);
            memcpy(color, buffer + 9000, 1000);

            *background = buffer[10000] & 0x0f;

            //Clean up masks
            for (int r = 0; r<1000; r++)
                color[r] &= 0x0f;

            *border = GuessBorderColor();
        }
        else if (lstrcmpi(_T("zom"), type) == 0)
        {
            BYTE buffer[10001];    //Decompress will skip PRG header
            if (DecompressZoomaticStream(((BYTE *)file) + 2, int(file.len() - 2), buffer, 10001) != 10001)
            {
                throw _T("Invalid Zoomatic stream");
            }

            memcpy(map, buffer, 8000);
            memcpy(screen, buffer + 8000, 1000);
            memcpy(color, buffer + 9000, 1000);

            *background = buffer[10000] & 0x0f;
            *border = buffer[10000] >> 4;

            //Clean up masks
            for (int r = 0; r<1000; r++)
                color[r] &= 0x0f;

        }
        else if(lstrcmpi(_T("cen"),type)==0)
        {
            if(file.len() != 10051)
            {
                throw _T("Invalid cenimate file size");
            }

            unsigned short addr;
            file >> addr;

            file.read(color, 1000);
            file.read(24);
            file.read(screen, 1000);
            file.read(24);
            file.read(map, 8000);
            file.read(background, 1);

            //Clean up masks
            *background &= 0x0f;
            for(int r=0;r<1000;r++)
                color[r] &= 0x0f;

            *border = GuessBorderColor();

        }
        else if (lstrcmpi(_T("mg"), type) == 0)
        {
            if (file.len() != 11266)
            {
                throw _T("Invalid Magic Formel file size");
            }

            unsigned short addr;
            file >> addr;

            file.read(map, 8000);
            file.read(175);
            file.read(background, 1);
            file.read(16);
            file.read(screen, 1000);
            file.read(24);
            file.read(color, 1000);
            file.read(24);

            //Clean up masks
            *background &= 0x0f;
            for (int r = 0; r<1000; r++)
                color[r] &= 0x0f;

            *border = GuessBorderColor();

        }
        else if(lstrcmpi(_T("ocp"),type)==0)
        {
            if(file.len() != 10018)
            {
                throw _T("Invalid Advanced Art Studio file size");
            }

            unsigned short addr;
            file >> addr;

            file.read(map, 8000);
            file.read(screen, 1000);

            file.read(border, 1);        //Border color
            file.read(background, 1);
            for(int r=0;r<14;r++)
                file.read(1);

            file.read(color, 1000);

            //Clean up masks
            *background &= 0x0f;
            for(int r=0;r<1000;r++)
                color[r] &= 0x0f;
        }
        else if(lstrcmpi(_T("pmg"),type)==0)
        {
            if(file.len() != 9332)
            {
                throw _T("Invalid Advanced Paint Magic file size");
            }

            unsigned short addr;
            file >> addr;
            assert(addr == 0x3f8e);

            //Skip display routine
            file.read(0x4000-0x3f8e);

            file.read(map, 8000);

            file.read(background, 1);

            //Throw 2 bytes
            file.read(2);

            //Read color
            BYTE c;
            file >> c;
            memset(color, c, 1000);

            file.read(border, 1);

            file.read(0x6000-0x5f45);
            file.read(screen, 1000);

            //Clean up masks
            *background &= 0x0f;
            for(int r=0;r<1000;r++)
                color[r] &= 0x0f;

            crippled[3] = 1;

        }
        else if (lstrcmpi(_T("binmc"), type) == 0)
        {
            if (file.len() != 88000)
            {
                throw _T("Invalid Multipaint file size");
            }

            file.read(border, 1);
            file.read(background, 1);

            // Skip to the bitmap
            file.setpos(0x0400);

            BYTE b;

            for(int y = 0; y < 200; y++)
            {
                for (int x = 0; x < 40; x++)
                {
                    int mapindex = (y / 8) * 320 + y % 8 + x * 8;
                    BYTE tmp = 0;
                    for (int bit = 7; bit >= 0; bit--)
                    {
                        file >> b;
                        tmp |= b << bit;
                    }
                    map[mapindex] = tmp;
                }
            }

            // Skip to the screen and color data
            file.setpos(0x10000);

            for (int r = 0; r < 1000; r++)
            {
                file >> b;
                screen[r] = b;
            }
            for (int r = 0; r < 1000; r++)
            {
                file >> b;
                screen[r] |= b << 4;
            }
            for (int r = 0; r < 1000; r++)
            {
                file >> b;
                color[r] |= b;
            }

        }
        else if(lstrcmpi(_T("raw"),type)==0)
        {
            size_t len = file.len();

            if(len % 8 != 0)
            {
                //Throw PRG header
                unsigned short tmp;
                file >> tmp;
                len -= 2;
            }

            xsize = 40*4;
            ysize = int(((len+319)/320)*8);

            Destroy();
            Create(ysize * (xsize/4), (xsize/4) * (ysize/8), (xsize/4) * (ysize/8));

            *background = 0;
            memset(screen,0xbc,(xsize/4) * (ysize/8));
            memset(color,0x01,(xsize/4) * (ysize/8));

            file.read(map, len);
        }
}
 */
@end
