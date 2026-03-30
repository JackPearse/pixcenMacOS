//
//  C64Codecs.swift
//  pixcen
//
//  Swift wrappers for C64 RLE compression codecs.
//  Calls the original C++ implementations via PixcenFoundation bridge.
//

import Foundation
import PixcenFoundation

enum C64CodecError: Error {
    case decompressionFailed
    case compressionFailed
}

struct C64Codecs {

    /// Decompress Koala RLE stream (used by .gg and .jj formats)
    static func decompressKoala(stream: Data, outputSize: Int) throws -> Data {
        var buffer = Data(count: outputSize)
        let result = stream.withUnsafeBytes { streamPtr -> Int32 in
            buffer.withUnsafeMutableBytes { bufPtr -> Int32 in
                return Int32(pixcen_decompress_koala(
                    streamPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(stream.count),
                    bufPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(outputSize)
                ))
            }
        }
        guard result == outputSize else { throw C64CodecError.decompressionFailed }
        return buffer
    }

    /// Compress to Koala RLE stream
    static func compressKoala(data: Data) throws -> Data {
        let maxOutput = data.count * 3
        var buffer = Data(count: maxOutput)
        let result = data.withUnsafeBytes { streamPtr -> Int32 in
            buffer.withUnsafeMutableBytes { bufPtr -> Int32 in
                return Int32(pixcen_compress_koala(
                    streamPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(data.count),
                    bufPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(maxOutput)
                ))
            }
        }
        guard result > 0 else { throw C64CodecError.compressionFailed }
        return buffer.prefix(Int(result))
    }

    /// Decompress Zoomatic RLE stream
    static func decompressZoomatic(stream: Data, outputSize: Int) throws -> Data {
        var buffer = Data(count: outputSize)
        let result = stream.withUnsafeBytes { streamPtr -> Int32 in
            buffer.withUnsafeMutableBytes { bufPtr -> Int32 in
                return Int32(pixcen_decompress_zoomatic(
                    streamPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(stream.count),
                    bufPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(outputSize)
                ))
            }
        }
        guard result == outputSize else { throw C64CodecError.decompressionFailed }
        return buffer
    }

    /// Compress to Zoomatic RLE stream
    static func compressZoomatic(data: Data) throws -> Data {
        let maxOutput = data.count * 3
        var buffer = Data(count: maxOutput)
        let result = data.withUnsafeBytes { streamPtr -> Int32 in
            buffer.withUnsafeMutableBytes { bufPtr -> Int32 in
                return Int32(pixcen_compress_zoomatic(
                    streamPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(data.count),
                    bufPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(maxOutput)
                ))
            }
        }
        guard result > 0 else { throw C64CodecError.compressionFailed }
        return buffer.prefix(Int(result))
    }

    /// Decompress Amica stream
    static func decompressAmica(stream: Data, outputSize: Int) throws -> Data {
        var buffer = Data(count: outputSize)
        let result = stream.withUnsafeBytes { streamPtr -> Int32 in
            buffer.withUnsafeMutableBytes { bufPtr -> Int32 in
                return Int32(pixcen_decompress_amica(
                    streamPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(stream.count),
                    bufPtr.bindMemory(to: UInt8.self).baseAddress!,
                    Int32(outputSize)
                ))
            }
        }
        guard result >= 0 else { throw C64CodecError.decompressionFailed }
        return buffer.prefix(Int(result))
    }
}
