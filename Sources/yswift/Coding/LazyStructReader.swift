//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

// Swift has no generator. So just providing API.
final class LazyStructReader {
    var gen: Array<Struct>.Iterator
    let filterSkips: Bool
    
    private(set) var curr: Struct?
    private(set) var done: Bool
    
    init(_ decoder: UpdateDecoder, filterSkips: Bool) throws {
        
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

    func next() throws -> Struct? {
        repeat {
            self.curr = self.gen.next()
        } while (self.filterSkips && self.curr != nil && self.curr is Skip)
        return self.curr
    }
}

final class LazyStructWriter {
    var currClient: Int
    var startClock: Int
    var written: Int
    var encoder: UpdateEncoder
    var clientStructs: [ClientStruct]
    
    init(_ encoder: UpdateEncoder) {
        self.currClient = 0
        self.startClock = 0
        self.written = 0
        self.encoder = encoder
        self.clientStructs = []
    }
}
