//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

public let structGCRefNumber: UInt8 = 0

public class GC: Struct {
    public override var deleted: Bool { true }

    public func delete() {}

    public override func merge(with right: Struct) -> Bool {
        if type(of: self) != type(of: right) { return false }
        self.length += right.length
        return true
    }

    public override func integrate(transaction: Transaction, offset: Int) throws {
        if offset > 0 {
            self.id.clock += offset
            self.length -= offset
        }
        try transaction.doc.store.addStruct(self)
    }

    public override func write(encoder: UpdateEncoder, offset: Int) {
        encoder.writeInfo(structGCRefNumber)
        encoder.writeLen(self.length - offset)
    }

    public override func getMissing(_ transaction: Transaction, store: StructStore) -> Int? {
        return nil
    }
}

