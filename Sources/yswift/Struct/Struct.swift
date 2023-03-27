//
//  File.swift
//  
//
//  Created by yuki on 2023/03/15.
//

public class Struct {
    public let id: ID
    public var length: Int
    
    public init(id: ID, length: Int) {
        self.id = id
        self.length = length
    }

    public var deleted: Bool { fatalError() }

    public func merge(with right: Struct) -> Bool { return false }

    public func encode(into encoder: any UpdateEncoder, offset: Int) throws { fatalError() }

    public func integrate(transaction: Transaction, offset: Int) throws -> Void { fatalError() }
    
    public func getMissing(_ transaction: Transaction, store: StructStore) throws -> Int? { nil }
}

extension Struct {
    func slice(diff: Int) -> Struct { // no Skip return
        let left = self
        
        if left is GC {
            let client = left.id.client, clock = left.id.clock
            return GC(id: ID(client: client, clock: clock + diff), length: left.length - diff)
        } else if left is Skip {
            let client = left.id.client, clock = left.id.clock
            return Skip(id: ID(client: client, clock: clock + diff), length: left.length - diff)
        } else {
            let leftItem = left as! Item
            let client = leftItem.id.client, clock = leftItem.id.clock
            
            return Item(
                id: ID(client: client, clock: clock + diff),
                left: nil,
                origin: ID(client: client, clock: clock + diff - 1),
                right: nil,
                rightOrigin: leftItem.rightOrigin,
                parent: leftItem.parent,
                parentSub: leftItem.parentKey,
                content: leftItem.content.splice(diff)
            )
        }
    }

    static func tryMerge(withLeft structs: Ref<[Struct]>, pos: Int) {
        let left = structs[pos - 1]
        let right = structs[pos]
        
        if left.deleted == right.deleted && type(of: left) == type(of: right) {
            if left.merge(with: right) {
                structs.value.remove(at: pos)
                if right is Item
                    && (right as! Item).parentKey != nil
                    && ((right as! Item).parent!.object!).storage[(right as! Item).parentKey!] === right
                {
                    ((right as! Item).parent!.object!).storage[(right as! Item).parentKey!] = (left as! Item)
                }
            }
        }
    }
}
