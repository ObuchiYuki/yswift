//
//  File.swift
//  
//
//  Created by yuki on 2023/03/16.
//

import Foundation

public let structSkipRefNumber: UInt8 = 10

final public class Skip: Struct {

    public override var deleted: Bool { true }

    public func delete() {}

    public func mergeWith(_ right: Struct) -> Bool {
        if type(of: self) != type(of: right) { return false }
        self.length += right.length
        return true
    }

    public override func integrate(transaction: Transaction, offset: UInt) throws {
        throw YSwiftError.unexpectedCase
    }

    public override func write(encoder: UpdateEncoder, offset: UInt) throws {
        encoder.writeInfo(structSkipRefNumber)
        encoder.restEncoder.writeUInt(self.length - offset)
    }

    public override func getMissing(_ transaction: Transaction, store: StructStore) -> UInt? {
        nil
    }
}
