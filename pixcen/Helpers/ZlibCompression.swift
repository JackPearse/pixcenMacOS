//
//  ZlibCompression.swift
//  pixcen
//
//  Zlib compression/decompression using system libz.
//  Compatible with miniz compress2/uncompress used by original Windows pixcen.
//  Works on macOS and iOS (both ship with libz).
//

import Foundation
import zlib

enum ZlibError: Error {
    case compressionFailed(Int32)
    case decompressionFailed(Int32)
}

struct ZlibCompression {

    /// Compress data using zlib (identical to miniz compress2 with Z_BEST_COMPRESSION).
    static func compress(_ data: Data) throws -> Data {
        var destLen = uLongf(compressBound(uLong(data.count)))
        var dest = Data(count: Int(destLen))

        let result = data.withUnsafeBytes { sourcePtr -> Int32 in
            dest.withUnsafeMutableBytes { destPtr -> Int32 in
                return zlib.compress2(
                    destPtr.bindMemory(to: UInt8.self).baseAddress!,
                    &destLen,
                    sourcePtr.bindMemory(to: UInt8.self).baseAddress!,
                    uLong(data.count),
                    Z_BEST_COMPRESSION
                )
            }
        }

        guard result == Z_OK else {
            throw ZlibError.compressionFailed(result)
        }

        return dest.prefix(Int(destLen))
    }

    /// Decompress zlib data (identical to miniz uncompress).
    static func decompress(_ data: Data, maxSize: Int) throws -> Data {
        var destLen = uLongf(maxSize)
        var dest = Data(count: maxSize)

        let result = data.withUnsafeBytes { sourcePtr -> Int32 in
            dest.withUnsafeMutableBytes { destPtr -> Int32 in
                return zlib.uncompress(
                    destPtr.bindMemory(to: UInt8.self).baseAddress!,
                    &destLen,
                    sourcePtr.bindMemory(to: UInt8.self).baseAddress!,
                    uLong(data.count)
                )
            }
        }

        guard result == Z_OK else {
            throw ZlibError.decompressionFailed(result)
        }

        return dest.prefix(Int(destLen))
    }
}
