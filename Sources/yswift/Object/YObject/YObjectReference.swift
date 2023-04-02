//
//  File.swift
//  
//
//  Created by yuki on 2023/04/01.
//

import Promise

protocol _YObjectReferenceType {}

final public class YObjectReference<T: YObject>: _YObjectReferenceType {
    
    public var value: Promise<YObject, Never> { YObjectStore.shared.object(for: objectID) }
    
    let objectID: YObjectID
    
    init(objectID: YObjectID) { self.objectID = objectID }
    
    public init(_ object: T) { self.objectID = object.objectID }
    
    public static func reference(for object: T) -> YObjectReference<T> { .init(object) }
}

extension YObjectReference: YElement {
    public func encodeToOpaque() -> Any? { self.objectID.value }
    public static func decode(from opaque: Any?) -> YObjectReference<T> {
        let id = YObjectID(opaque as! Int)
        return YObjectReference(objectID: id)
    }
}
