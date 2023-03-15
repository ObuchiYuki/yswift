//
//  UpdateDecoder.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation
import lib0

public class DSDecoderV1 {
    let restDecoder: Lib0Decoder

    public init(_ decoder: Lib0Decoder) {
        self.restDecoder = decoder
    }

    public func resetDsCurVal() {}

    public func readDsClock() throws -> UInt {
        return try self.restDecoder.readUInt()
    }

    public func readDsLen() throws -> UInt {
        return try self.restDecoder.readUInt()
    }
}

public class UpdateDecoderV1: DSDecoderV1 {
    public func readLeftID() throws -> ID {
        return try ID(self.restDecoder.readUInt(), self.restDecoder.readUInt())
    }

    public func readRightID() throws -> ID {
        return ID(self.restDecoder.readUInt(), self.restDecoder.readUInt())
    }

    /**
     * Read the next client id.
     * Use this in favor of readID whenever possible to reduce the Int of objects created.
     */
    public func readClient() throws -> UInt {
        return try self.restDecoder.readUInt()
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

    public func readTypeRef() throws -> UInt {
        return try self.restDecoder.readUInt()
    }

    /** Write len of a struct - well suited for Opt RLE encoder. */
    public func readLen() throws -> UInt {
        return try self.restDecoder.readUInt()
    }

    public func readAny() throws -> Any {
        return try self.restDecoder.readAny()
    }

    public func readBuf() throws -> Data {
        return try self.restDecoder.readVarData()
    }

    public func readKey() throws -> String {
        return try self.restDecoder.readString()
    }
}

public class DSDecoderV2 {
    private var dsCurrVal: UInt = 0
    fileprivate let restDecoder: Lib0Decoder

    public init(_ decoder: Lib0Decoder) throws {
        self.restDecoder = decoder
    }

    public func resetDsCurVal() { self.dsCurrVal = 0 }

    public func readDsClock() throws -> UInt {
        self.dsCurrVal += try self.restDecoder.readUInt()
        return self.dsCurrVal
    }

    public func readDsLen() throws -> UInt {
        let diff = try self.restDecoder.readUInt() + 1
        self.dsCurrVal += diff
        return diff
    }
}

public class UpdateDecoderV2: DSDecoderV2 {
    private var keys: [String] = []
    
    private let keyClockDecoder: Lib0IntDiffOptRleDecoder
    private let clientDecoder: Lib0UintOptRleDecoder
    private let leftClockDecoder: Lib0IntDiffOptRleDecoder
    private let rightClockDecoder: Lib0IntDiffOptRleDecoder
    private let infoDecoder: Lib0RleDecoder
    private let StringDecoder: Lib0StringDecoder
    private let parentInfoDecoder: Lib0RleDecoder
    private let typeRefDecoder: Lib0UintOptRleDecoder
    private let lenDecoder: Lib0UintOptRleDecoder

    public override init(_ decoder: Lib0Decoder) throws {
        try super.init(decoder)

        _ = try decoder.readUInt() // read feature flag - currently unused
        self.keyClockDecoder = Lib0IntDiffOptRleDecoder(data: try decoder.readVarData())
        self.clientDecoder = Lib0UintOptRleDecoder(data: try decoder.readVarData())
        self.leftClockDecoder = Lib0IntDiffOptRleDecoder(data: try decoder.readVarData())
        self.rightClockDecoder = Lib0IntDiffOptRleDecoder(data: try decoder.readVarData())
        self.infoDecoder = Lib0RleDecoder(data: try decoder.readVarData())
        self.StringDecoder = try Lib0StringDecoder(data: try decoder.readVarData())
        self.parentInfoDecoder = Lib0RleDecoder(data: try decoder.readVarData())
        self.typeRefDecoder = Lib0UintOptRleDecoder(data: try decoder.readVarData())
        self.lenDecoder = Lib0UintOptRleDecoder(data: try decoder.readVarData())
    }

    public func readLeftID() throws -> ID {
        return try ID(self.clientDecoder.read(), self.leftClockDecoder.read())
    }

    public func readRightID() throws -> ID {
        return try ID(self.clientDecoder.read(), self.rightClockDecoder.read())
    }

    public func readClient() throws -> Int {
        return try self.clientDecoder.read()
    }

    public func readInfo() throws -> UInt8 {
        return try self.infoDecoder.read()
    }

    public func readString() throws -> String {
        return try self.StringDecoder.read()
    }

    public func readParentInfo() throws -> Bool {
        return try self.parentInfoDecoder.read() == 1
    }

    public func readTypeRef() throws -> Int {
        return try self.typeRefDecoder.read()
    }

     public func readLen() throws -> Int {
        return try self.lenDecoder.read()
    }

    public func readAny() throws -> Any {
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
            let key = try self.StringDecoder.read()
            self.keys.append(key)
            return key
        }
    }
}


