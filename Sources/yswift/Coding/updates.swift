//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

public class LazyStructReader {
    public var gen: Array<Struct>.Iterator
    public var curr: Struct?
    public var done: Bool
    public var filterSkips: Bool
    
    public init(_ decoder: UpdateDecoder, filterSkips: Bool) throws {
        
        // TODO: lazy!
        var array = [Struct]()
        try lazyStructReaderGenerator(decoder, yield: {
            array.append($0)
        })
        
        self.gen = array.makeIterator()
        /**
         * @type {nil | Item | Skip | GC}
         */
        self.curr = nil
        self.done = false
        self.filterSkips = filterSkips
        _ = try self.next()
    }

    public func next() throws -> Struct? {
        repeat {
            self.curr = self.gen.next()
        } while (self.filterSkips && self.curr != nil && self.curr is Skip)
        return self.curr
    }
}

public func logUpdate(_ update: Data) {
    logUpdateV2(update, YDecoder: UpdateDecoderV1.init)
}

public func logUpdateV2(_ update: Data, YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init) {
    do {
        var structs: [Struct] = []
        let updateDecoder = try YDecoder(LZDecoder(update))
        let lazyDecoder = try LazyStructReader(updateDecoder, filterSkips: false)
        
        var curr = lazyDecoder.curr; while curr != nil {
            structs.append(curr!)
            curr = try lazyDecoder.next()
        }
        print("Structs: \(structs)")
        let ds = try DeleteSet.decode(decoder: updateDecoder)
        print("DeleteSet: \(ds)")
    } catch {
        print(error)
    }
}

public class DecodedUpdate {
    public var structs: [Struct]
    public var ds: DeleteSet
    
    init(structs: [Struct], ds: DeleteSet) {
        self.structs = structs
        self.ds = ds
    }
}

func decodeUpdate(update: Data) throws -> DecodedUpdate {
    return try decodeUpdateV2(update: update, YDecoder: UpdateDecoderV1.init)
}

public func decodeUpdateV2(update: Data, YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init) throws -> DecodedUpdate {
    var structs: [Struct] = []
    let updateDecoder = try YDecoder(LZDecoder(update))
    let lazyDecoder = try LazyStructReader(updateDecoder, filterSkips: false)
    var curr = lazyDecoder.curr
    while curr != nil {
        structs.append(curr!)
        curr = try lazyDecoder.next()
    }
    
    return DecodedUpdate(structs: structs, ds: try DeleteSet.decode(decoder: updateDecoder))
}

public struct ClientStruct {
    public var written: Int
    public var restEncoder: Data
}

public class LazyStructWriter {
    public var currClient: Int
    public var startClock: Int
    public var written: Int
    public var encoder: UpdateEncoder
    public var clientStructs: [ClientStruct]
    
    public init(_ encoder: UpdateEncoder) {
        self.currClient = 0
        self.startClock = 0
        self.written = 0
        self.encoder = encoder
        self.clientStructs = []
    }
}

public func mergeUpdates(updates: Array<Data>) throws -> Data {
    return try mergeUpdatesV2(updates: updates, YDecoder: UpdateDecoderV1.init, YEncoder: UpdateEncoderV1.init)
}

