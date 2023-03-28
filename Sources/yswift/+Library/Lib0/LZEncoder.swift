//
//  LZEncoder.swift
//  lib0-swift
//
//  Created by yuki on 2023/03/09.
//

import Foundation

public final class LZEncoder {
    private var buffers: [Data] = []
    private var currentBuffer = Data(repeating: 0, count: 100)
    private var currentBufferPosition = 0
    
    public init() {}

    public var count: Int {
        self.currentBufferPosition + self.buffers.lazy.map{ $0.count }.reduce(0, +)
    }

    public var data: Data {
        var data = Data()
        data.reserveCapacity(count)
        for buffer in buffers { data.append(buffer) }
        data.append(self.currentBuffer[..<self.currentBufferPosition])
        return data
    }

    public func reserveCapacity(_ minimumCapacity: Int) {
        let bufferSize = self.currentBuffer.count
        if bufferSize - self.currentBufferPosition < minimumCapacity {
            self.buffers.append(
                self.currentBuffer[..<self.currentBufferPosition]
            )
            self.currentBuffer = Data(repeating: 0, count: max(bufferSize, minimumCapacity) * 2)
            self.currentBufferPosition = 0
        }
    }

    public func writeUInt8(_ value: UInt8) {
        let bufferSize = self.currentBuffer.count
        if self.currentBufferPosition == bufferSize {
            self.buffers.append(self.currentBuffer)
            self.currentBuffer = Data(repeating: 0, count: bufferSize * 2)
            self.currentBufferPosition = 0
        }
        self.currentBuffer[self.currentBufferPosition] = value
        self.currentBufferPosition += 1
    }

    public func writeUInt(_ value: UInt) {
        var value = value
        while (value > 0b0111_1111) {
            self.writeUInt8(0b1000_0000 | UInt8(0b0111_1111 & value))
            value >>= 7
        }
        self.writeUInt8(UInt8(0b0111_1111 & value))
    }
    
    public func writeInt(_ value: Int, zeroIsNegative: Bool = false) {
        var value = value
        let isNegative = (value == 0 && zeroIsNegative) ? true : value < 0
        if (isNegative) { value = -value }
        
        self.writeUInt8(
            UInt8(value > 0b0011_1111 ? 0b1000_0000 : 0) | // whether to continue reading (8th bit)
            UInt8(isNegative ? 0b0100_0000 : 0) |          // whether is negative (7th bit)
            UInt8(0b0011_1111 & value)                     // number (bottom 6bits)
        )
        value >>= 6
        while (value > 0) {
            self.writeUInt8(
                UInt8(value > 0b0111_1111 ? 0b1000_0000 : 0) | // whether to continue reading (8th bit)
                UInt8(0b0111_1111 & value) // number (bottom 7bits)
            )
            value >>= 7
        }
    }

    public func writeString(_ value: String) {
        self.writeData(value.data(using: .utf8)!)
    }

    public func writeData(_ data: Data) {
        self.writeUInt(UInt(data.count))
        self.writeOpaqueSizeData(data)
    }
    public func writeOpaqueSizeData(_ data: Data) {
        let bufferLen = self.currentBuffer.count
        let cpos = self.currentBufferPosition
        let leftCopyLen = min(bufferLen - cpos, data.count)
        let rightCopyLen = data.count - leftCopyLen
        
        let subdata = data[0..<leftCopyLen]
        self.currentBuffer[cpos..<cpos+subdata.count] = subdata
        self.currentBufferPosition += leftCopyLen

        if rightCopyLen > 0 {
            self.buffers.append(self.currentBuffer)
            self.currentBuffer = Data(repeating: 0, count: max(bufferLen * 2, rightCopyLen))
            let subdata = data[leftCopyLen...]
            self.currentBuffer[0..<subdata.count] = subdata
            self.currentBufferPosition = rightCopyLen
        }
    }
    
    public func writeFloat(_ value: Float) {
        let value = value.bitPattern
        for i in (0..<4).reversed() {
            self.writeUInt8(UInt8((value >> (8 * i)) & 0b1111_1111))
        }
    }
    public func writeDouble(_ value: Double) {
        let value = value.bitPattern
        for i in (0..<8).reversed() {
            self.writeUInt8(UInt8((value >> (8 * i)) & 0b1111_1111))
        }
    }

    public func writeAny(_ data: Any?) {
        if data == nil || data is NSNull { // null
            self.writeUInt8(126)
            return
        }
        switch (data) {
        case let data as String:
            self.writeUInt8(119)
            self.writeString(data)
        case let data as Int:
            self.writeUInt8(125)
            self.writeInt(data)
        case let data as Float:
            self.writeUInt8(124)
            self.writeFloat(data)
        case let data as Double:
            self.writeUInt8(123)
            self.writeDouble(data)
        case let data as [String: Any]:
            self.writeUInt8(118)
            self.writeUInt(UInt(data.count))
            for (key, value) in data {
                self.writeString(key)
                self.writeAny(value)
            }
        case let data as Data:
            self.writeUInt8(116)
            self.writeData(data)
            
        case let data as [Any]:
            self.writeUInt8(117)
            self.writeUInt(UInt(data.count))
            for element in data {
                self.writeAny(element)
            }
        case let data as Bool:
            self.writeUInt8(data ? 120 : 121)
        default: // undefined
            assertionFailure("undefined object to code \(data ?? "nil")")
            self.writeUInt8(127)
        }
    }
}

