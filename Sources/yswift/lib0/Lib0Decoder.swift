//
//  Decoder.swift
//  lib0-swift
//
//  Created by yuki on 2023/03/09.
//

import Foundation

public enum Lib0DecoderError: String, LocalizedError {
    case integerOverflow = "Integer overflow."
    case unexpectedEndOfArray = "Unexpected End of Array."
    case unkownStringEncodingType = "Unkown string encoding type."
    case useOfBigintType = "Swift has no bigint type."
    case typeMissmatch = "Type missmatch."
}

public final class Lib0Decoder {

    private let data: Data
    private var position: Int = 0
    
    public init(data: Data) { self.data = data }
    
    public var hasContent: Bool {
        return self.position != data.count
    }
    
    public func readData(count: Int) -> Data {
        defer { position += count }
        return data[position..<position+count]
    }
    public func readVarData() throws -> Data {
        let count = try Int(self.readUInt())
        return self.readData(count: count)
    }
    
    public func readUInt8() -> UInt8 {
        defer { self.position += 1 }
        return self.data[self.position]
    }
    
    public func readUInt() throws -> UInt {
        var num: UInt = 0
        var mult: UInt = 1
        let len = self.data.count
        while self.position < len {
            let r = UInt(self.data[self.position])
            self.position += 1
            
            let (pnum, overflow) = num.addingReportingOverflow((r & 0b0111_1111) * mult)
            if overflow {
                throw Lib0DecoderError.integerOverflow
            }
            num = pnum
            mult *= 128
            if (r < 0b1000_0000) { return num }
        }
        throw Lib0DecoderError.unexpectedEndOfArray
    }

    public func readInt() throws -> Int {
        var r = Int(self.data[self.position])
        self.position += 1
        var num = r & 0b0011_1111
        var mult = 64
        let sign = (r & 0b0100_0000) > 0 ? -1 : 1
        if (r & 0b1000_0000) == 0 { return sign * num }
        let len = self.data.count
        
        while self.position < len {
            r = Int(self.data[self.position])
            self.position += 1
            let (pnum, overflow) = num.addingReportingOverflow((r & 0b0111_1111) * mult)
            if overflow { throw Lib0DecoderError.integerOverflow }
            num = pnum
            mult *= 128
            if (r < 0b1000_0000) { return sign * num }
        }
        throw Lib0DecoderError.unexpectedEndOfArray
    }
    
    public func readString() throws -> String {
        let data = try self.readVarData()
        guard let string = String(data: data, encoding: .utf8) else {
            throw Lib0DecoderError.unkownStringEncodingType
        }
        return string
    }

    public func readFloat() -> Float {
        let bigEndianValue = readData(count: 4).reversed().withUnsafeBytes{ ptr in
            ptr.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        }
        return Float(bitPattern: bigEndianValue)
    }
    
    public func readDouble() -> Double {
        let bigEndianValue = readData(count: 8).reversed().withUnsafeBytes{ ptr in
            ptr.baseAddress!.withMemoryRebound(to: UInt64.self, capacity: 1) { $0.pointee }
        }
        
        return Double(bitPattern: bigEndianValue)
    }
        
    public func readAny() throws -> Any {
        let type = self.readUInt8()
        
        switch type {
        case 125: return try self.readInt()
        case 124: return self.readFloat()
        case 123: return self.readDouble()
        case 122: throw Lib0DecoderError.useOfBigintType
        case 121: return false
        case 120: return true
        case 119: return try readString()
        case 118:
            let count = try self.readUInt()
            var dictionary: [String: Any] = [:]
            for _ in 0..<count {
                let key = try self.readString()
                dictionary[key] = try self.readAny()
            }
            return dictionary
        case 117:
            let length = Int(try self.readUInt())
            var array: [Any] = []
            array.reserveCapacity(length)
            for _ in 0..<length {
                array.append(try self.readAny())
            }
            return array
        default: return Optional<Void>.none as Any
        }
    }
}

