//
//  File.swift
//  
//
//  Created by yuki on 2023/04/03.
//

import Foundation

extension YObject {
    
    func _copyWithSmartCopy(map: YObject, value: Any?, key: String, writers: RefDictionary<YObjectID, (YObjectID) -> ()>) {
        if let id = value as? Int {
            writers[YObjectID(id)] = { map._setValue($0.persistenceObject(), for: key) }
        } else if let value = value as? [Int] {
            var takeValues = [YObjectID]()
            for id in value {
                writers[YObjectID(id)] = { newID in // newID
                    takeValues.append(newID)
                    if takeValues.count == value.count { map._setValue(takeValues, for: key) }
                }
            }
        } else if let value = value as? [String: Int] {
            var takeValues = [String: YObjectID]()
            for (mkey, id) in value {
                writers[YObjectID(id)] = { newID in // newID
                    takeValues[mkey] = newID
                    if takeValues.count == value.count { map._setValue(takeValues, for: key) }
                }
            }
        } else if let value = value as? YOpaqueArray, value.allSatisfy({ $0 is Int }) {
            var takeValues = [YObjectID]()
            for id in value {
                writers[YObjectID(id as! Int)] = { newID in // newID
                    takeValues.append(newID)
                    if takeValues.count == value.count { map._setValue(takeValues, for: key) }
                }
            }
        } else if let value = value as? YOpaqueMap, value.values().allSatisfy({ $0 is Int }) {
            var takeValues = [String: YObjectID]()
            for (mkey, id) in value {
                writers[YObjectID(id as! Int)] = { newID in // newID
                    takeValues[mkey] = newID
                    if takeValues.count == value.count { map._setValue(takeValues, for: key) }
                }
            }
        }
    }
    
    public func smartCopy() -> Self {
        // [old:new]
        let table = RefDictionary<YObjectID, YObjectID>()
        let writers = RefDictionary<YObjectID, (YObjectID) -> ()>()
        YObject.initContext = .smartcopy(table, writers)
        
        let copied = self.copy()
        
        print(table, writers)
        
        for (oldID, writer) in writers {
            let newID = table[oldID] ?? oldID
            writer(newID)
        }
        
        return copied
    }
}
