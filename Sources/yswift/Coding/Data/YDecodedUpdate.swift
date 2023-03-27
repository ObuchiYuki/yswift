//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

final public class YDecodedUpdate {
    public var structs: [Struct]
    public var deleteSets: DeleteSet
    
    init(structs: [Struct], deleteSets: DeleteSet) {
        self.structs = structs
        self.deleteSets = deleteSets
    }
    
    public init(_ update: Data, YDecoder: (LZDecoder) throws -> YUpdateDecoder = YUpdateDecoderV1.init) throws {
        var structs: [Struct] = []
        let updateDecoder = try YDecoder(LZDecoder(update))
        let lazyDecoder = try YLazyStructReader(updateDecoder, filterSkips: false)
        var curr = lazyDecoder.curr
        while let ucurr = curr {
            structs.append(ucurr)
            curr = try lazyDecoder.next()
        }
        
        self.structs = structs
        self.deleteSets = try DeleteSet.decode(decoder: updateDecoder)
    }
}


extension YDecodedUpdate: CustomStringConvertible {
    public var description: String {
        "YDecodedUpdate(structs: \(structs), deleteSets: \(deleteSets))"
    }
}
