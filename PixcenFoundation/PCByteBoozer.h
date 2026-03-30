//
//  PCByteBoozer.h
//  pixcen
//
//  C-compatible wrapper for ByteBoozer2 compression, callable from Swift.
//

#ifndef PCByteBoozer_h
#define PCByteBoozer_h

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Compress data using ByteBoozer2 (C64 cruncher).
/// Returns compressed data and size. Caller must free the returned data with free().
/// startAddress is the C64 load address (e.g. 0x1F00).
/// Returns true on success, false on failure.
bool pixcen_b2crunch(const uint8_t *sourceData, size_t sourceSize,
                     uint8_t **outData, size_t *outSize,
                     uint16_t startAddress);

#ifdef __cplusplus
}
#endif

#endif /* PCByteBoozer_h */