public func encodeStateVectorFromUpdateV2(
    update: Data,
    YEncoder: () -> DSEncoder = DSEncoderV2.init,
    YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init
) throws -> Data {
    var encoder = YEncoder()
    let updateDecoder = try LazyStructReader(YDecoder(LZDecoder(update)), filterSkips: false)
    var curr = updateDecoder.curr
    if curr != nil {
        var size = 0
        var currClient = curr!.id.client
        var stopCounting = curr!.id.clock != 0 // must start at 0
        var currClock = stopCounting ? 0 : curr!.id.clock + curr!.length
        while curr != nil {
            if currClient != curr!.id.client {
                if currClock != 0 {
                    size += 1
                    encoder.restEncoder.writeUInt(UInt(currClient))
                    encoder.restEncoder.writeUInt(UInt(currClock))
                }
                currClient = curr!.id.client
                currClock = 0
                stopCounting = curr!.id.clock != 0
            }
            if curr! is Skip {
                stopCounting = true
            }
            if !stopCounting {
                currClock = curr!.id.clock + curr!.length
            }
            curr = try updateDecoder.next()
        }
        // write what we have
        if currClock != 0 {
            size += 1
            encoder.restEncoder.writeUInt(UInt(currClient))
            encoder.restEncoder.writeUInt(UInt(currClock))
        }
        // prepend the size of the state vector
        let enc = LZEncoder()
        enc.writeUInt(UInt(size))
        enc.writeOpaqueSizeData(encoder.restEncoder.data)
        encoder.restEncoder = enc
        return encoder.toData()
    } else {
        encoder.restEncoder.writeUInt(0)
        return encoder.toData()
    }
}

public func encodeStateVectorFromUpdate(update: Data) throws -> Data {
    return try encodeStateVectorFromUpdateV2(update: update, YEncoder: DSEncoderV1.init, YDecoder: UpdateDecoderV1.init)
}

public class UpdateMeta: Equatable {
    public static func == (lhs: UpdateMeta, rhs: UpdateMeta) -> Bool {
        lhs.from == rhs.from && lhs.to == rhs.to
    }
    
    public var from: [Int: Int]
    public var to: [Int: Int]
    
    init(from: [Int : Int], to: [Int : Int]) {
        self.from = from
        self.to = to
    }
}

public func parseUpdateMetaV2(update: Data, YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init) throws -> UpdateMeta {
    var from: [Int: Int] = [:]
    var to: [Int: Int] = [:]
    
    let updateDecoder = try LazyStructReader(YDecoder(LZDecoder(update)), filterSkips: false)
    var curr = updateDecoder.curr
    if curr != nil {
        var currClient = curr!.id.client
        var currClock = curr!.id.clock
        // write the beginning to `from`
        from[Int(currClient)] = Int(currClock)
        
        while curr != nil {
            if currClient != curr!.id.client {
                to[Int(currClient)] = Int(currClock)
                from[Int(curr!.id.client)] = Int(curr!.id.clock)
                currClient = curr!.id.client
            }
            currClock = curr!.id.clock + curr!.length
            
            curr = try updateDecoder.next()
        }
        
        to[Int(currClient)] = Int(currClock)
    }
    return UpdateMeta(from: from, to: to)
}

