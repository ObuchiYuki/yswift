//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final class YGC: YStruct {
    static let refID: UInt8 = 0
    
    override var deleted: Bool { true }

    override func merge(with right: YStruct) -> Bool {
        guard let gc = right as? YGC else { return false }
        self.length += gc.length
        return true
    }

    override func integrate(transaction: Transaction, offset: Int) throws {
        if offset > 0 {
            self.id.clock += offset
            self.length -= offset
        }
        try transaction.doc.store.addStruct(self)
    }

    override func encode(into encoder: YUpdateEncoder, offset: Int) {
        encoder.writeInfo(YGC.refID)
        encoder.writeLen(self.length - offset)
    }
}

