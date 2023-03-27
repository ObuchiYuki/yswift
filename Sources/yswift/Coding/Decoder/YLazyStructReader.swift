//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

// Swift has no generator. So just providing API.
final class YLazyStructReader {
    private(set) var curr: YStruct?
    private(set) var done: Bool
    
    private var gen: Array<YStruct>.Iterator
    private let filterSkips: Bool
    
    init(_ decoder: YUpdateDecoder, filterSkips: Bool) throws {
        
        // TODO: lazy!
        var array = [YStruct]()
        try lazyStructReaderGenerator(decoder, yield: {
            array.append($0)
        })
        
        self.gen = array.makeIterator()
        self.curr = nil
        self.done = false
        self.filterSkips = filterSkips
        _ = try self.next()
    }

    func next() throws -> YStruct? {
        repeat {
            self.curr = self.gen.next()
        } while (self.filterSkips && self.curr != nil && self.curr is YSkip)
        return self.curr
    }
}
