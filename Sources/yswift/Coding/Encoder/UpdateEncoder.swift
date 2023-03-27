//
//  UpdateEncoder.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol UpdateEncoder: DSEncoder {
    func writeLeftID(_ id: ID)
    func writeRightID(_ id: ID)
    func writeClient(_ client: Int)
    func writeInfo(_ info: UInt8)
    func writeString(_ s: String)
    func writeParentInfo(_ isYKey: Bool)
    func writeTypeRef(_ info: UInt8)
    func writeLen(_ len: Int)
    func writeAny(_ any: Any?)
    func writeBuf(_ buf: Data)
    func writeJSON(_ embed: Any?) throws
    func writeKey(_ key: String)
}

public class UpdateEncoderV1: DSEncoderV1, UpdateEncoder {
    
    public func writeLeftID(_ id: ID) {
        self.restEncoder.writeUInt(UInt(id.client))
        self.restEncoder.writeUInt(UInt(id.clock))
    }

    public func writeRightID(_ id: ID) {
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

    public func writeTypeRef(_ info: UInt8) {
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

    public func writeJSON(_ embed: Any?) throws {
        if let embed = embed {
            self.restEncoder.writeData(
                try JSONSerialization.data(withJSONObject: embed, options: [.fragmentsAllowed])
            )
        } else {
            self.restEncoder.writeString("null")
        }
    }

    public func writeKey(_ key: String) {
        self.restEncoder.writeString(key)
    }
}


public class UpdateEncoderV2: DSEncoderV2, UpdateEncoder {
    var keyMap: [String: Int] = [:]
    
    /// Refers to the next uniqe key-identifier to me used. See writeKey method for more information.
    private var keyClock: Int = 0

    let keyClockEncoder = LZIntDiffOptRleEncoder()
    let clientEncoder = LZUintOptRleEncoder()
    let leftClockEncoder = LZIntDiffOptRleEncoder()
    let rightClockEncoder = LZIntDiffOptRleEncoder()
    let infoEncoder = LZRleEncoder()
    let stringEncoder = LZStringEncoder()
    let parentInfoEncoder = LZRleEncoder()
    let typeRefEncoder = LZUintOptRleEncoder()
    let lenEncoder = LZUintOptRleEncoder()

    public override init() {
        super.init()
    }

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

    public func writeLeftID(_ id: ID) {
        self.clientEncoder.write(UInt(id.client))
        self.leftClockEncoder.write(id.clock)
    }

    public func writeRightID(_ id: ID) {
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

    public func writeTypeRef(_ info: UInt8) {
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

    /**
     * This is mainly here for legacy purposes.
     *
     * Initial we incoded objects using JSON. Now we use the much faster lib0/any-encoder. This method mainly exists for legacy purposes for the v1 encoder.
     */
    public func writeJSON(_ embed: Any?) {
        self.restEncoder.writeAny(embed)
    }

    /**
     * Property keys are often reused. For example, in y-prosemirror the key `bold` might
     * occur very often. For a 3d application, the key `position` might occur very often.
     *
     * We cache these keys in a Map and refer to them via a unique Int.
     */
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

