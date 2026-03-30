//
//  PCByteBoozer.mm
//  pixcen
//
//  Objective-C++ wrapper bridging ByteBoozer2 to C interface for Swift.
//

#import "PCByteBoozer.h"
#include "b2wrap.h"

extern "C" bool pixcen_b2crunch(const uint8_t *sourceData, size_t sourceSize,
                                 uint8_t **outData, size_t *outSize,
                                 uint16_t startAddress)
{
    B2File source;
    source.size = sourceSize;
    // B2Crunch needs a mutable buffer
    source.data = (BYTE *)malloc(sourceSize);
    if (!source.data) return false;
    memcpy(source.data, sourceData, sourceSize);

    B2File target;
    target.size = 0;
    target.data = NULL;

    bool result = B2Crunch(&source, &target, startAddress);

    free(source.data);

    if (result && target.data && target.size > 0) {
        *outData = target.data;  // caller must free()
        *outSize = target.size;
        return true;
    }

    if (target.data) free(target.data);
    *outData = NULL;
    *outSize = 0;
    return false;
}
