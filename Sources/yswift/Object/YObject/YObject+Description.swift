//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject: CustomStringConvertible {
    public var description: String {
        var components = [String]()
                
        for var (key, value) in self.elementSequence().sorted(by: { $0.0 < $1.0 }) {
            if key == YObject.objectIDKey {
                value = YObjectID(value as! Int).compressedString()
                key = "_"
            }
            
            if let _value = value, !(_value is NSNull) {
                if let property = self._propertyTable[key], String(describing: type(of: property)).contains("YObjectReference") {
                    value = YObjectID(value as! Int).compressedString()
                }
                value = String(reflecting: value!)
            } else {
                value = "nil"
            }
            
            components.append("\(key): \(value!)")
        }
        
        return "\(Self.self)(\(components.joined(separator: ", ")))"
    }
}

