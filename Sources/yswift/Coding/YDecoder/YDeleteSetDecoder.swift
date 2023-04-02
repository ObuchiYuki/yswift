//
//  File.swift
//  
//
//  Created by yuki on 2023/03/25.
//

import lib0
import Foundation

public protocol YDeleteSetDecoder {
    var restDecoder: LZDecoder { get }

    init(_ decoder: LZDecoder) throws
    
    func resetDeleteSetValue()
    func readDeleteSetClock() throws -> Int
    func readDeleteSetLen() throws -> Int
}

extension YDeleteSetDecoder {
    public init(_ update: YUpdate) throws { try self.init(update.data) }
    public init(_ data: Data) throws { try self.init(LZDecoder(data)) }
}

public class YDeleteSetDecoderV1 {
    public let restDecoder: LZDecoder

    required public init(_ decoder: LZDecoder) { self.restDecoder = decoder }
}

extension YDeleteSetDecoderV1: YDeleteSetDecoder {
    public func resetDeleteSetValue() {}

    public func readDeleteSetClock() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    public func readDeleteSetLen() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }
}

public class YDeleteSetDecoderV2 {
    public let restDecoder: LZDecoder
    
    private var deleteSetCurrentValue = 0

    required public init(_ decoder: LZDecoder) throws { self.restDecoder = decoder }
}

extension YDeleteSetDecoderV2: YDeleteSetDecoder {
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
