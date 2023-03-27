//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation


public func logUpdate(_ update: YUpdate) {
    logUpdateV2(update, YDecoder: UpdateDecoderV1.init)
}

public func logUpdateV2(_ update: YUpdate, YDecoder: (LZDecoder) throws -> UpdateDecoder = UpdateDecoderV2.init) {
    do {
        var structs: [Struct] = []
        let updateDecoder = try YDecoder(LZDecoder(update.data))
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
