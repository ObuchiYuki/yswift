//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

/// `YElement` should be light weight wrapper
public protocol YElement {
    static var isReference: Bool { get }
    
    static func fromOpaque(_ opaque: Any?) -> Self
    func toOpaque() -> Any?
}

extension YElement {
    public static var isReference: Bool { false } 
}

extension YOpaqueObject: YElement {
    public static var isReference: Bool { false }
    public static func fromOpaque(_ opaque: Any?) -> Self { opaque as! Self }
    
    public func toOpaque() -> Any? { self }
}
