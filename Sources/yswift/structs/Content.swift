//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol Content {
    func getLength() -> UInt
    
    func getContent() -> [Any]
    
    func isCountable() -> Bool
    
    func copy() -> Self
    
    func splice(_ offset: UInt) -> Self

    func mergeWith(_ right: any Content) -> Bool

    func integrate(_ transaction: Transaction, item: Item) -> Void

    func delete(_ transaction: Transaction) -> Void

    func gc(_ store: StructStore) -> Void

    func write(_ encoder: UpdateEncoder, offset: UInt) throws -> Void
    
    func getRef() -> UInt8
}
