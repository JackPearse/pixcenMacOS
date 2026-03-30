//
//  DataExtensions.swift
//  pixcen
//
//  Created by Jack Pearse on 25.01.21.
//

/**
 Example 1:
 MemoryLayout<Int>.size      // returns 8 on 64-bit
 MemoryLayout<Bool>.size     // returns 1
 MemoryLayout<Foo>.size      // returns 9
 MemoryLayout<Foo>.stride    // returns 16 because of alignment requirements
 MemoryLayout<Foo>.alignment // returns 8, addresses must be multiples of 8
 
 Example 2:
 let count = 50
 let ptr = UnsafeMutablePointer<Int>.alloc(count)
 let buffer = UnsafeMutableBufferPointer(start: ptr, count: count)
 for (i, _) in buffer.enumerate() {
     buffer[i] = Int(arc4random())
 }

 // Do stuff...

 ptr.dealloc(count)   // Don't forget to dealloc!
 */

import Foundation

extension Data {
    
    mutating func read(_ ptr:UnsafeMutablePointer<UInt8>?, _ size:Int) {
        
        if let buf = ptr {
            
            self.copyBytes(to: buf, from: 0..<size)
            if self.count > size {
            
                self = self.advanced(by: size)
            }
        }
    }
    
    public static func >> (lval: inout Data, rval: inout UInt32) {
                
        // Read value from Data
        let size = MemoryLayout<UInt32>.size
        let buf:UnsafeMutableBufferPointer<UInt32> = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: 1)
        lval.copyBytes(to: buf, from: 0..<size)
        
        rval = buf[0]
        lval = lval.advanced(by: size)
        buf.deallocate()
    }
    
    public static func >> (lval: inout Data, rval: inout UInt16) {

        // Read value from Data
        let size = MemoryLayout<UInt16>.size
        let buf:UnsafeMutableBufferPointer<UInt16> = UnsafeMutableBufferPointer<UInt16>.allocate(capacity: 1)
        lval.copyBytes(to: buf, from: 0..<size)

        rval = buf[0]
        lval = lval.advanced(by: size)
        buf.deallocate()
    }

    public static func >> (lval: inout Data, rval: inout Int32) {

        let size = MemoryLayout<Int32>.size
        let buf:UnsafeMutableBufferPointer<Int32> = UnsafeMutableBufferPointer<Int32>.allocate(capacity: 1)
        lval.copyBytes(to: buf, from: 0..<size)

        rval = buf[0]
        lval = lval.advanced(by: size)
        buf.deallocate()
    }

    // MARK: - Write helpers (for GPX save)

    /// Append a little-endian Int32 to the data.
    mutating func appendInt32(_ value: Int32) {
        var v = value
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }

    /// Append a little-endian UInt32 to the data.
    mutating func appendUInt32(_ value: UInt32) {
        var v = value
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }

    // MARK: - String read helpers

    /// Read a null-terminated ASCII string (nstrc format).
    /// Reads bytes until a 0x00 byte is found, consuming the null terminator.
    mutating func readNullTerminatedASCII() -> String {

        var bytes:[UInt8] = []
        while self.count > 0 {
            let byte = self[self.startIndex]
            self = self.advanced(by: 1)
            if byte == 0 { break }
            bytes.append(byte)
        }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    /// Read a null-terminated wide string (nstrw format, UTF-16LE).
    /// Reads 2-byte units until a 0x0000 is found, consuming the null terminator.
    mutating func readNullTerminatedUTF16LE() -> String {

        var codeUnits:[UInt16] = []
        while self.count >= 2 {
            let lo = UInt16(self[self.startIndex])
            let hi = UInt16(self[self.startIndex + 1])
            self = self.advanced(by: 2)
            let unit = lo | (hi << 8)
            if unit == 0 { break }
            codeUnits.append(unit)
        }
        return String(utf16CodeUnits: codeUnits, count: codeUnits.count)
    }
}
