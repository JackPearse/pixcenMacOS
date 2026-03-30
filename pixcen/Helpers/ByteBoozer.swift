//
//  ByteBoozer.swift
//  pixcen
//
//  Swift wrapper for ByteBoozer2 C64 cruncher.
//  Calls the C++ implementation via PixcenFoundation bridge.
//

import Foundation
import PixcenFoundation

enum ByteBoozerError: Error {
    case crunchFailed
}

struct ByteBoozer {

    /// Compress data using ByteBoozer2 (C64 cruncher).
    /// The result is a self-extracting PRG that decompresses at startAddress on the C64.
    static func crunch(data: Data, startAddress: UInt16) throws -> Data {
        var outPtr: UnsafeMutablePointer<UInt8>?
        var outSize: Int = 0

        let success = data.withUnsafeBytes { sourcePtr -> Bool in
            let bound = sourcePtr.bindMemory(to: UInt8.self)
            return pixcen_b2crunch(bound.baseAddress!, data.count,
                                   &outPtr, &outSize,
                                   startAddress)
        }

        guard success, let ptr = outPtr, outSize > 0 else {
            throw ByteBoozerError.crunchFailed
        }

        let result = Data(bytes: ptr, count: outSize)
        free(ptr)
        return result
    }
}
