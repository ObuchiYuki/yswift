//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation


struct ClientStruct {
    var written: Int
    var restEncoder: Data
}

public func sliceStruct(left: Struct, diff: Int) -> Struct { // no Skip return
    if left is GC {
        let client = left.id.client, clock = left.id.clock
        return GC(id: ID(client: client, clock: clock + diff), length: left.length - diff)
    } else if left is Skip {
        let client = left.id.client, clock = left.id.clock
        return Skip(id: ID(client: client, clock: clock + diff), length: left.length - diff)
    } else {
        let leftItem = left as! Item
        let client = leftItem.id.client, clock = leftItem.id.clock
        
        return Item(
            id: ID(client: client, clock: clock + diff),
            left: nil,
            origin: ID(client: client, clock: clock + diff - 1),
            right: nil,
            rightOrigin: leftItem.rightOrigin,
            parent: leftItem.parent,
            parentSub: leftItem.parentKey,
            content: leftItem.content.splice(diff)
        )
    }
}

public class StructWrite {
    public var struct_: Struct
    public var offset: Int
    
    init(struct_: Struct, offset: Int) {
        self.struct_ = struct_
        self.offset = offset
    }
}


func flushLazyStructWriter(lazyWriter: LazyStructWriter) {
    if lazyWriter.written > 0 {
        let clientStruct = ClientStruct(written: lazyWriter.written, restEncoder: lazyWriter.encoder.restEncoder.data)
        lazyWriter.clientStructs.append(clientStruct)
        lazyWriter.encoder.restEncoder = LZEncoder()
        lazyWriter.written = 0
    }
}

func writeStructToLazyStructWriter(lazyWriter: LazyStructWriter, struct_: Struct /* not Skip */, offset: Int) throws {
    // flush curr if we start another client
    if lazyWriter.written > 0 && lazyWriter.currClient != struct_.id.client {
        flushLazyStructWriter(lazyWriter: lazyWriter)
    }
    if lazyWriter.written == 0 {
        lazyWriter.currClient = Int(struct_.id.client)
        // write next client
        lazyWriter.encoder.writeClient(struct_.id.client)
        // write startClock
        lazyWriter.encoder.restEncoder.writeUInt(UInt(struct_.id.clock + offset))
    }
    try struct_.encode(into: lazyWriter.encoder, offset: offset)
    lazyWriter.written += 1
}

func finishLazyStructWriting(lazyWriter: LazyStructWriter) {
    flushLazyStructWriter(lazyWriter: lazyWriter)

    // this is a fresh encoder because we called flushCurr
    let restEncoder = lazyWriter.encoder.restEncoder

    restEncoder.writeUInt(UInt(lazyWriter.clientStructs.count))

    for i in 0..<lazyWriter.clientStructs.count {
        let partStructs = lazyWriter.clientStructs[i]
        restEncoder.writeUInt(UInt(partStructs.written))
        restEncoder.writeOpaqueSizeData(partStructs.restEncoder)
    }
}

public func convertUpdateFormat(
    update: YUpdate,
    YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init,
    YEncoder: () -> UpdateEncoder = UpdateEncoderV2.init
) throws -> YUpdate {
    let updateDecoder = try YDecoder(LZDecoder(update.data))
    let lazyDecoder = try LazyStructReader(updateDecoder, filterSkips: false)
    let updateEncoder = YEncoder()
    let lazyWriter = LazyStructWriter(updateEncoder)

    var curr = lazyDecoder.curr; while curr != nil {
        try writeStructToLazyStructWriter(lazyWriter: lazyWriter, struct_: curr!, offset: 0)
        curr = try lazyDecoder.next()
    }
    
    finishLazyStructWriting(lazyWriter: lazyWriter)
    let ds = try DeleteSet.decode(decoder: updateDecoder)
    try ds.encode(into: updateEncoder)
    return updateEncoder.toUpdate()
}

public func convertUpdateFormatV1ToV2(update: YUpdate) throws -> YUpdate {
    return try convertUpdateFormat(update: update, YDecoder: UpdateDecoderV1.init, YEncoder: UpdateEncoderV2.init)
}

public func convertUpdateFormatV2ToV1(update: YUpdate) throws -> YUpdate {
    return try convertUpdateFormat(update: update, YDecoder: UpdateDecoderV2.init, YEncoder: UpdateEncoderV1.init)
}
