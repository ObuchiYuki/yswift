//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation


public func lazyStructReaderGenerator(_ decoder: UpdateDecoder, yield: (Struct) -> ()) throws {

    let numOfStateUpdates = try decoder.restDecoder.readUInt()
    
    for _ in 0..<numOfStateUpdates {
        let numberOfStructs = try decoder.restDecoder.readUInt()
        let client = try decoder.readClient()
        var clock = try Int(decoder.restDecoder.readUInt())
        
        for _ in 0..<numberOfStructs {
            let info = try decoder.readInfo()
            if info == 10 {
                let len = try Int(decoder.restDecoder.readUInt())
                yield(
                    Skip(id: ID(client: client, clock: clock), length: len)
                )
                clock += len
            } else if (info & 0b0001_1111) != 0 {
                let cantCopyParentInfo = (info & (0b0100_0000 | 0b1000_0000)) == 0
                let struct_ = try Item(
                    id: ID(client: client, clock: clock),
                    left: nil,
                    origin: (info & 0b1000_0000) == 0b1000_0000 ? decoder.readLeftID() : nil, // origin
                    right: nil,
                    rightOrigin: (info & 0b0100_0000) == 0b0100_0000 ? decoder.readRightID() : nil, // right origin
                    parent: cantCopyParentInfo
                    ? (decoder.readParentInfo()
                        ? decoder.readString() as (any AbstractType_or_ID_or_String)
                        : decoder.readLeftID() as (any AbstractType_or_ID_or_String))
                    : nil,
                    parentSub: cantCopyParentInfo && (info & 0b0010_0000) == 0b0010_0000 ? decoder.readString() : nil, // parentSub
                    content: readItemContent(decoder: decoder, info: info) // item content
                )
                yield(struct_)
                clock += struct_.length
            } else {
                let len = try decoder.readLen()
                yield(GC(id: ID(client: client, clock: clock), length: len))
                clock += len
            }
        }
    }
}

