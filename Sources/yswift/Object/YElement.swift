//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

public protocol YElement {
    func persistenceObject() -> Any?
    static func fromPersistence(_ opaque: Any?) -> Self
}

extension YOpaqueObject: YElement {
    public func persistenceObject() -> Any? { self }
    public static func fromPersistence(_ opaque: Any?) -> Self { opaque as! Self }
}

// ============================================================================== //
// MARK: - Ex + Primitive -

public protocol YPrimitive: YElement {}

extension YPrimitive {
    public func persistenceObject() -> Any? { self }
    public static func fromPersistence(_ opaque: Any?) -> Self { opaque as! Self }
}

extension Int: YPrimitive {}
extension Int8: YPrimitive {}
extension Int16: YPrimitive {}
extension Int32: YPrimitive {}
extension Int64: YPrimitive {}

extension UInt: YPrimitive {}
extension UInt8: YPrimitive {}
extension UInt16: YPrimitive {}
extension UInt32: YPrimitive {}
extension UInt64: YPrimitive {}

extension Float: YPrimitive {}
extension Double: YPrimitive {}

extension String: YPrimitive {}
extension Data: YPrimitive {}

extension Array: YPrimitive, YElement where Element: YPrimitive {}
extension Dictionary: YPrimitive, YElement where Key == String, Value: YPrimitive {}

extension Optional: YElement where Wrapped: YElement {
    public func persistenceObject() -> Any? {
        switch self {
        case .none: return NSNull()
        case .some(let element): return element.persistenceObject()
        }
    }
    public static func fromPersistence(_ opaque: Any?) -> Self {
        if opaque == nil || opaque is NSNull {
            return .none
        } else {
            return .some(Wrapped.fromPersistence(opaque))
        }
    }
}
