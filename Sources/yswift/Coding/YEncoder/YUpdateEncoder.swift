//
//  UpdateEncoder.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol YUpdateEncoder: YDeleteSetEncoder {
    func writeLeftID(_ id: YID)
    func writeRightID(_ id: YID)
    func writeClient(_ client: Int)
    func writeInfo(_ info: UInt8)
    func writeString(_ s: String)
    func writeParentInfo(_ isYKey: Bool)
    func writeTypeRef(_ info: Int)
    func writeLen(_ len: Int)
    func writeAny(_ any: Any?)
    func writeBuf(_ buf: Data)
    func writeJSON(_ embed: Any?)
    func writeKey(_ key: String)
}

public class YUpdateEncoderV1: YDeleteSetEncoderV1, YUpdateEncoder {
    
    public func writeLeftID(_ id: YID) {
        self.restEncoder.writeUInt(UInt(id.client))
        self.restEncoder.writeUInt(UInt(id.clock))
    }

    public func writeRightID(_ id: YID) {
        self.restEncoder.writeUInt(UInt(id.client))
        self.restEncoder.writeUInt(UInt(id.clock))
    }

    public func writeClient(_ client: Int) {
        self.restEncoder.writeUInt(UInt(client))
    }

    public func writeInfo(_ info: UInt8) {
        self.restEncoder.writeUInt8(info)
    }

    public func writeString(_ s: String) {
        self.restEncoder.writeString(s)
    }

    public func writeParentInfo(_ isYKey: Bool) {
        self.restEncoder.writeUInt(isYKey ? 1 : 0)
    }

    public func writeTypeRef(_ info: Int) {
        self.restEncoder.writeUInt(UInt(info))
    }

    public func writeLen(_ len: Int) {
        self.restEncoder.writeUInt(UInt(len))
    }

    public func writeAny(_ any: Any?) {
        self.restEncoder.writeAny(any)
    }

    public func writeBuf(_ buf: Data) {
        self.restEncoder.writeData(buf)
    }

    public func writeJSON(_ embed: Any?) {
        if let embed = embed {
            self.restEncoder.writeData(try! JSONSerialization.data(withJSONObject: embed, options: [.fragmentsAllowed]))
        } else {
            self.restEncoder.writeString("null")
        }
    }

    public func writeKey(_ key: String) {
        self.restEncoder.writeString(key)
    }
}


public class YUpdateEncoderV2: YDeleteSetEncoderV2, YUpdateEncoder {
    /// Refers to the next uniqe key-identifier to me used. See writeKey method for more information.
    private var keyClock: Int = 0

    private var keyMap: [String: Int] = [:]
    
    private let keyClockEncoder = LZIntDiffOptRleEncoder()
    private let clientEncoder = LZUintOptRleEncoder()
    private let leftClockEncoder = LZIntDiffOptRleEncoder()
    private let rightClockEncoder = LZIntDiffOptRleEncoder()
    private let infoEncoder = LZRleEncoder()
    private let stringEncoder = LZStringEncoder()
    private let parentInfoEncoder = LZRleEncoder()
    private let typeRefEncoder = LZUintOptRleEncoder()
    private let lenEncoder = LZUintOptRleEncoder()

    public override func toData() -> Data {
        let encoder = LZEncoder()
        encoder.writeUInt(0)
        encoder.writeData(self.keyClockEncoder.data)
        encoder.writeData(self.clientEncoder.data)
        encoder.writeData(self.leftClockEncoder.data)
        encoder.writeData(self.rightClockEncoder.data)
        encoder.writeData(self.infoEncoder.data)
        encoder.writeData(self.stringEncoder.data)
        encoder.writeData(self.parentInfoEncoder.data)
        encoder.writeData(self.typeRefEncoder.data)
        encoder.writeData(self.lenEncoder.data)
        encoder.writeOpaqueSizeData(self.restEncoder.data)
        return encoder.data
    }

    public func writeLeftID(_ id: YID) {
        self.clientEncoder.write(UInt(id.client))
        self.leftClockEncoder.write(id.clock)
    }

    public func writeRightID(_ id: YID) {
        self.clientEncoder.write(UInt(id.client))
        self.rightClockEncoder.write(id.clock)
    }

    public func writeClient(_ client: Int) {
        self.clientEncoder.write(UInt(client))
    }

    public func writeInfo(_ info: UInt8) {
        self.infoEncoder.write(info)
    }

    public func writeString(_ s: String) {
        self.stringEncoder.write(s)
    }

    public func writeParentInfo(_ isYKey: Bool) {
        self.parentInfoEncoder.write(isYKey ? 1 : 0)
    }

    public func writeTypeRef(_ info: Int) {
        self.typeRefEncoder.write(UInt(info))
    }

    /// Write len of a struct - well suited for Opt RLE encoder.
    public func writeLen(_ len: Int) {
        self.lenEncoder.write(UInt(len))
    }

    public func writeAny(_ any: Any?) {
        self.restEncoder.writeAny(any)
    }

    public func writeBuf(_ buf: Data) {
        self.restEncoder.writeData(buf)
    }

    public func writeJSON(_ embed: Any?) {
        self.restEncoder.writeAny(embed)
    }

    public func writeKey(_ key: String) {
        let clock = self.keyMap[key]
        
        if clock == nil {
            self.keyClockEncoder.write(self.keyClock)
            self.keyClock += 1
            self.stringEncoder.write(key)
        } else {
            self.keyClockEncoder.write(clock!)
        }        
    }
}