public func parseUpdateMeta(update: Data) throws -> UpdateMeta {
    return try parseUpdateMetaV2(update: update, YDecoder: UpdateDecoderV1.init)
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

public func mergeUpdatesV2(
    updates: [Data],
    YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init,
    YEncoder: () -> UpdateEncoder = UpdateEncoderV2.init
) throws -> Data {    
    if updates.count == 1 {
        return updates[0]
    }
    let updateDecoders = try updates.map{ try YDecoder(LZDecoder($0)) }
    var lazyStructDecoders = try updateDecoders.map{ try LazyStructReader($0, filterSkips: true) }

    var currWrite: StructWrite? = nil

    let updateEncoder = YEncoder()
    let lazyStructEncoder = LazyStructWriter(updateEncoder)
    
    while (true) {
        lazyStructDecoders = lazyStructDecoders.filter{
            $0.curr != nil
        }
        lazyStructDecoders.sort(by: { dec1, dec2 in
            if dec1.curr!.id.client == dec2.curr!.id.client {
                let clockDiff = dec1.curr!.id.clock - dec2.curr!.id.clock
                if clockDiff == 0 {
                    // @todo remove references to skip since the structDecoders must filter Skips.
                    return type(of: dec1.curr) == type(of: dec2.curr)
                        ? false
                        : dec1.curr is Skip ? false : true // we are filtering skips anyway.
                } else {
                    return clockDiff < 0
                }
            } else {
                return dec2.curr!.id.client - dec1.curr!.id.client < 0
            }
        })
                        
        if lazyStructDecoders.count == 0 {
            break
        }
        let currDecoder = lazyStructDecoders[0]
        
        let firstClient = currDecoder.curr!.id.client

        if currWrite != nil {
            var curr = currDecoder.curr
            var iterated = false

            // iterate until we find something that we haven't written already
            // remember: first the high client-ids are written
            while (curr != nil
                   && curr!.id.clock + curr!.length <= currWrite!.struct_.id.clock + currWrite!.struct_.length
                   && curr!.id.client >= currWrite!.struct_.id.client
            ) {
                curr = try currDecoder.next()
                iterated = true
            }
            if (
                // current decoder is empty
                curr == nil
                // check whether there is another decoder that has has updates from `firstClient`
                || curr!.id.client != firstClient
                // the above while loop was used and we are potentially missing updates
                || (iterated && curr!.id.clock > currWrite!.struct_.id.clock + currWrite!.struct_.length)
            ) {
                continue
            }

            if firstClient != currWrite!.struct_.id.client {
                try writeStructToLazyStructWriter(
                    lazyWriter: lazyStructEncoder,
                    struct_: currWrite!.struct_,
                    offset: Int(currWrite!.offset)
                )
                currWrite = StructWrite(struct_: curr!, offset: 0)
                _ = try currDecoder.next()
            } else {
                if currWrite!.struct_.id.clock + currWrite!.struct_.length < curr!.id.clock {
                    if currWrite!.struct_ is Skip {
                        currWrite!.struct_.length = curr!.id.clock + curr!.length - currWrite!.struct_.id.clock
                    } else {
                        try writeStructToLazyStructWriter(
                            lazyWriter: lazyStructEncoder,
                            struct_: currWrite!.struct_,
                            offset: currWrite!.offset
                        )
                        let diff = curr!.id.clock - currWrite!.struct_.id.clock - currWrite!.struct_.length
                        let struct_ = Skip(id: ID(client: firstClient, clock: currWrite!.struct_.id.clock + currWrite!.struct_.length), length: diff)
                        currWrite = StructWrite(struct_: struct_, offset: 0)
                    }
                } else { // if currWrite.struct.id.clock + currWrite.struct.length >= curr.id.clock {
                    let diff = currWrite!.struct_.id.clock + currWrite!.struct_.length - curr!.id.clock
                    if diff > 0 {
                        if currWrite!.struct_ is Skip {
                            // prefer to slice Skip because the other struct might contain more information
                            currWrite!.struct_.length -= diff
                        } else {
                            curr = sliceStruct(left: curr!, diff: diff)
                        }
                    }
                    if !currWrite!.struct_.merge(with: curr!) {
                        try writeStructToLazyStructWriter(
                            lazyWriter: lazyStructEncoder,
                            struct_: currWrite!.struct_,
                            offset: currWrite!.offset
                        )
                        currWrite = StructWrite(struct_: curr!, offset: 0)
                        _ = try currDecoder.next()
                    }
                }
            }
        } else {
            currWrite = StructWrite(struct_: currDecoder.curr!, offset: 0)
            _ = try currDecoder.next()
        }
        var next = currDecoder.curr
        
        while(
            next != nil
            && next!.id.client == firstClient
            && next!.id.clock == currWrite!.struct_.id.clock + currWrite!.struct_.length
            && !(next is Skip)
        ) {
            try writeStructToLazyStructWriter(lazyWriter: lazyStructEncoder, struct_: currWrite!.struct_, offset: currWrite!.offset)
            currWrite = StructWrite(struct_: next!, offset: 0)
            
            next = try currDecoder.next()
        }
    }
    
    if currWrite != nil {
        try writeStructToLazyStructWriter(lazyWriter: lazyStructEncoder, struct_: currWrite!.struct_, offset: currWrite!.offset)
        currWrite = nil
    }
    finishLazyStructWriting(lazyWriter: lazyStructEncoder)

    let dss = try updateDecoders.map{ try DeleteSet.decode(decoder: $0) }
    let ds = DeleteSet.mergeAll(dss)
    try ds.encode(updateEncoder)
    return updateEncoder.toData()
}

public func diffUpdateV2(
    update: Data, sv: Data,
    YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init,
    YEncoder: () -> UpdateEncoder = UpdateEncoderV2.init
) throws -> Data {
    let state = try decodeStateVector(decodedState: sv)
    let encoder = YEncoder()
    let lazyStructWriter = LazyStructWriter(encoder)
    let decoder = try YDecoder(LZDecoder(update))
    let reader = try LazyStructReader(decoder, filterSkips: false)
    while reader.curr != nil {
        let curr = reader.curr
        let currClient = curr!.id.client
        let svClock = state[Int(currClient)] ?? 0
        if reader.curr is Skip {
            _ = try reader.next()
            continue
        }
        if curr!.id.clock + curr!.length > svClock {
            try writeStructToLazyStructWriter(lazyWriter: lazyStructWriter, struct_: curr!, offset: max(svClock - Int(curr!.id.clock), 0))
            _ = try reader.next()
            while (reader.curr != nil && reader.curr!.id.client == currClient) {
                try writeStructToLazyStructWriter(lazyWriter: lazyStructWriter, struct_: reader.curr!, offset: 0)
                _ = try reader.next()
            }
        } else {
            // read until something comes up
            while (reader.curr != nil && reader.curr!.id.client == currClient && reader.curr!.id.clock + reader.curr!.length <= svClock) {
                _ = try reader.next()
            }
        }
    }
    finishLazyStructWriting(lazyWriter: lazyStructWriter)
    // write ds
    let ds = try DeleteSet.decode(decoder: decoder)
    try ds.encode(encoder)
    return encoder.toData()
}

public func diffUpdate(update: Data, sv: Data) throws -> Data {
    return try diffUpdateV2(update: update, sv: sv, YDecoder: UpdateDecoderV1.init, YEncoder: UpdateEncoderV1.init)
}



public func flushLazyStructWriter(lazyWriter: LazyStructWriter) {
    if lazyWriter.written > 0 {
        let clientStruct = ClientStruct(written: lazyWriter.written, restEncoder: lazyWriter.encoder.restEncoder.data)
        lazyWriter.clientStructs.append(clientStruct)
        lazyWriter.encoder.restEncoder = LZEncoder()
        lazyWriter.written = 0
    }
}

public func writeStructToLazyStructWriter(lazyWriter: LazyStructWriter, struct_: Struct /* not Skip */, offset: Int) throws {
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

public func finishLazyStructWriting(lazyWriter: LazyStructWriter) {
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
    update: Data,
    YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init,
    YEncoder: () -> UpdateEncoder = UpdateEncoderV2.init
) throws -> Data {
    let updateDecoder = try YDecoder(LZDecoder(update))
    let lazyDecoder = try LazyStructReader(updateDecoder, filterSkips: false)
    let updateEncoder = YEncoder()
    let lazyWriter = LazyStructWriter(updateEncoder)

    var curr = lazyDecoder.curr; while curr != nil {
        try writeStructToLazyStructWriter(lazyWriter: lazyWriter, struct_: curr!, offset: 0)
        curr = try lazyDecoder.next()
    }
    
    finishLazyStructWriting(lazyWriter: lazyWriter)
    let ds = try DeleteSet.decode(decoder: updateDecoder)
    try ds.encode(updateEncoder)
    return updateEncoder.toData()
}

public func convertUpdateFormatV1ToV2(update: Data) throws -> Data {
    return try convertUpdateFormat(update: update, YDecoder: UpdateDecoderV1.init, YEncoder: UpdateEncoderV2.init)
}

public func convertUpdateFormatV2ToV1(update: Data) throws -> Data {
    return try convertUpdateFormat(update: update, YDecoder: UpdateDecoderV2.init, YEncoder: UpdateEncoderV1.init)
}