public class Lib0RleDecoder {
    private let decoder: Lib0Decoder
    private var state: UInt8? = nil
    private var count = 0

    public init(data: Data) {
        self.decoder = Lib0Decoder(data: data)
        self.state = nil
        self.count = 0
    }

    public func read() throws -> UInt8 {
        if self.count == 0 {
            self.state = self.decoder.readUInt8()
            if self.decoder.hasContent {
                self.count = Int(try self.decoder.readUInt()) + 1
            } else {
                self.count = -1
            }
        }
        self.count -= 1
        return self.state!
    }
}

public class Lib0IntDiffDecoder {
    private let decoder: Lib0Decoder
    private var state: Int

    public init(data: Data, start: Int) {
        self.decoder = Lib0Decoder(data: data)
        self.state = start
    }

    public func read() throws -> Int {
        self.state += try self.decoder.readInt()
        return self.state
    }
}

public class Lib0RleIntDiffDecoder {
    private let decoder: Lib0Decoder
    private var state: Int
    private var count: Int = 0
    
    public init(data: Data, start: Int) {
        self.decoder = Lib0Decoder(data: data)
        self.state = start
    }

    public func read() throws -> Int {
        if self.count == 0 {
            self.state += try self.decoder.readInt()
            if self.decoder.hasContent {
                self.count = Int(try self.decoder.readUInt() + 1)
            } else {
                self.count = -1
            }
        }
        self.count -= 1
        return self.state
    }
}

public class Lib0UintOptRleDecoder {
    private let decoder: Lib0Decoder
    private var state = 0
    private var count: UInt = 0

    public init(data: Data) {
        self.decoder = Lib0Decoder(data: data)
    }

    public func read() throws -> UInt {
        if self.count == 0 {
            self.state = try self.decoder.readInt()
            self.count = 1
            if self.state < 0 {
                self.state = -self.state
                self.count = try self.decoder.readUInt() + 2
            }
        }
        self.count -= 1
        return UInt(self.state)
    }
    
    public func readString() throws -> String {
        return try self.decoder.readString()
    }
}

public class Lib0IncUintOptRleDecoder {
    private let decoder: Lib0Decoder
    private var state = 0
    private var count: UInt = 0

    public init(data: Data) {
        self.decoder = Lib0Decoder(data: data)
    }

    public func read() throws -> UInt {
        if self.count == 0 {
            self.state = try self.decoder.readInt()
            self.count = 1
            if self.state < 0 {
                self.state = -self.state
                self.count = try self.decoder.readUInt() + 2
            }
        }
        self.count -= 1
        defer { self.state += 1 }
        return UInt(self.state)
    }
}

public class Lib0IntDiffOptRleDecoder {
    private let decoder: Lib0Decoder
    private var state = 0
    private var count: UInt = 0
    private var diff = 0

    public init(data: Data) {
        self.decoder = Lib0Decoder(data: data)
    }

    public func read() throws -> Int {
        if self.count == 0 {
            let diff = try self.decoder.readInt()
            self.diff = diff >> 1
            self.count = 1
            if diff & 1 != 0 {
                self.count = try self.decoder.readUInt() + 2
            }
        }
        self.state += self.diff
        self.count -= 1
        return self.state
    }
}

public class Lib0StringDecoder {
    private let decoder: Lib0UintOptRleDecoder
    private var str: String
    private var spos: UInt = 0

    public init(data: Data) throws {
        self.decoder = Lib0UintOptRleDecoder(data: data)
        self.str = try self.decoder.readString()
    }

    public func read() throws -> String {
        let end = try self.spos + self.decoder.read()
        
        // TODO: Swift should not be use String subscript.
        let res = String(self.str[
            self.str.index(self.str.startIndex, offsetBy: Int(self.spos))
            ..<
            self.str.index(self.str.startIndex, offsetBy: Int(end))
        ])
        self.spos = end
        return res
    }
}
