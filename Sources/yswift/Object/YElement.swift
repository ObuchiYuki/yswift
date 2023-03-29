//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

public protocol YElement {
    func encodeToOpaque() -> Any?
    static func decode(from opaque: Any?) -> Self
}

extension YOpaqueObject: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

// ============================================================================== //
// MARK: - Ex + Codable -
private let dictionayEncoder = DictionaryEncoder()
private let dictionayDecoder = DictionaryDecoder()

extension YElement where Self: Encodable {
    public func encodeToOpaque() -> Any? {
        try! dictionayEncoder.encode(self) as NSDictionary
    }
}

extension YElement where Self: Decodable {
    public static func decode(from opaque: Any?) -> Self {
        try! dictionayDecoder.decode(Self.self, from: opaque as! NSDictionary)
    }
}

// ============================================================================== //
// MARK: - Ex + Primitive -

public protocol YPrimitive {
    func encodeToOpaque() -> Any?
    static func decode(from opaque: Any?) -> Self
}

extension Int: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int8: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int16: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int32: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int64: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension UInt: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt8: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt16: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt32: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt64: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension Float: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Double: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension String: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Data: YPrimitive, YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension Array: YElement where Element: YPrimitive {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension Optional: YElement where Wrapped: YElement {
    public func encodeToOpaque() -> Any? {
        switch self {
        case .none: return NSNull()
        case .some(let element): return element
        }
    }
    public static func decode(from opaque: Any?) -> Self {
        if opaque == nil || opaque is NSNull {
            return .none
        } else {
            return .some(Wrapped.decode(from: opaque))
        }
    }
}
