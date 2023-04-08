//
//  File.swift
//  
//
//  Created by yuki on 2023/04/01.
//

final public class YReference<T: YObject> {
    
    public var value: T { YObjectStore.shared.object(for: objectID) as! T }
    
    let objectID: YObjectID
    
    init(objectID: YObjectID) { self.objectID = objectID }
    
    public init(_ object: T) { self.objectID = object.objectID }
    
    public static func reference(for object: T) -> YReference<T> { .init(object) }
}

extension YReference: YValue {
    public static var isReference: Bool { true }
    
    public func toOpaque() -> Any? { self.objectID.value }
    
    public static func fromOpaque(_ opaque: Any?) -> YReference<T> {
        YReference(objectID: YObjectID(opaque as! Int))
    }
    
    public func toPropertyList() -> Any? { self.objectID.value }
    
    public static func fromPropertyList(_ content: Any?) -> YReference<T>? {
        guard let content = content as? Int else { return nil }
        return YReference(objectID: YObjectID(content))
    }
}