public class LZRleEncoder {
    private let encoder = LZEncoder()
    private var state: UInt8? = nil
    private var count: UInt = 0

    public init() {}
    
    public var data: Data { encoder.data }

    public func write(_ value: UInt8) {
        if self.state == value as UInt8? {
            self.count += 1
        } else {
            if self.count > 0 {
                self.encoder.writeUInt(self.count - 1)
            }
            self.count = 1
            self.encoder.writeUInt8(value)
            self.state = value
        }
    }
}

public class LZIntDiffEncoder {
    private let encoder = LZEncoder()
    private var state: Int

    public var data: Data { encoder.data }
    
    public init(start: Int) {
        self.state = start
    }

    public func write(_ value: Int) {
        self.encoder.writeInt(value - self.state)
        self.state = value
    }
}

public class LZRleIntDiffEncoder {
    private let encoder = LZEncoder()
    private var state: Int
    private var count: UInt
    
    public var data: Data { encoder.data }
    
    public init(start: Int) {
        self.state = start
        self.count = 0
    }

    public func write(_ value: Int) {
        if self.state == value && self.count > 0 {
            self.count += 1
        } else {
            if self.count > 0 {
                self.encoder.writeUInt(self.count - 1)
            }
            self.count = 1
            self.encoder.writeInt(state - self.state)
            self.state = value
        }
    }
}

private protocol LZUIntOptRleEncoderType {
    var count: UInt { get }
    var state: UInt { get }
    var encoder: LZEncoder { get }
}

extension LZUIntOptRleEncoderType {
    func flush() {
        if self.count > 0 {
            if self.count == 1 {
                self.encoder.writeInt(Int(self.state))
            } else {
                self.encoder.writeInt(-Int(self.state), zeroIsNegative: true)
            }
            if self.count > 1 {
                self.encoder.writeUInt(self.count - 2)
            }
        }
    }
}

public class LZUintOptRleEncoder: LZUIntOptRleEncoderType {
    fileprivate var encoder = LZEncoder()
    fileprivate var state: UInt = 0
    fileprivate var count: UInt = 0
    fileprivate var mutated = false

    public init() {}

    public func write(_ value: UInt) {
        self.mutated = true
        if self.state == value {
            self.count += 1
        } else {
            self.flush()
            self.count = 1
            self.state = value
        }
    }

    public var data: Data {
        if self.mutated {
            self.flush()
            self.mutated = false
        }
        return self.encoder.data
    }
}

public class LZIncUintOptRleEncoder: LZUIntOptRleEncoderType {
    fileprivate let encoder = LZEncoder()
    fileprivate var state: UInt = 0
    fileprivate var count: UInt = 0
    
    public init() {}

    public func write(_ value: UInt) {
        if self.state + self.count == value {
            self.count += 1
        } else {
            self.flush()
            self.count = 1
            self.state = value
        }
    }

    public var data: Data {
        self.flush()
        return self.encoder.data
    }
}

public class LZIntDiffOptRleEncoder {
    let encoder = LZEncoder()
    var state = 0
    var count: UInt = 0
    var diff = 0

    public init() {}

    public func write(_ value: Int) {
        if self.diff == value - self.state {
            self.state = value
            self.count += 1
        } else {
            self.flush()
            self.count = 1
            self.diff = value - self.state
            self.state = value
        }
    }
    
    private func flush() {
        if self.count > 0 {
            let encodedDiff = self.diff * 2 + (self.count == 1 ? 0 : 1)
            self.encoder.writeInt(encodedDiff)
            if self.count > 1 {
                self.encoder.writeUInt(self.count - 2)
            }
        }
    }

    public var data: Data {
        self.flush()
        return self.encoder.data
    }
}

public class LZStringEncoder {
    private var sarr: [NSString] = []
    private var s = NSMutableString()
    private var lensE = LZUintOptRleEncoder()

    public init() {}

    public func write(_ string: String) {
        let nsstring = string as NSString
        self.s.append(string)
        if self.s.length > 19 {
            self.sarr.append(self.s)
            self.s = NSMutableString()
        }
        self.lensE.write(UInt(nsstring.length))
    }

    public var data: Data {
        let encoder = LZEncoder()
        self.sarr.append(self.s)
        self.s = NSMutableString()
                
        encoder.writeString(self.sarr.joined() as String)
        encoder.writeOpaqueSizeData(self.lensE.data)
        return encoder.data
    }
}

extension Array where Element == NSString {
    fileprivate func joined() -> NSString {
        let base = NSMutableString()
        for str in self {
            base.append(str as String)
        }
        return base
    }
}
