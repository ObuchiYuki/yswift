//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

import Foundation

public protocol Content: AnyObject {
    var count: Int { get }
    
    var isCountable: Bool { get }
    
    func getContent() -> [Any?]
    
    func copy() -> Self
    
    func splice(_ offset: Int) -> Self

    func merge(with right: any Content) -> Bool

    func integrate(with item: Item, _ transaction: Transaction) throws -> Void

    func delete(_ transaction: Transaction) -> Void

    func gc(_ store: StructStore) throws -> Void

    func write(_ encoder: UpdateEncoder, offset: Int) throws -> Void
    
    func getRef() -> UInt8
}
