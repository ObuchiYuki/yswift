//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

public protocol YElement {}

public protocol YConcreteObject: YElement {
    associatedtype Opaque: YObject
    
    var opaque: Opaque { get }

    init(opaque: Opaque)
}

public protocol YPrimitive: YElement, Equatable, Hashable {}

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

extension Dictionary: YElement where Key == String, Value: YPrimitive {}
extension Dictionary: YPrimitive where Key == String, Value: YPrimitive {}

extension Array: YElement where Element: YPrimitive {}
extension Array: YPrimitive where Element: YPrimitive {}

extension NSString: YPrimitive {}
extension NSArray: YPrimitive {}
extension NSDictionary: YPrimitive {}

public protocol YCodable: YElement {
    func encode() throws -> NSDictionary
    static func decode(from dictionary: NSDictionary) throws -> Self
}

private let dictionayEncoder = DictionaryEncoder()
private let dictionayDecoder = DictionaryDecoder()

extension YCodable where Self: Encodable {
    func encode() throws -> NSDictionary {
        try dictionayEncoder.encode(self)
    }
}

extension YCodable where Self: Decodable {
    static func decode(from dictionary: NSDictionary) throws -> Self {
        try dictionayDecoder.decode(Self.self, from: dictionary)
    }
}
