//
//  File.swift
//  
//
//  Created by yuki on 2023/03/25.
//

import Foundation

public protocol DSDecoder {
    var restDecoder: LZDecoder { get }

    func resetDeleteSetValue()
    func readDeleteSetClock() throws -> Int
    func readDeleteSetLen() throws -> Int
}

public class DSDecoderV1 {
    public let restDecoder: LZDecoder

    public init(_ decoder: LZDecoder) { self.restDecoder = decoder }
    public init(_ data: Data) { self.restDecoder = LZDecoder(data) }
}

extension DSDecoderV1: DSDecoder {
    public func resetDeleteSetValue() {}

    public func readDeleteSetClock() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    public func readDeleteSetLen() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }
}

public class DSDecoderV2 {
    public let restDecoder: LZDecoder
    
    private var deleteSetCurrentValue = 0

    public init(_ decoder: LZDecoder) throws { self.restDecoder = decoder }
    public init(_ data: Data) { self.restDecoder = LZDecoder(data) }
}

extension DSDecoderV2: DSDecoder {
    public func resetDeleteSetValue() { self.deleteSetCurrentValue = 0 }

    public func readDeleteSetClock() throws -> Int {
        self.deleteSetCurrentValue += try Int(self.restDecoder.readUInt())
        return self.deleteSetCurrentValue
    }

    public func readDeleteSetLen() throws -> Int {
        let diff = try Int(self.restDecoder.readUInt()) + 1
        self.deleteSetCurrentValue += diff
        return diff
    }
}
