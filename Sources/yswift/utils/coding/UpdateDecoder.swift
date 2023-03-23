//
//  UpdateDecoder.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0

public protocol DSDecoder {
    var restDecoder: Lib0Decoder { get }

    func resetDsCurVal()
    func readDsClock() throws -> Int
    func readDsLen() throws -> Int
}

public class DSDecoderV1: DSDecoder {
    public let restDecoder: Lib0Decoder

    public init(_ decoder: Lib0Decoder) {
        self.restDecoder = decoder
    }

    public func resetDsCurVal() {}

    public func readDsClock() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    public func readDsLen() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }
}

public protocol UpdateDecoder: DSDecoder {
    func readLeftID() throws -> ID
    func readRightID() throws -> ID
    func readClient() throws -> Int
    func readInfo() throws -> UInt8
    func readString() throws -> String
    func readParentInfo() throws -> Bool
    func readTypeRef() throws -> Int
    func readLen() throws -> Int
    func readAny() throws -> Any?
    func readBuf() throws -> Data
    func readKey() throws -> String
    func readJSON() throws -> Any?
}

public class UpdateDecoderV1: DSDecoderV1, UpdateDecoder {
    public func readLeftID() throws -> ID {
        return try ID(
            client: Int(self.restDecoder.readUInt()),
            clock: Int(self.restDecoder.readUInt())
        )
    }

    public func readRightID() throws -> ID {
        return try ID(
            client: Int(self.restDecoder.readUInt()),
            clock: Int(self.restDecoder.readUInt())
        )
    }

    public func readClient() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    public func readInfo() -> UInt8 {
        return self.restDecoder.readUInt8()
    }

    public func readString() throws -> String {
        return try self.restDecoder.readString()
    }

    public func readParentInfo() throws -> Bool {
        return try self.restDecoder.readUInt() == 1
    }

    public func readTypeRef() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    /** Write len of a struct - well suited for Opt RLE encoder. */
    public func readLen() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    public func readAny() throws -> Any? {
        return try self.restDecoder.readAny()
    }

    public func readBuf() throws -> Data {
        return try self.restDecoder.readVarData()
    }

    public func readKey() throws -> String {
        return try self.restDecoder.readString()
    }
    
    public func readJSON() throws -> Any? {
        let data = try self.restDecoder.readVarData()
        return try! JSONSerialization.jsonObject(
            with: data, options: [.fragmentsAllowed]
        )
    }
}

public class DSDecoderV2: DSDecoder {
    private var dsCurrVal: Int = 0
    public let restDecoder: Lib0Decoder

    public init(_ decoder: Lib0Decoder) throws {
        self.restDecoder = decoder
    }

    public func resetDsCurVal() { self.dsCurrVal = 0 }

    public func readDsClock() throws -> Int {
        self.dsCurrVal += try Int(self.restDecoder.readUInt())
        return self.dsCurrVal
    }

    public func readDsLen() throws -> Int {
        let diff = try Int(self.restDecoder.readUInt()) + 1
        self.dsCurrVal += diff
        return diff
    }
}

public class UpdateDecoderV2: DSDecoderV2, UpdateDecoder {
    var keys: [String] = []
    
    let keyClockDecoder: Lib0IntDiffOptRleDecoder
    let clientDecoder: Lib0UintOptRleDecoder
    let leftClockDecoder: Lib0IntDiffOptRleDecoder
    let rightClockDecoder: Lib0IntDiffOptRleDecoder
    let infoDecoder: Lib0RleDecoder
    let stringDecoder: Lib0StringDecoder
    let parentInfoDecoder: Lib0RleDecoder
    let typeRefDecoder: Lib0UintOptRleDecoder
    let lenDecoder: Lib0UintOptRleDecoder

    public override init(_ decoder: Lib0Decoder) throws {
        _ = try decoder.readUInt() // read feature flag - currently unused
        self.keyClockDecoder = Lib0IntDiffOptRleDecoder(data: try decoder.readVarData())
        self.clientDecoder = Lib0UintOptRleDecoder(data: try decoder.readVarData())
        self.leftClockDecoder = Lib0IntDiffOptRleDecoder(data: try decoder.readVarData())
        self.rightClockDecoder = Lib0IntDiffOptRleDecoder(data: try decoder.readVarData())
        self.infoDecoder = Lib0RleDecoder(data: try decoder.readVarData())
        self.stringDecoder = try Lib0StringDecoder(data: try decoder.readVarData())
        self.parentInfoDecoder = Lib0RleDecoder(data: try decoder.readVarData())
        self.typeRefDecoder = Lib0UintOptRleDecoder(data: try decoder.readVarData())
        self.lenDecoder = Lib0UintOptRleDecoder(data: try decoder.readVarData())
        
        try super.init(decoder)
    }

    public func readLeftID() throws -> ID {
        return try ID(
            client: Int(self.clientDecoder.read()),
            clock: self.leftClockDecoder.read()
        )
    }

    public func readRightID() throws -> ID {
        return try ID(
            client: Int(self.clientDecoder.read()),
            clock: self.rightClockDecoder.read()
        )
    }

    public func readClient() throws -> Int {
        return try Int(self.clientDecoder.read())
    }

    public func readInfo() throws -> UInt8 {
        return try self.infoDecoder.read()
    }

    public func readString() throws -> String {
        return try self.stringDecoder.read()
    }

    public func readParentInfo() throws -> Bool {
        return try self.parentInfoDecoder.read() == 1
    }

    public func readTypeRef() throws -> Int {
        return try Int(self.typeRefDecoder.read())
    }

     public func readLen() throws -> Int {
        return try Int(self.lenDecoder.read())
    }

    public func readAny() throws -> Any? {
        return try self.restDecoder.readAny()
    }

    public func readBuf() throws -> Data {
        return try self.restDecoder.readVarData()
    }

    public func readKey() throws -> String {
        let keyClock = try self.keyClockDecoder.read()
        if keyClock < self.keys.count {
            return self.keys[keyClock]
        } else {
            let key = try self.stringDecoder.read()
            self.keys.append(key)
            return key
        }
    }
    
    public func readJSON() throws -> Any? {
        return try self.restDecoder.readAny()
    }
}


