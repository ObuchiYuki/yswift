//
//  File.swift
//  
//
//  Created by yuki on 2023/03/25.
//

import Foundation

public protocol DSDecoder {
    var restDecoder: LZDecoder { get }

    init(_ decoder: LZDecoder) throws
    
    func resetDeleteSetValue()
    func readDeleteSetClock() throws -> Int
    func readDeleteSetLen() throws -> Int
}

extension DSDecoder {
    public init(_ update: YUpdate) throws { try self.init(update.data) }
    public init(_ data: Data) throws { try self.init(LZDecoder(data)) }
}

public class DSDecoderV1 {
    public let restDecoder: LZDecoder

    required public init(_ decoder: LZDecoder) { self.restDecoder = decoder }
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

    required public init(_ decoder: LZDecoder) throws { self.restDecoder = decoder }
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
