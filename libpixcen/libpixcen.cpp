//
//  libpixcen.cpp
//  libpixcen
//
//  Created by Jack Pearse on 05.08.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//

#include "libpixcen.h"
#include "C64Col.h"
#include "C64Interface.h"
#include "MCBitmap.cpp"

void MCBitmap_init(pcHandle_t* handle) {
    
    if (handle != nil) {
            
        MCBitmap *instance = new MCBitmap();
        if (instance != NULL) {
        
            handle->instance = reinterpret_cast < void* > ( new MCBitmap() );
            handle->module = mc_bitmap;
        }
    }
}

void MCBitmap_load(pcHandle_t* handle, void* bytes, unsigned long size, const char* type, int version) {
    
    switch (handle->module) {
        
        case mc_bitmap: {
            
            // get instance of bitmap class
            MCBitmap* instance = reinterpret_cast < MCBitmap* > ( handle->module );
            
            // create handle and attach buffer to handle
            nmemfile *f = new nmemfile(bytes, size, false);
                      
            // and call the instance function
            instance->Load(*f, type, version); // C64Interface::Load(f, type, version)
        } break;
            
        case none:
            break;
    }
}

/*
C64InterfaceWrapper::C64InterfaceWrapper() {
    
    MCBitmap *i = new MCBitmap();
    C64InterfaceWrapper::instance = reinterpret_cast < void* > ( i );
}

C64InterfaceWrapper::~C64InterfaceWrapper() {
    
}
*/

/*
@implementation NubiSynthAUDSPKernelAdapter {
    // C++ members need to be ivars; they would be copied on access if they were properties.
    NubiSynthAUDSPKernel  _kernel;
    BufferedInputBus _inputBus;
}

- (instancetype)init {

    if (self = [super init]) {
        
        MCBitmap *i = new MCBitmap();
        C64InterfaceWrapper::instance = reinterpret_cast < void* > ( i );
    }
    return self;
}
*/
