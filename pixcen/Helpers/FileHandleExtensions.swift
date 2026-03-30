//
//  FileHandleExtensions.swift
//  pixcen
//
//  Created by Jack Pearse on 25.01.21.
//

import Foundation
extension FileHandle {
    
    func readLittleEndian<T>() -> T?
        where T: FixedWidthInteger
    {
        let data = readData(ofLength: MemoryLayout<T>.size)
        if data.count < MemoryLayout<T>.size {
            return nil
        }
        var value: T = 0
        _ = withUnsafeMutableBytes(of: &value) {bufPtr in
            data.copyBytes(to: bufPtr)
        }
        return T(littleEndian: value)
    }
    
    func readString(ofSize size: Int, encoding: String.Encoding = .isoLatin1) -> String? {
        let strData = readData(ofLength: size)
        if strData.count == size {
            return String(data: strData, encoding: encoding)
        } else {
            return nil
        }
    }
    
    func readPascalString(encoding: String.Encoding = .isoLatin1) -> String? {
        
        if let len: UInt8 = readLittleEndian() {
            return readString(ofSize: Int(len), encoding: encoding)
        } else {
            return nil
        }
    }
}

//And use it like this:
/*
// char
if let ch: UInt8 = fileHandle?.readLittleEndian() {
    var id = Character(UnicodeScalar(ch))
    //...
}
// UInt16
if let num: UInt16 = fileHandle?.readLittleEndian() {
    //Use num here...
    print(String(format: "%04X", num))
    //..
}
*/
