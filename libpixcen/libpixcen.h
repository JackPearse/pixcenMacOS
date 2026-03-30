
//
//  Header.h
//  pixcen
//
//  Created by Jack Pearse on 04.08.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//
// You cannot import C++ code directly into Swift.
// Instead, create an Objective-C or C wrapper for C++ code.

#ifndef Header_h
#define Header_h

typedef enum _module {
    
    none = 0,
    mc_bitmap
} module_t;

typedef struct _pcHandle {
    
    void* instance;
    module_t module;
} pcHandle_t;

void MCBitmap_init(pcHandle_t* handle);
void MCBitmap_load(pcHandle_t* handle, void* bytes, unsigned long size, const char* type, int version);

/*
C64InterfaceWrapper();
    ~C64InterfaceWrapper();
    

    void* instance;
};
*/


#endif /* Header_h */


