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

    public func write(encoder: any UpdateEncoder, offset: UInt) throws { fatalError() }

    public func integrate(transaction: Transaction, offset: UInt) throws -> Void { fatalError() }

    static public func tryMerge(withLeft structs: [Struct], pos: Int) {
        var structs = structs
        let left = structs[pos - 1]
        let right = structs[pos]
        
        if left.deleted == right.deleted && type(of: left) == type(of: right) {
            if left.merge(with: right) {
                structs.remove(at: pos)
                if right is Item
                    && (right as! Item).parentSub != nil
                    && ((right as! Item).parent as! AbstractType)._map[(right as! Item).parentSub!] === right
                {
                    ((right as! Item).parent as! AbstractType)._map[(right as! Item).parentSub!] = (left as! Item)
                }
            }
        }
    }
    
    public func getMissing(_ transaction: Transaction, store: StructStore) -> UInt? { fatalError() }
}
