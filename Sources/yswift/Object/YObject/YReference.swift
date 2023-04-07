//
//  File.swift
//  
//
//  Created by yuki on 2023/04/01.
//

import Promise

final public class YReference<T: YObject> {
    
    public var value: T { YObjectStore.shared.object(for: objectID) as! T }
    
    let objectID: YObjectID
    
    init(objectID: YObjectID) { self.objectID = objectID }
    
    public init(_ object: T) { self.objectID = object.objectID }
    
    public static func reference(for object: T) -> YReference<T> { .init(object) }
}

extension YReference: YPrimitive {
    public static var isReference: Bool { true }
    public func persistenceObject() -> Any? { self.objectID.value }
    public static func fromPersistence(_ opaque: Any?) -> YReference<T> {
        let id = YObjectID(opaque as! Int)
        return YReference(objectID: id)
    }
}
