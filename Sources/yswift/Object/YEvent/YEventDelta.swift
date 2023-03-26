//
//  File.swift
//  
//
//  Created by yuki on 2023/03/26.
//

import Foundation

final public class YEventDelta {
    public var insert: YEventDeltaInsertType?
    public var retain: Int?
    public var delete: Int?
    public var attributes: YTextAttributes?
    
    public init(insert: YEventDeltaInsertType? = nil, retain: Int? = nil, delete: Int? = nil, attributes: YTextAttributes? = nil) {
        self.insert = insert
        self.retain = retain
        self.delete = delete
        self.attributes = attributes
    }
}

extension YEventDelta: CustomStringConvertible {
    public var description: String {
        var dict = [String: Any]()
        dict["insert"] = insert
        dict["retain"] = retain
        dict["delete"] = delete
        dict["attributes"] = attributes
        return dict.description
    }
}

extension YEventDelta: Equatable {
    public static func == (lhs: YEventDelta, rhs: YEventDelta) -> Bool {
        return optionalEqual(lhs.insert, rhs.insert, compare: { $0.isEqual(to: $1) })
        && lhs.retain == rhs.retain
        && lhs.delete == rhs.delete
        && optionalEqual(lhs.attributes, rhs.attributes, compare: { $0.isEqual(to: $1) })
    }
}


public protocol YEventDeltaInsertType {}

extension String: YEventDeltaInsertType {}
extension NSNumber: YEventDeltaInsertType {}
extension NSDictionary: YEventDeltaInsertType {}
extension NSArray: YEventDeltaInsertType {}
extension YObject: YEventDeltaInsertType {}

extension YEventDeltaInsertType {
    public func isEqual(to other: any YEventDeltaInsertType) -> Bool {
        if equalJSON(self, other) { return true }
        if let a = self as? YObject, let b = other as? YObject {
            return equalJSON(a.toJSON(), b.toJSON())
        }
        return false
    }
}
