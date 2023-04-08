//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation
import lib0

final public class YDecodedUpdate {
    var structs: [YStructure]
    var deleteSets: YDeleteSet
    
    init(structs: [YStructure], deleteSets: YDeleteSet) {
        self.structs = structs
        self.deleteSets = deleteSets
    }
    
    init(_ update: Data, YDecoder: (LZDecoder) throws -> YUpdateDecoder = YUpdateDecoderV1.init) throws {
        var structs: [YStructure] = []
        let updateDecoder = try YDecoder(LZDecoder(update))
        let lazyDecoder = try YLazyStructReader(updateDecoder, filterSkips: false)
        var curr = lazyDecoder.curr
        while let ucurr = curr {
            structs.append(ucurr)
            curr = try lazyDecoder.next()
        }
        
        self.structs = structs
        self.deleteSets = try YDeleteSet.decode(decoder: updateDecoder)
    }
}


extension YDecodedUpdate: CustomStringConvertible {
    public var description: String {
        "YDecodedUpdate(structs: \(structs), deleteSets: \(deleteSets))"
    }
}
