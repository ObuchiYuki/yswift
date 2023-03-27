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

extension Int: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int8: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int16: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int32: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Int64: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension UInt: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt8: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt16: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt32: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension UInt64: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension Float: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Double: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension String: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension Data: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension Dictionary: YElement where Key == String, Value: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension Array: YElement where Element: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}

extension NSString: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension NSArray: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
extension NSDictionary: YElement {
    public func encodeToOpaque() -> Any? { self }
    public static func decode(from opaque: Any?) -> Self { opaque as! Self }
}
