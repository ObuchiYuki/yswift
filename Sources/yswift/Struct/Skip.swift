//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

final public class Skip: Struct {
    static let refID: UInt8 = 10

    public override var deleted: Bool { true }

    public func mergeWith(_ right: Struct) -> Bool {
        guard let skip = right as? Skip else { return false }
        self.length += skip.length
        return true
    }

    public override func integrate(transaction: Transaction, offset: Int) throws {
        throw YSwiftError.unexpectedCase
    }

    public override func encode(into encoder: YUpdateEncoder, offset: Int) throws {
        encoder.writeInfo(Skip.refID)
        encoder.restEncoder.writeUInt(UInt(self.length - offset))
    }
}
