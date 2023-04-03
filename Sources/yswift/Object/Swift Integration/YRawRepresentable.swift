//
//  File.swift
//  
//
//  Created by yuki on 2023/04/02.
//

import Foundation

public protocol YRawRepresentable: YPrimitive {
    associatedtype RawValue: YPrimitive

    var rawValue: RawValue { get }

    init?(rawValue: RawValue)
}

extension YRawRepresentable {
    public func persistenceObject() -> Any? { self.rawValue }
    
    public static func fromPersistence(_ opaque: Any?) -> Self {
        Self.init(rawValue: opaque as! Self.RawValue)!
    }
}
