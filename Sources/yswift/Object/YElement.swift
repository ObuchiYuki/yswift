//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

public protocol YElement {
    static var isReference: Bool { get }
    func persistenceObject() -> Any?
    static func fromPersistence(_ opaque: Any?) -> Self
}

extension YElement {
    public static var isReference: Bool { false } 
}

extension YOpaqueObject: YElement {
    public static var isReference: Bool { false }
    public func persistenceObject() -> Any? { self }
    public static func fromPersistence(_ opaque: Any?) -> Self { opaque as! Self }
}

// ============================================================================== //
// MARK: - Ex + Primitive -

public protocol YPrimitive: YElement {}

extension YPrimitive {
    public static var isReference: Bool { false }
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
extension CGFloat: YPrimitive {}
extension Double: YPrimitive {}

extension String: YPrimitive {}
extension Data: YPrimitive {}

extension NSArray: YPrimitive {}
extension NSDictionary: YPrimitive {}

extension Array: YPrimitive, YElement where Element: YPrimitive {
    public static var isReference: Bool { Element.isReference }
}
extension Dictionary: YPrimitive, YElement where Key == String, Value: YPrimitive {
    public static var isReference: Bool { Value.isReference }
}

extension Optional: YElement where Wrapped: YElement {
    public static var isReference: Bool { Wrapped.isReference }
    
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
