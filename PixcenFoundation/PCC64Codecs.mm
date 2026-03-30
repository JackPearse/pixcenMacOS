//
//  PCC64Codecs.mm
//  pixcen
//
//  Bridges the original MCBitmap codec implementations to C interface.
//

#import "PCC64Codecs.h"
#include "C64Interface.h"

// The codec functions are static methods on MCBitmap in the C++ library.
// We forward to them directly.

extern "C" {

int pixcen_decompress_koala(const uint8_t *stream, int streamSize,
                            uint8_t *buffer, int bufferSize) {
    return MCBitmap::DecompressKoalaStream(stream, streamSize, buffer, bufferSize);
}

int pixcen_compress_koala(const uint8_t *stream, int streamSize,
                          uint8_t *buffer, int bufferSize) {
    return MCBitmap::CompressKoalaStream(stream, streamSize, buffer, bufferSize);
}

int pixcen_decompress_zoomatic(const uint8_t *stream, int streamSize,
                               uint8_t *buffer, int bufferSize) {
    return MCBitmap::DecompressZoomaticStream(stream, streamSize, buffer, bufferSize);
}

int pixcen_compress_zoomatic(const uint8_t *stream, int streamSize,
                             uint8_t *buffer, int bufferSize) {
    return MCBitmap::CompressZoomaticStream(stream, streamSize, buffer, bufferSize);
}

int pixcen_decompress_amica(const uint8_t *stream, int streamSize,
                            uint8_t *buffer, int bufferSize) {
    return MCBitmap::DecompressAmicaStream(stream, streamSize, buffer, bufferSize);
}

}
