//
//  UpdateDecoder.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

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

    public func readLen() throws -> Int {
        return try Int(self.restDecoder.readUInt())
    }

    public func readAny() throws -> Any? {
        return try self.restDecoder.readAny()
    }

    public func readBuf() throws -> Data {
        return try self.restDecoder.readData()
    }

    public func readKey() throws -> String {
        return try self.restDecoder.readString()
    }
    
    public func readJSON() throws -> Any? {
        let data = try self.restDecoder.readData()
        return try! JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

public class UpdateDecoderV2: DSDecoderV2, UpdateDecoder {
    var keys: [String] = []
    
    let keyClockDecoder: LZIntDiffOptRleDecoder
    let clientDecoder: LZUIntOptRleDecoder
    let leftClockDecoder: LZIntDiffOptRleDecoder
    let rightClockDecoder: LZIntDiffOptRleDecoder
    let infoDecoder: LZRleDecoder
    let stringDecoder: LZStringDecoder
    let parentInfoDecoder: LZRleDecoder
    let typeRefDecoder: LZUIntOptRleDecoder
    let lenDecoder: LZUIntOptRleDecoder

    public required init(_ decoder: LZDecoder) throws {
        _ = try decoder.readUInt() // read feature flag - currently unused
        self.keyClockDecoder = LZIntDiffOptRleDecoder(try decoder.readData())
        self.clientDecoder = LZUIntOptRleDecoder(try decoder.readData())
        self.leftClockDecoder = LZIntDiffOptRleDecoder(try decoder.readData())
        self.rightClockDecoder = LZIntDiffOptRleDecoder(try decoder.readData())
        self.infoDecoder = LZRleDecoder(try decoder.readData())
        self.stringDecoder = try LZStringDecoder(try decoder.readData())
        self.parentInfoDecoder = LZRleDecoder(try decoder.readData())
        self.typeRefDecoder = LZUIntOptRleDecoder(try decoder.readData())
        self.lenDecoder = LZUIntOptRleDecoder(try decoder.readData())
        
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
        return try self.restDecoder.readData()
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


