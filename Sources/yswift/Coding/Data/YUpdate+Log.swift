//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

extension YUpdate {
    public func log() {
        switch self.version {
        case .v1: self._logUpdate(YDecoder: YUpdateDecoderV1.init)
        case .v2: self._logUpdate(YDecoder: YUpdateDecoderV2.init)
        }
    }

    private func _logUpdate(YDecoder: (LZDecoder) throws -> YUpdateDecoder) {
        do {
            var structs: [Struct] = []
            let updateDecoder = try YDecoder(LZDecoder(self.data))
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

}
