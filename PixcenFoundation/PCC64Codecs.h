//
//  PCC64Codecs.h
//  pixcen
//
//  C-compatible wrappers for C64 RLE compression codecs.
//  Bridges the original C++ MCBitmap codec implementations to Swift.
//

#ifndef PCC64Codecs_h
#define PCC64Codecs_h

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Decompress Koala RLE stream. Returns decompressed size, or -1 on error.
int pixcen_decompress_koala(const uint8_t *stream, int streamSize,
                            uint8_t *buffer, int bufferSize);

/// Compress to Koala RLE stream. Returns compressed size, or -1 on error.
int pixcen_compress_koala(const uint8_t *stream, int streamSize,
                          uint8_t *buffer, int bufferSize);

/// Decompress Zoomatic RLE stream. Returns decompressed size, or -1 on error.
int pixcen_decompress_zoomatic(const uint8_t *stream, int streamSize,
                               uint8_t *buffer, int bufferSize);

/// Compress to Zoomatic RLE stream. Returns compressed size, or -1 on error.
int pixcen_compress_zoomatic(const uint8_t *stream, int streamSize,
                             uint8_t *buffer, int bufferSize);

/// Decompress Amica stream. Returns decompressed size, or -1 on error.
int pixcen_decompress_amica(const uint8_t *stream, int streamSize,
                            uint8_t *buffer, int bufferSize);

#ifdef __cplusplus
}
#endif

#endif /* PCC64Codecs_h */
