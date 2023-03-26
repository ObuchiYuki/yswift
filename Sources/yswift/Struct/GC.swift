//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class GC: Struct {
    static let refID: UInt8 = 0
    
    public override var deleted: Bool { true }

    public override func merge(with right: Struct) -> Bool {
        guard let gc = right as? GC else { return false }
        self.length += gc.length
        return true
    }

    public override func integrate(transaction: Transaction, offset: Int) throws {
        if offset > 0 {
            self.id.clock += offset
            self.length -= offset
        }
        try transaction.doc.store.addStruct(self)
    }

    public override func encode(into encoder: UpdateEncoder, offset: Int) {
        encoder.writeInfo(GC.refID)
        encoder.writeLen(self.length - offset)
    }
}

