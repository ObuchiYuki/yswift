//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

public class Struct {
    public let id: ID
    public var length: UInt
    
    public init(id: ID, length: UInt) {
        self.id = id
        self.length = length
    }

    public var deleted: Bool { fatalError() }

    public func merge(with right: Struct) -> Bool { return false }

    public func write(encoder: any UpdateEncoder, offset: Int, encodingRef: Int) { fatalError() }

    public func integrate(transaction: Transaction, offset: Int) -> Void { fatalError() }

    static public func tryMerge(withLeft structs: [Struct], pos: Int) {
        var structs = structs
        let left = structs[pos - 1]
        let right = structs[pos]
        
        if left.deleted == right.deleted && type(of: left) == type(of: right) {
            if left.merge(with: right) {
                structs.remove(at: pos)
                if right is Item
                    && right.parentSub != nil
                    && (right.parent as! AbstractType)._map.get(right.parentSub) == right
                {
                    (right.parent as! AbstractType)._map.set(right.parentSub, left as! Item)
                }
            }
        }
    }
}
